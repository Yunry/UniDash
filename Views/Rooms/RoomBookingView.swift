//
//  RoomBookingView.swift
//  UniDash
//
//  Unified Campus Hub: Bibliotheken (with live occupancy & opening hours),
//  Study Pods & Booking (Anny SSO), Semester Timeline & Deadlines,
//  Campus Quick Links (Moodle, LSF, LRZ Mail), and Room Finder Decoder.
//

import SwiftUI

enum CampusHubTab: String, CaseIterable, Identifiable {
    case libraries = "Bibliotheken"
    case rooms = "Lernräume"
    case timeline = "Fristen"
    case portals = "Portale"
    case roomFinder = "Raum-Finder"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .libraries: return "books.vertical.fill"
        case .rooms: return "chair.lounge.fill"
        case .timeline: return "clock.badge.exclamationmark.fill"
        case .portals: return "link"
        case .roomFinder: return "magnifyingglass"
        }
    }
}

struct StudyRoom: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var location: String
    var capacity: String
    var noiseLevel: String
    var bookingURL: String
    var iconName: String
    var colorHex: String

    static let defaultRooms: [StudyRoom] = [
        StudyRoom(
            name: "Zentralbibliothek – Einzelplatz",
            location: "Hauptcampus • Geschwister-Scholl-Platz 1",
            capacity: "1 Person",
            noiseLevel: "Stille Zone 🤫",
            bookingURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            iconName: "book.closed.fill",
            colorHex: "#3B82F6"
        ),
        StudyRoom(
            name: "Philologicum – Gruppenarbeitsraum",
            location: "Ludwigstraße 25 • 3. OG",
            capacity: "4–8 Personen",
            noiseLevel: "Diskussion erlaubt 🗣️",
            bookingURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            iconName: "person.3.fill",
            colorHex: "#10B981"
        ),
        StudyRoom(
            name: "MINT Lernzentrum Pods",
            location: "Theresienstraße 39 • MINT-Trakt",
            capacity: "1–2 Personen",
            noiseLevel: "Gedämpft 🎧",
            bookingURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            iconName: "headphones",
            colorHex: "#8B5CF6"
        ),
        StudyRoom(
            name: "Informatik CIP-Pool & MakerSpace",
            location: "Oettingenstraße 67 • EG",
            capacity: "Bis 12 Personen",
            noiseLevel: "Projektarbeit 🛠️",
            bookingURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            iconName: "wrench.and.screwdriver.fill",
            colorHex: "#F59E0B"
        ),
        StudyRoom(
            name: "Lernzentrum WiWi",
            location: "Ludwigstraße 28 • 2. OG",
            capacity: "Einzeltische",
            noiseLevel: "Ruhige Arbeitsatmosphäre 📖",
            bookingURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            iconName: "chart.line.uptrend.xyaxis",
            colorHex: "#EC4899"
        )
    ]
}

struct RoomBookingView: View {
    @Environment(\.openURL) private var openURL
    @State private var selectedTab: CampusHubTab = .libraries

    // Libraries & Live Occupancy State
    @StateObject private var occupancyService = LibraryOccupancyService()
    @State private var libraries: [CampusLibrary] = CampusLibrary.defaultLibraries
    @State private var librarySearchText: String = ""
    @State private var selectedEquipmentFilter: LibraryEquipment? = nil
    @State private var onlyOpenLibraries: Bool = false
    @State private var currentTime: Date = Date()

    // Rooms State
    @State private var rooms: [StudyRoom] = StudyRoom.defaultRooms
    @State private var activeURL: URL? = nil
    @State private var activeTitle: String = ""
    @State private var showAddRoomSheet: Bool = false

    private let libraryColumns = [
        GridItem(.adaptive(minimum: 320, maximum: 440), spacing: 16)
    ]

