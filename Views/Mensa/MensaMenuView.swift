//
//  MensaMenuView.swift
//  UniDash
//
//  iMensa-style university cafeteria tracker with city/canteen browser, favorite canteens,
//  Monday-to-Friday week tabs, category groupings, and interactive 5-star ratings.
//

import SwiftUI

enum MensaDietFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case vegetarian = "Vegetarisch 🌱"
    case vegan = "Vegan 🌿"
    case porkFree = "Ohne Schwein 🚫🐷"
    case poultry = "Geflügel 🍗"

    var id: String { rawValue }
}

struct MensaMenuView: View {
    @ObservedObject private var mensaService = MensaService.shared
    @AppStorage("activeCanteenId") private var selectedCanteenId: Int = 133
    @AppStorage("activeCanteenName") private var selectedCanteenName: String = "Mensa Leopoldstraße (LMU)"
    @AppStorage("activeCanteenCity") private var selectedCanteenCity: String = "München"

    @State private var selectedDayOffset: Int = 0 // 0 = Monday/Today offset
    @State private var activeFilter: MensaDietFilter = .all
    @State private var searchText: String = ""
    @State private var showCanteenDirectorySheet: Bool = false
    @State private var ratingMealTarget: MensaMeal? = nil

    // Generate dates for current week Monday through Friday
    private var weekDays: [(date: Date, offset: Int, title: String, isToday: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // Sunday = 1, Monday = 2
        let daysFromMonday = (weekday == 1 ? 6 : weekday - 2)
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return []
        }

        var result: [(Date, Int, String, Bool)] = []
        let df = DateFormatter()
        df.dateFormat = "E d.M."

        for i in 0..<5 {
            if let date = calendar.date(byAdding: .day, value: i, to: monday) {
                let isToday = calendar.isDate(date, inSameDayAs: today)
                let title = df.string(from: date)
                result.append((date, i - daysFromMonday, title, isToday))
            }
        }
        return result
    }

    private var targetDate: Date {
        Calendar.current.date(byAdding: .day, value: selectedDayOffset, to: Date()) ?? Date()
    }

