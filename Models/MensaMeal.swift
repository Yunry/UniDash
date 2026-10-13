//
//  MensaMeal.swift
//  UniDash
//
//  Decodable models for OpenMensa API v2 cafeteria menus, iMensa-style categories, ratings, and dietary info.
//

import Foundation

/// Price tier model from OpenMensa API
struct MealPrices: Codable, Hashable, Sendable {
    let students: Double?
    let employees: Double?
    let pupils: Double?
    let others: Double?

    enum CodingKeys: String, CodingKey {
        case students
        case employees
        case pupils
        case others
    }

    init(students: Double? = nil, employees: Double? = nil, pupils: Double? = nil, others: Double? = nil) {
        self.students = students
        self.employees = employees
        self.pupils = pupils
        self.others = others
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.students = MealPrices.decodePrice(from: container, key: .students)
        self.employees = MealPrices.decodePrice(from: container, key: .employees)
        self.pupils = MealPrices.decodePrice(from: container, key: .pupils)
        self.others = MealPrices.decodePrice(from: container, key: .others)
    }

    private static func decodePrice(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let val = try? container.decodeIfPresent(Double.self, forKey: key) {
            return val
        }
        if let str = try? container.decodeIfPresent(String.self, forKey: key), let val = Double(str) {
            return val
        }
        return nil
    }
}

/// Represents a dish offered at a cafeteria
struct MensaMeal: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let category: String
    let prices: MealPrices?
    let notes: [String]

    init(id: Int, name: String, category: String, prices: MealPrices?, notes: [String] = []) {
        self.id = id
        self.name = name
        self.category = category
        self.prices = prices
        self.notes = notes
    }

    // MARK: - iMensa Category Normalization

    var normalizedCategory: String {
        let cat = category.lowercased()
        if cat.contains("pasta") || cat.contains("wok") || cat.contains("nudel") {
            return "Pastatheke & Wok"
        } else if isVegan || cat.contains("vegan") || cat.contains("vegetar") {
            return "Vegetarisch & Vegan"
        } else if cat.contains("suppe") || cat.contains("salat") || cat.contains("beilage") {
            return "Suppen & Beilagen"
        } else if cat.contains("dessert") || cat.contains("nachtisch") || cat.contains("snack") {
            return "Dessert & Snacks"
        } else {
            return "Tagesgerichte & Klassiker"
        }
    }

    // MARK: - Dietary Indicators

    var isVegan: Bool {
        notes.contains { note in
            let lower = note.lowercased()
            return lower.contains("vegan") || lower.contains("rein pflanzlich")
        }
    }

    var isVegetarian: Bool {
        if isVegan { return true }
        return notes.contains { note in
            let lower = note.lowercased()
            return lower.contains("vegetarisch") || lower.contains("vegi") || lower.contains("vegetarian")
        }
    }

    var isPorkFree: Bool {
        !notes.contains { note in
            let lower = note.lowercased()
            return lower.contains("schwein") || lower.contains("pork") || lower.contains("speck") || lower.contains("gelatine")
        }
    }

    var isBeefFree: Bool {
        !notes.contains { note in
            let lower = note.lowercased()
            return lower.contains("rind") || lower.contains("beef") || lower.contains("kalb")
        }
    }

    var isPoultry: Bool {
        notes.contains { note in
            let lower = note.lowercased()
            return lower.contains("geflügel") || lower.contains("hähnchen") || lower.contains("pute") || lower.contains("chicken")
        }
    }

    var isFish: Bool {
        notes.contains { note in
            let lower = note.lowercased()
            return lower.contains("fisch") || lower.contains("fish") || lower.contains("lachs")
        }
    }

    /// Cleaned notes list excluding redundant dietary tags
    var allergensAndAdditives: [String] {
        notes.filter { note in
            let lower = note.lowercased()
            return !lower.contains("vegan") && !lower.contains("vegetarisch")
        }
    }

    /// Formatted student price with Euro currency symbol
    var studentPriceFormatted: String {
        guard let price = prices?.students else { return "—" }
        return String(format: "%.2f €", price).replacingOccurrences(of: ".", with: ",")
    }

    var employeePriceFormatted: String? {
        guard let price = prices?.employees else { return nil }
        return String(format: "%.2f €", price).replacingOccurrences(of: ".", with: ",")
    }

    var otherPricesFormatted: String {
        var parts: [String] = []
        if let emp = prices?.employees {
            parts.append("Bed.: " + String(format: "%.2f €", emp).replacingOccurrences(of: ".", with: ","))
        }
        if let oth = prices?.others {
            parts.append("Gast: " + String(format: "%.2f €", oth).replacingOccurrences(of: ".", with: ","))
        }
        return parts.joined(separator: " • ")
    }

    // MARK: - iMensa Simulated Community Rating

    var communityRating: Double {
        // Deterministic rating based on meal id for consistent display
        let base = 3.8 + (Double(abs(id) % 12) / 10.0)
        return min(5.0, max(3.5, base))
    }

    var communityRatingCount: Int {
        return 12 + (abs(id) % 45)
    }

    // MARK: - Sample Data for Previews and Demo

    static var sampleMeals: [MensaMeal] {
        [
            MensaMeal(
                id: 101,
                name: "Pasta mit feiner Basilikum-Pesto, gerösteten Pinienkernen und Kirschtomaten",
                category: "Pastatheke",
                prices: MealPrices(students: 2.80, employees: 4.20, pupils: nil, others: 5.50),
                notes: ["vegan", "Glutenhaltiges Getreide (Weizen)", "Knoblauch"]
            ),
            MensaMeal(
                id: 102,
                name: "Schwäbische Käsespätzle mit Röstzwiebeln und buntem Beilagensalat",
                category: "Tagesgericht",
                prices: MealPrices(students: 3.20, employees: 4.80, pupils: nil, others: 6.00),
                notes: ["vegetarisch", "Milch/Laktose", "Eier", "Gluten"]
            ),
            MensaMeal(
                id: 103,
                name: "Knuspriges Hähnchenschnitzel Wiener Art mit Pommes Frites und Preiselbeeren",
                category: "Klassiker",
                prices: MealPrices(students: 3.90, employees: 5.60, pupils: nil, others: 7.20),
                notes: ["Geflügel", "Gluten", "Eier"]
            ),
            MensaMeal(
                id: 104,
                name: "Süßkartoffel-Kichererbsen-Curry mit Kokosmilch und Duftreis",
                category: "Wok & International",
                prices: MealPrices(students: 2.95, employees: 4.50, pupils: nil, others: 5.80),
                notes: ["vegan", "Sesam"]
            ),
            MensaMeal(
                id: 105,
                name: "Hausgemachte Rote Grütze mit Vanillesoße",
                category: "Dessert",
                prices: MealPrices(students: 1.20, employees: 1.60, pupils: nil, others: 2.00),
                notes: ["vegetarisch", "Milch/Laktose"]
            )
        ]
    }
}