    private var filteredLibraries: [CampusLibrary] {
        libraries.filter { lib in
            let matchesSearch = librarySearchText.isEmpty ||
                lib.name.localizedCaseInsensitiveContains(librarySearchText) ||
                lib.address.localizedCaseInsensitiveContains(librarySearchText) ||
                lib.campusArea.localizedCaseInsensitiveContains(librarySearchText)

            let matchesEquipment = selectedEquipmentFilter == nil || lib.equipment.contains(selectedEquipmentFilter!)
            let matchesOpen = !onlyOpenLibraries || lib.isOpen(at: currentTime)

            return matchesSearch && matchesEquipment && matchesOpen
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Top Navigation Sub-Tabs Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CampusHubTab.allCases) { tab in
                                Button {
                                    selectedTab = tab
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: tab.icon)
                                        Text(tab.rawValue)
                                    }
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? Color.blue : Color.secondary.opacity(0.12))
                                    .foregroundStyle(selectedTab == tab ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // Content Switcher
                    switch selectedTab {
                    case .libraries:
                        librariesSection
                    case .rooms:
                        roomsSection
                    case .timeline:
                        AcademicTimelineView()
                    case .portals:
                        CampusQuickLinksView()
                    case .roomFinder:
                        CampusRoomDecoderView()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Campus & Lernräume")
            .toolbar {
                if selectedTab == .libraries {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task {
                                await refreshOccupancy()
                            }
                        } label: {
                            if occupancyService.isLoading {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Aktualisieren", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(occupancyService.isLoading)
                        .help("Auslastung der Bibliotheken neu laden")
                    }
                }

                if selectedTab == .rooms {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddRoomSheet = true
                        } label: {
                            Label("Raum hinzufügen", systemImage: "plus")
                        }
                    }
                }
            }
            .task {
                await refreshOccupancy()
            }
            .onAppear {
                loadRooms()
            }
            .sheet(item: Binding<IdentifiableURL?>(
                get: { activeURL.map { IdentifiableURL(url: $0, title: activeTitle) } },
                set: { activeURL = $0?.url }
            )) { item in
                InAppBrowserSheet(url: item.url, title: item.title)
            }
            .sheet(isPresented: $showAddRoomSheet) {
                AddStudyRoomModal { newRoom in
                    rooms.append(newRoom)
                    saveRooms()
                }
            }
        }
    }

    private func refreshOccupancy() async {
        currentTime = Date()
        let feedIDs = libraries.compactMap { $0.occupancyFeedID }
        await occupancyService.refresh(feedIDs: feedIDs)
    }

    private func loadRooms() {
        if let data = UserDefaults.standard.data(forKey: "custom_study_rooms"),
           let decoded = try? JSONDecoder().decode([StudyRoom].self, from: data),
           !decoded.isEmpty {
            self.rooms = decoded
        }
    }

    private func saveRooms() {
        if let data = try? JSONEncoder().encode(rooms) {
            UserDefaults.standard.set(data, forKey: "custom_study_rooms")
        }
    }

    // MARK: - Libraries Section

    private var librariesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search & Filter Bar
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Bibliothek suchen (z.B. Philologicum, WiWi...)", text: $librarySearchText)
                        .textFieldStyle(.plain)

                    if !librarySearchText.isEmpty {
                        Button {
                            librarySearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            onlyOpenLibraries.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(onlyOpenLibraries ? Color.green : Color.secondary)
                                    .frame(width: 6, height: 6)
                                Text("Jetzt geöffnet")
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(onlyOpenLibraries ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1))
                            .foregroundStyle(onlyOpenLibraries ? Color.green : Color.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        ForEach(LibraryEquipment.allCases) { equip in
                            let isSelected = selectedEquipmentFilter == equip
                            Button {
                                selectedEquipmentFilter = isSelected ? nil : equip
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: equip.icon)
                                    Text(equip.rawValue)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSelected ? Color.blue : Color.secondary.opacity(0.1))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Libraries Grid
            LazyVGrid(columns: libraryColumns, spacing: 16) {
                ForEach(filteredLibraries) { lib in
                    LibraryCard(
                        library: lib,
                        occupancy: lib.occupancyFeedID.flatMap { occupancyService.occupancy[$0] },
                        isLoadingOccupancy: occupancyService.isLoading,
                        now: currentTime,
                        onBookInApp: {
                            if let reservation = lib.reservationURL, let url = URL(string: reservation) {
                                activeURL = url
                                activeTitle = "Platz reservieren: \(lib.name)"
                            }
                        },
                        onOpenInSafari: {
                            if let url = URL(string: lib.webURL) {
                                openURL(url)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Study Pods / Rooms Section

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Campus Lernplätze & Pods")
                        .font(.headline)
                    Text("Buchen Sie Arbeitsplätze direkt über das Campus-Buchungssystem (Anny).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            LazyVGrid(columns: libraryColumns, spacing: 16) {
                ForEach(rooms) { room in
                    StudyRoomCard(
                        room: room,
                        onOpenInSafari: {
                            if let url = URL(string: room.bookingURL) {
                                openURL(url)
                            }
                        },
                        onOpenInApp: {
                            if let url = URL(string: room.bookingURL) {
                                activeURL = url
                                activeTitle = room.name
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Room Card Component

struct StudyRoomCard: View {
    let room: StudyRoom
    var onOpenInSafari: () -> Void
    var onOpenInApp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: room.colorHex).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: room.iconName)
                        .font(.title3)
                        .foregroundStyle(Color(hex: room.colorHex))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(room.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Label(room.capacity, systemImage: "person.fill")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())

                Text(room.noiseLevel)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Divider()

            HStack(spacing: 12) {
                Button(action: onOpenInApp) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.inset.filled.and.cursorarrow")
                        Text("In-App Buchen")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button(action: onOpenInSafari) {
                    Image(systemName: "safari")
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("In Safari mit Uni-SSO öffnen")
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - In-App Browser Sheet with WKWebView

struct InAppBrowserSheet: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                EmbeddedWebView(url: url, isLoading: $isLoading)

                if isLoading {
                    VStack {
                        ProgressView("Buchungsportal lädt...")
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("In Safari", systemImage: "safari")
                    }
                }
            }
        }
    }
}

// MARK: - Add Custom Room Modal

struct AddStudyRoomModal: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (StudyRoom) -> Void

    @State private var name: String = ""
    @State private var location: String = ""
    @State private var capacity: String = "1 Person"
    @State private var noiseLevel: String = "Stille Zone 🤫"
    @State private var bookingURL: String = "https://anny.co"

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rauminformationen")) {
                    TextField("Name des Lernbereichs", text: $name)
                    TextField("Gebäude / Raum-ID", text: $location)
                    TextField("Kapazität (z.B. 2–4 Personen)", text: $capacity)
                    TextField("Lautstärke (z.B. Ruhig)", text: $noiseLevel)
                    TextField("Buchungs-URL (Anny Link)", text: $bookingURL)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                }
            }
            .navigationTitle("Lernraum hinzufügen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let newRoom = StudyRoom(
                            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Campus Lernraum" : name,
                            location: location.isEmpty ? "Campus" : location,
                            capacity: capacity,
                            noiseLevel: noiseLevel,
                            bookingURL: bookingURL.isEmpty ? "https://auth.anny.eu" : bookingURL,
                            iconName: "building.2.fill",
                            colorHex: "#3B82F6"
                        )
                        onAdd(newRoom)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (59, 130, 246)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