    private var filteredMeals: [MensaMeal] {
        var list = mensaService.meals

        // Filter by diet
        switch activeFilter {
        case .all: break
        case .vegetarian: list = list.filter { $0.isVegetarian }
        case .vegan: list = list.filter { $0.isVegan }
        case .porkFree: list = list.filter { $0.isPorkFree }
        case .poultry: list = list.filter { $0.isPoultry }
        }

        // Filter by search
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.category.lowercased().contains(query) ||
                $0.notes.contains { $0.lowercased().contains(query) }
            }
        }

        return list
    }

    // Group meals by normalized categories (iMensa layout)
    private var categorizedMeals: [(category: String, meals: [MensaMeal])] {
        let grouped = Dictionary(grouping: filteredMeals, by: { $0.normalizedCategory })
        let order = ["Tagesgerichte & Klassiker", "Pastatheke & Wok", "Vegetarisch & Vegan", "Suppen & Beilagen", "Dessert & Snacks"]

        var result: [(String, [MensaMeal])] = []
        for cat in order {
            if let meals = grouped[cat], !meals.isEmpty {
                result.append((cat, meals))
            }
        }
        // Add any remaining categories
        for (cat, meals) in grouped where !order.contains(cat) && !meals.isEmpty {
            result.append((cat, meals))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - iMensa Top Header & Favorite Switcher
                VStack(spacing: 8) {
                    // Canteen Title & City
                    Button {
                        showCanteenDirectorySheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(selectedCanteenName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(selectedCanteenCity) • iMensa Speiseplan")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            Button {
                                mensaService.toggleFavorite(canteenId: selectedCanteenId)
                            } label: {
                                Image(systemName: mensaService.isFavorite(canteenId: selectedCanteenId) ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 6)

                    // Favorite Canteens Quick Switcher Strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(favoriteCanteensList) { canteen in
                                let isSelected = canteen.id == selectedCanteenId
                                Button {
                                    switchCanteen(to: canteen)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundStyle(isSelected ? .yellow : .secondary)
                                        Text(canteen.name)
                                            .font(.caption)
                                            .fontWeight(isSelected ? .bold : .regular)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                showCanteenDirectorySheet = true
                            } label: {
                                Label("Mensa suchen", systemImage: "magnifyingglass")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    }

                    // Weekdays Strip (Mo - Fr)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(weekDays, id: \.offset) { item in
                                let isSelected = item.offset == selectedDayOffset

                                Button {
                                    selectedDayOffset = item.offset
                                    loadMeals()
                                } label: {
                                    VStack(spacing: 3) {
                                        Text(item.title)
                                            .font(.caption)
                                            .fontWeight(isSelected ? .bold : .medium)

                                        if item.isToday {
                                            Text("Heute")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(isSelected ? Color.white : Color.blue)
                                                .foregroundStyle(isSelected ? Color.blue : Color.white)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .frame(minWidth: 64)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(isSelected ? Color.blue : Color.secondary.opacity(0.08))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                    }
                }
                .background(.bar)

                // MARK: - Dietary Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MensaDietFilter.allCases) { filter in
                            Button {
                                activeFilter = filter
                            } label: {
                                Text(filter.rawValue)
                                    .font(.caption)
                                    .fontWeight(activeFilter == filter ? .semibold : .regular)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(activeFilter == filter ? Color.green : Color.secondary.opacity(0.12))
                                    .foregroundStyle(activeFilter == filter ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }

                Divider()

                // MARK: - Meals List by Categories
                if mensaService.isLoading {
                    Spacer()
                    ProgressView("Speiseplan wird geladen...")
                    Spacer()
                } else if filteredMeals.isEmpty {
                    emptyMealsState
                } else {
                    List {
                        ForEach(categorizedMeals, id: \.category) { section in
                            Section(header: Text(section.category).font(.subheadline).fontWeight(.bold)) {
                                ForEach(section.meals) { meal in
                                    IMensaMealCard(
                                        meal: meal,
                                        canteenId: selectedCanteenId,
                                        onRateTap: {
                                            ratingMealTarget = meal
                                        }
                                    )
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await mensaService.fetchMeals(for: selectedCanteenId, date: targetDate, forceRefresh: true)
                    }
                }
            }
            .navigationTitle("Mensa")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Gericht suchen (z.B. Schnitzel, Pasta, Curry)...")
            .sheet(isPresented: $showCanteenDirectorySheet) {
                IMensaDirectoryModal(
                    selectedCanteenId: $selectedCanteenId,
                    selectedCanteenName: $selectedCanteenName,
                    selectedCanteenCity: $selectedCanteenCity,
                    onSelected: {
                        loadMeals(force: true)
                    }
                )
            }
            .sheet(item: $ratingMealTarget) { meal in
                RateMealSheet(
                    meal: meal,
                    canteenId: selectedCanteenId
                )
            }
            .onAppear {
                loadMeals()
            }
        }
    }

    // MARK: - Handlers

    private var favoriteCanteensList: [CanteenInfo] {
        CanteenInfo.defaultCanteens.filter { mensaService.isFavorite(canteenId: $0.id) }
    }

    private func switchCanteen(to canteen: CanteenInfo) {
        selectedCanteenId = canteen.id
        selectedCanteenName = canteen.name
        selectedCanteenCity = canteen.city
        loadMeals(force: true)
    }

    private func loadMeals(force: Bool = false) {
        Task {
            _ = await mensaService.fetchMeals(for: selectedCanteenId, date: targetDate, forceRefresh: force)
        }
    }

    private var emptyMealsState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            if let error = mensaService.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("Keine Speisen für diesen Tag eingetragen.")
                    .font(.headline)
                Text("Die Mensa hat an diesem Tag geschlossen oder der Speiseplan wurde noch nicht veröffentlicht.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                mensaService.loadDemoMeals()
            } label: {
                Label("Demo-Speiseplan anzeigen", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .padding(.top, 6)

            Spacer()
        }
    }
}

// MARK: - iMensa Dish Card

struct IMensaMealCard: View {
    let meal: MensaMeal
    let canteenId: Int
    var onRateTap: () -> Void

    @ObservedObject private var mensaService = MensaService.shared
    @State private var showAllergens: Bool = false

    private var userRating: Int? {
        mensaService.ratingForMeal(canteenId: canteenId, mealId: meal.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Category tag, Star rating, Price pill
            HStack {
                Text(meal.category.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Spacer()

                // iMensa Star Rating
                Button(action: onRateTap) {
                    HStack(spacing: 3) {
                        Image(systemName: userRating != nil ? "star.fill" : "star.leadinghalf.filled")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                        Text(userRating != nil ? "\(userRating!).0" : String(format: "%.1f", meal.communityRating))
                            .font(.caption2)
                            .fontWeight(.semibold)
                        Text("(\(meal.communityRatingCount))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Student Price Pill (Bold Green)
                Text(meal.studentPriceFormatted)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            // Dish Title
            Text(meal.name)
                .font(.body)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)

            // Dietary & Allergen Badges
            HStack(spacing: 6) {
                if meal.isVegan {
                    BadgePill(title: "Vegan", icon: "leaf.fill", color: .green)
                } else if meal.isVegetarian {
                    BadgePill(title: "Vegi", icon: "leaf", color: .green)
                }

                if meal.isPoultry {
                    BadgePill(title: "Geflügel", icon: "bird", color: .orange)
                } else if meal.isBeefFree && !meal.isPorkFree {
                    BadgePill(title: "Schwein", icon: "circle.grid.cross", color: .pink)
                } else if meal.isFish {
                    BadgePill(title: "Fisch", icon: "water.waves", color: .teal)
                }

                Spacer()

                // Other prices if available
                if let empPrice = meal.employeePriceFormatted {
                    Text("Bed.: \(empPrice)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !meal.allergensAndAdditives.isEmpty {
                    Button {
                        showAllergens.toggle()
                    } label: {
                        Image(systemName: showAllergens ? "info.circle.fill" : "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Expanded Allergens
            if showAllergens && !meal.allergensAndAdditives.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Divider()
                    Text("Zusatzstoffe & Allergene: " + meal.allergensAndAdditives.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - iMensa Dish Rating Modal

struct RateMealSheet: View {
    let meal: MensaMeal
    let canteenId: Int
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var mensaService = MensaService.shared
    @State private var selectedStars: Int = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(meal.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 20)

                Text("Wie hat es geschmeckt?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            selectedStars = star
                        } label: {
                            Image(systemName: star <= selectedStars ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundStyle(star <= selectedStars ? .yellow : .secondary.opacity(0.3))
                        }
                    }
                }
                .padding(.vertical, 8)

                Text(starDescription(for: selectedStars))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    mensaService.rateMeal(canteenId: canteenId, mealId: meal.id, stars: selectedStars)
                    dismiss()
                } label: {
                    Text("Bewertung abgeben")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Gericht bewerten")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear {
                if let r = mensaService.ratingForMeal(canteenId: canteenId, mealId: meal.id) {
                    selectedStars = r
                }
            }
        }
        .presentationDetents([.fraction(0.45)])
    }

    private func starDescription(for stars: Int) -> String {
        switch stars {
        case 5: return "Hervorragend! 😋"
        case 4: return "Sehr lecker! 👍"
        case 3: return "Ganz in Ordnung 👌"
        case 2: return "Nicht so gut 😕"
        default: return "Ungenießbar ❌"
        }
    }
}

// MARK: - iMensa City & Canteen Directory Modal

struct IMensaDirectoryModal: View {
    @Binding var selectedCanteenId: Int
    @Binding var selectedCanteenName: String
    @Binding var selectedCanteenCity: String
    var onSelected: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var mensaService = MensaService.shared

    @State private var searchKeyword: String = ""
    @State private var selectedCityFilter: String = "Alle"

    private var availableCities: [String] {
        let cities = Set(CanteenInfo.defaultCanteens.map { $0.city })
        return ["Alle"] + cities.sorted()
    }

    private var filteredCanteens: [CanteenInfo] {
        var list = CanteenInfo.defaultCanteens
        if selectedCityFilter != "Alle" {
            list = list.filter { $0.city == selectedCityFilter }
        }
        let q = searchKeyword.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                $0.city.lowercased().contains(q) ||
                ($0.address?.lowercased().contains(q) ?? false)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // City Filter Scroll Strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableCities, id: \.self) { city in
                            Button {
                                selectedCityFilter = city
                            } label: {
                                Text(city)
                                    .font(.caption)
                                    .fontWeight(selectedCityFilter == city ? .bold : .regular)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCityFilter == city ? Color.blue : Color.secondary.opacity(0.1))
                                    .foregroundStyle(selectedCityFilter == city ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.bar)

                List {
                    // Favorites Section
                    let favorites = filteredCanteens.filter { mensaService.isFavorite(canteenId: $0.id) }
                    if !favorites.isEmpty {
                        Section(header: Text("Favoriten (iMensa)")) {
                            ForEach(favorites) { canteen in
                                canteenRow(canteen)
                            }
                        }
                    }

                    // All Canteens Section
                    Section(header: Text("Alle Mensen (\(filteredCanteens.count))")) {
                        ForEach(filteredCanteens) { canteen in
                            canteenRow(canteen)
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.sidebar)
                #endif
            }
            .navigationTitle("Mensa wählen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchKeyword, prompt: "Stadt oder Mensa suchen...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func canteenRow(_ canteen: CanteenInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(canteen.name)
                        .font(.body)
                        .fontWeight(.medium)
                    if selectedCanteenId == canteen.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                Text("\(canteen.city) • \(canteen.address ?? "Campus")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                mensaService.toggleFavorite(canteenId: canteen.id)
            } label: {
                Image(systemName: mensaService.isFavorite(canteenId: canteen.id) ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCanteenId = canteen.id
            selectedCanteenName = canteen.name
            selectedCanteenCity = canteen.city
            onSelected()
            dismiss()
        }
    }
}

// MARK: - Badge Pill

struct BadgePill: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