/// Representation of a Mensa canteen from OpenMensa API or Munich live feed
struct CanteenInfo: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let city: String
    let address: String?
    var slug: String?

    init(id: Int, name: String, city: String, address: String?, slug: String? = nil) {
        self.id = id
        self.name = name
        self.city = city
        self.address = address
        self.slug = slug
    }

    // Comprehensive list with LMU München at the top
    static let defaultCanteens: [CanteenInfo] = [
        // LMU München & München (Direct Live Feed)
        CanteenInfo(id: 133, name: "Mensa Leopoldstraße (LMU)", city: "München", address: "Leopoldstraße 13a", slug: "mensa-leopoldstr"),
        CanteenInfo(id: 136, name: "StuBistro Schellingstraße (LMU)", city: "München", address: "Schellingstraße 3", slug: "stubistro-schellingstr"),
        CanteenInfo(id: 134, name: "Mensa Martinsried (LMU)", city: "München", address: "Großhaderner Str. 6", slug: "mensa-martinsried"),
        CanteenInfo(id: 138, name: "Mensa Arcisstraße (TUM)", city: "München", address: "Arcisstraße 17", slug: "mensa-arcisstr"),
        CanteenInfo(id: 421, name: "Mensa Garching (TUM)", city: "München", address: "Boltzmannstraße 19", slug: "mensa-garching"),

        // Aachen
        CanteenInfo(id: 187, name: "Mensa Academica (RWTH)", city: "Aachen", address: "Pontwall 3"),
        CanteenInfo(id: 95, name: "Mensa Ahornstraße (RWTH)", city: "Aachen", address: "Ahornstraße 55"),

        // Berlin
        CanteenInfo(id: 122, name: "Mensa Nord (HU Berlin)", city: "Berlin", address: "Hannoversche Str. 7"),
        CanteenInfo(id: 520, name: "Mensa Hardenbergstraße (TU Berlin)", city: "Berlin", address: "Hardenbergstraße 34"),

        // Karlsruhe
        CanteenInfo(id: 31, name: "Mensa Am Adenauerring (KIT)", city: "Karlsruhe", address: "Adenauerring 7"),

        // Leipzig & Dresden
        CanteenInfo(id: 63, name: "Mensa am Park (Uni Leipzig)", city: "Leipzig", address: "Universitätsstraße 5"),
        CanteenInfo(id: 79, name: "Alte Mensa (TU Dresden)", city: "Dresden", address: "Mommsenstraße 13"),

        // Hannover, Hamburg, Frankfurt, Stuttgart
        CanteenInfo(id: 6, name: "Hannover Hauptmensa", city: "Hannover", address: "Callinstraße 23"),
        CanteenInfo(id: 450, name: "Mensa Studierendenhaus (Uni Hamburg)", city: "Hamburg", address: "Von-Melle-Park 2"),
        CanteenInfo(id: 490, name: "Mensa Casino (Goethe-Uni)", city: "Frankfurt am Main", address: "Nina-Rubinstein-Weg 1"),
        CanteenInfo(id: 410, name: "Mensa Vaihingen (Uni Stuttgart)", city: "Stuttgart", address: "Universitätsstraße 34"),

        // Freiburg & Würzburg
        CanteenInfo(id: 382, name: "Mensa Rempartstraße (Uni Freiburg)", city: "Freiburg", address: "Rempartstraße 18"),
        CanteenInfo(id: 533, name: "Mensa Studentenhaus (Uni Würzburg)", city: "Würzburg", address: "Am Hubland"),
        CanteenInfo(id: 1, name: "Mensa UniCampus Magdeburg", city: "Magdeburg", address: "Pfälzer Str. 1"),
        CanteenInfo(id: 74, name: "Mensa Philosophenweg (Uni Jena)", city: "Jena", address: "Philosophenweg 20")
    ]
}
