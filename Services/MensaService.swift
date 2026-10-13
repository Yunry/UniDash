//
//  MensaService.swift
//  UniDash
//
//  Dual-engine client supporting direct LMU Munich live feeds (nav.tum.de) and OpenMensa API v2
//  with offline disk caching, favorite canteens, and iMensa star ratings.
//

import Foundation

// MARK: - Munich Live API Decodable Models

struct MunichCanteenResponse: Codable {
    let canteen_id: String?
    let name: String?
    let days: [MunichCanteenDay]?
}

struct MunichCanteenDay: Codable {
    let date: String
    let dishes: [MunichDish]
}

struct MunichDish: Codable {
    let name: String
    let dish_type: String?
    let prices: MunichPrices?
    let labels: [String]?
}

struct MunichPrices: Codable {
    let students: MunichPriceItem?
    let staff: MunichPriceItem?
    let guests: MunichPriceItem?
}

struct MunichPriceItem: Codable {
    let base_price: Double?
    let price_per_unit: Double?
    let unit: String?
}

// MARK: - MensaService

@MainActor
final class MensaService: ObservableObject {
    static let shared = MensaService()

    @Published var meals: [MensaMeal] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var allCanteens: [CanteenInfo] = CanteenInfo.defaultCanteens
    @Published var favoriteCanteenIds: Set<Int> = [133, 136, 134] // Default: LMU Mensen
    @Published var userRatings: [String: Int] = [:] // "canteenId_mealId" -> 1..5

    private var memoryCache: [String: (timestamp: Date, meals: [MensaMeal])] = [:]
    private let cacheTTL: TimeInterval = 60 * 60 // 1 hour

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return df
    }()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        loadPersistedState()
    }

    // MARK: - State Persistence

    private func loadPersistedState() {
        if let favs = UserDefaults.standard.array(forKey: "favoriteCanteenIds") as? [Int], !favs.isEmpty {
            self.favoriteCanteenIds = Set(favs)
        }
        if let ratings = UserDefaults.standard.dictionary(forKey: "userMealRatings") as? [String: Int] {
            self.userRatings = ratings
        }
    }

    private func savePersistedState() {
        UserDefaults.standard.set(Array(favoriteCanteenIds), forKey: "favoriteCanteenIds")
        UserDefaults.standard.set(userRatings, forKey: "userMealRatings")
    }

    // MARK: - Favorites Management

    func isFavorite(canteenId: Int) -> Bool {
        favoriteCanteenIds.contains(canteenId)
    }

    func toggleFavorite(canteenId: Int) {
        if favoriteCanteenIds.contains(canteenId) {
            favoriteCanteenIds.remove(canteenId)
        } else {
            favoriteCanteenIds.insert(canteenId)
        }
        savePersistedState()
    }

    // MARK: - Ratings Management (iMensa 1..5 Star Reviews)

    func ratingForMeal(canteenId: Int, mealId: Int) -> Int? {
        userRatings["\(canteenId)_\(mealId)"]
    }

    func rateMeal(canteenId: Int, mealId: Int, stars: Int) {
        userRatings["\(canteenId)_\(mealId)"] = stars
        savePersistedState()
    }

    // MARK: - API Fetching (LMU Direct Live + OpenMensa Dual Engine)

    func fetchMeals(for canteenId: Int, date: Date, forceRefresh: Bool = false) async -> [MensaMeal] {
        let dateString = dateFormatter.string(from: date)
        let cacheKey = "\(canteenId)_\(dateString)"

        // Check memory cache
        if !forceRefresh, let cached = memoryCache[cacheKey], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            self.meals = cached.meals
            self.errorMessage = nil
            return cached.meals
        }

        // Check disk cache for offline access (only if fresh)
        if !forceRefresh, let diskMeals = loadMealsFromDisk(for: cacheKey, maxAge: cacheTTL), !diskMeals.isEmpty {
            self.meals = diskMeals
            self.memoryCache[cacheKey] = (Date(), diskMeals)
            self.errorMessage = nil
            return diskMeals
        }

        self.isLoading = true
        self.errorMessage = nil
        defer { self.isLoading = false }

        let canteen = allCanteens.first(where: { $0.id == canteenId })

        if let slug = canteen?.slug {
            // Fetch live Munich / LMU data from NavigaTUM feed
            return await fetchMunichLiveMeals(slug: slug, canteenId: canteenId, targetDate: dateString, cacheKey: cacheKey)
        } else {
            // Fetch OpenMensa API v2 for other universities
            return await fetchOpenMensaMeals(canteenId: canteenId, dateString: dateString, cacheKey: cacheKey)
        }
    }

    // MARK: - Munich / LMU Live Feed Engine

    private func fetchMunichLiveMeals(slug: String, canteenId: Int, targetDate: String, cacheKey: String) async -> [MensaMeal] {
        guard let url = URL(string: "https://nav.tum.de/api/mensa/\(slug)") else {
            self.errorMessage = "Ungültige Mensa-URL."
            return []
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            request.setValue("UniDash-LMU/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            let munichResponse = try decoder.decode(MunichCanteenResponse.self, from: data)

            guard let days = munichResponse.days, !days.isEmpty else {
                self.meals = []
                self.errorMessage = "Derzeit sind keine Speisepläne für diese Mensa hinterlegt."
                return []
            }

            // Find exact day requested
            guard let activeDay = days.first(where: { $0.date == targetDate }), !activeDay.dishes.isEmpty else {
                self.meals = []
                self.errorMessage = "Für dieses Datum liegt kein Speiseplan vor (Mensa geschlossen oder Wochenende)."
                return []
            }

            var resultMeals: [MensaMeal] = []
            for dish in activeDay.dishes {
                // Calculate student price
                let studentPrice: Double = {
                    if let s = dish.prices?.students {
                        if let base = s.base_price, base > 0 {
                            return base + (s.price_per_unit ?? 0.0) * 2.5
                        } else if let unit = s.price_per_unit, unit > 0 {
                            return unit * 4.0
                        }
                    }
                    return 3.50 // Standard average student price
                }()

                let employeePrice: Double? = {
                    guard let e = dish.prices?.staff else { return nil }
                    if let base = e.base_price, base > 0 {
                        return base + (e.price_per_unit ?? 0.0) * 2.5
                    } else if let unit = e.price_per_unit {
                        return unit * 4.0
                    }
                    return 5.20
                }()

                let otherPrice: Double? = {
                    guard let g = dish.prices?.guests else { return nil }
                    if let base = g.base_price, base > 0 {
                        return base + (g.price_per_unit ?? 0.0) * 2.5
                    } else if let unit = g.price_per_unit {
                        return unit * 4.0
                    }
                    return 6.90
                }()

                // Clean and translate labels into readable German notes
                let translatedNotes = (dish.labels ?? []).map { translateLabel($0) }

                let stableId = MensaService.stableDishID(name: dish.name, canteenId: canteenId)
                let meal = MensaMeal(
                    id: stableId,
                    name: dish.name,
                    category: dish.dish_type ?? "Tagesgericht",
                    prices: MealPrices(students: studentPrice, employees: employeePrice, others: otherPrice),
                    notes: translatedNotes
                )
                resultMeals.append(meal)
            }

            self.meals = resultMeals
            self.memoryCache[cacheKey] = (Date(), resultMeals)
            saveMealsToDisk(resultMeals, for: cacheKey)
            self.errorMessage = nil
            return resultMeals

        } catch {
            if let diskMeals = loadMealsFromDisk(for: cacheKey, maxAge: nil), !diskMeals.isEmpty {
                self.meals = diskMeals
                self.errorMessage = nil
                return diskMeals
            }
            self.errorMessage = "Konnte Live-Speiseplan der LMU nicht laden: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - OpenMensa Engine

    private func fetchOpenMensaMeals(canteenId: Int, dateString: String, cacheKey: String) async -> [MensaMeal] {
        guard let url = URL(string: "https://openmensa.org/api/v2/canteens/\(canteenId)/days/\(dateString)/meals") else {
            self.errorMessage = "Ungültige Mensa-URL."
            return []
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("UniDash-Client/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 404 {
                self.meals = []
                self.errorMessage = "Mensa hat an diesem Tag geschlossen oder bietet kein Menü an."
                self.memoryCache[cacheKey] = (Date(), [])
                return []
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.init(rawValue: httpResponse.statusCode))
            }

            let decoder = JSONDecoder()
            let decodedMeals = try decoder.decode([MensaMeal].self, from: data)

            self.meals = decodedMeals
            self.memoryCache[cacheKey] = (Date(), decodedMeals)
            saveMealsToDisk(decodedMeals, for: cacheKey)
            self.errorMessage = nil
            return decodedMeals
        } catch {
            if let diskMeals = loadMealsFromDisk(for: cacheKey, maxAge: nil), !diskMeals.isEmpty {
                self.meals = diskMeals
                self.errorMessage = nil
                return diskMeals
            }
            self.errorMessage = "Konnte Speiseplan nicht laden: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Stable Dish Identification

    /// Generates a deterministic, cross-session identifier based on dish name and canteen.
    /// This ensures user star ratings persist accurately to the specific dish, rather than array indices.
    static func stableDishID(name: String, canteenId: Int) -> Int {
        let combined = "\(canteenId):\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        var hash: UInt64 = 14695981039346656037
        for byte in combined.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return Int(hash % 2_000_000_000)
    }

    private func translateLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "vegan": return "vegan"
        case "vegetarian": return "vegetarisch"
        case "beef": return "Rindfleisch"
        case "meat": return "Fleisch"
        case "pork": return "Schwein"
        case "poultry": return "Geflügel"
        case "fish": return "Fisch"
        case "chicken_eggs": return "Eier"
        case "milk", "lactose": return "Milch/Laktose"
        case "gluten": return "Gluten"
        case "wheat": return "Weizen"
        case "celery": return "Sellerie"
        case "mustard": return "Senf"
        case "soy": return "Soja"
        case "garlic": return "Knoblauch"
        case "antioxidants": return "Antioxidationsmittel"
        case "preservatives": return "Konservierungsstoffe"
        default: return raw
        }
    }

    // MARK: - Disk Caching for Offline Mode

    private struct CachedMealsPayload: Codable {
        let timestamp: Date
        let meals: [MensaMeal]
    }

    private func cacheFileURL(for key: String) -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("mensa_\(key).json")
    }

    private func saveMealsToDisk(_ meals: [MensaMeal], for key: String) {
        guard let url = cacheFileURL(for: key) else { return }
        let payload = CachedMealsPayload(timestamp: Date(), meals: meals)
        try? JSONEncoder().encode(payload).write(to: url)
    }

    private func loadMealsFromDisk(for key: String, maxAge: TimeInterval? = nil) -> [MensaMeal]? {
        guard let url = cacheFileURL(for: key),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(CachedMealsPayload.self, from: data) else {
            return nil
        }
        if let maxAge, Date().timeIntervalSince(payload.timestamp) > maxAge {
            return nil
        }
        return payload.meals
    }

    /// Load demo fallback meals
    func loadDemoMeals() {
        self.meals = MensaMeal.sampleMeals
        self.errorMessage = nil
    }
}
