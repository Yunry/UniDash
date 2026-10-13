//
//  CampusRoomDecoderView.swift
//  UniDash
//
//  Interactive LMU Raumfinder internal map (https://www.lmu.de/raumfinder/#/)
//  with building quick-selector, live floor plan browsing, and room code decoder.
//

import SwiftUI

enum RoomfinderViewMode: String, CaseIterable, Identifiable {
    case internalMap = "Interne Raumkarte"
    case decoderAndGuide = "Gebäude-Guide & Decoder"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .internalMap: return "map.fill"
        case .decoderAndGuide: return "magnifyingglass.circle.fill"
        }
    }
}

struct CampusRoomDecoderView: View {
    @State private var viewMode: RoomfinderViewMode = .internalMap
    @State private var roomQuery: String = ""
    @State private var selectedBuildingCode: String = "bw0000" // Default: Hauptgebäude GSP 1
    @State private var selectedRoomKey: String? = nil
    @State private var isMapLoading: Bool = false
    @State private var showFullScreenMap: Bool = false
    @Environment(\.openURL) private var openURL

    private let buildings = CampusBuildingGuide.defaultBuildings

    private var currentBuilding: CampusBuildingGuide? {
        buildings.first(where: { $0.lmuRaumfinderCode == selectedBuildingCode })
    }

    private var activeMapURL: URL {
        if selectedBuildingCode == "city" {
            return URL(string: "https://www.lmu.de/raumfinder/#/")!
        }
        if let key = selectedRoomKey, !key.isEmpty {
            return URL(string: "https://www.lmu.de/raumfinder/#/building/\(selectedBuildingCode)/map?room=\(key)")!
        }
        return URL(string: "https://www.lmu.de/raumfinder/#/building/\(selectedBuildingCode)/map")!
    }

    private var decodedResult: DecodedRoom? {
        CampusBuildingGuide.decode(roomCode: roomQuery)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Sub-mode Picker (Interne Karte vs. Gebäude-Guide)
            Picker("Modus", selection: $viewMode) {
                ForEach(RoomfinderViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Room Search & Decoder Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Raum suchen (z.B. S 002, B 201, N 120, Audimax, Theresienstr. 39)...", text: $roomQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()

                    if !roomQuery.isEmpty {
                        Button {
                            roomQuery = ""
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

                // Quick Suggestion Chips when search bar is empty
                if roomQuery.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Schnellsuche:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            ForEach(["S 002", "B 201", "N 120", "Audimax", "B 052", "W 101", "Raum 023", "Raum 144"], id: \.self) { sample in
                                Button(sample) {
                                    roomQuery = sample
                                }
                                .font(.caption2)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                // Instant Decoded Room Info Card
                if let result = decodedResult {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "building.2.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title3)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.building)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .fixedSize(horizontal: false, vertical: true)

                                Label(result.address, systemImage: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "stairs")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                Text(result.floor)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "tram.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(result.tip)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Quick Jump into Internal Raumfinder Map & Navigation (Equal width buttons)
                        HStack(spacing: 8) {
                            Button {
                                switchToBuildingFromDecoded()
                            } label: {
                                Label("Auf Raumkarte", systemImage: "map.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity, minHeight: 28)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            if let url = URL(string: result.mapsURL) {
                                Button {
                                    openURL(url)
                                } label: {
                                    Label("Apple Maps", systemImage: "location.fill")
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .frame(maxWidth: .infinity, minHeight: 28)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if let url = URL(string: result.raumfinderURL) {
                                Button {
                                    openURL(url)
                                } label: {
                                    Label("Raumfinder Web", systemImage: "safari")
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .frame(maxWidth: .infinity, minHeight: 28)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)

            // Content Switcher based on viewMode
            switch viewMode {
            case .internalMap:
                internalMapView
            case .decoderAndGuide:
                buildingsGuideView
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showFullScreenMap) {
            fullScreenMapContent
        }
        #else
        .sheet(isPresented: $showFullScreenMap) {
            fullScreenMapContent
                .frame(minWidth: 850, minHeight: 650)
        }
        #endif
    }

    private var fullScreenMapContent: some View {
        NavigationStack {
            EmbeddedWebView(
                url: activeMapURL,
                isLoading: $isMapLoading,
                targetRoomKey: selectedRoomKey,
                targetRoomQuery: roomQuery
            )
                .navigationTitle(currentBuilding?.name ?? "LMU Raumfinder")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") {
                            showFullScreenMap = false
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openURL(activeMapURL)
                        } label: {
                            Image(systemName: "safari")
                        }
                    }
                }
        }
    }

    // MARK: - Internal Raumfinder Map View

    private var internalMapView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Campus Building Quick-Switcher Pills
            VStack(alignment: .leading, spacing: 6) {
                Text("Gebäude-Auswahl (LMU Raumplan):")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // City Map Overview button
                        Button {
                            selectedBuildingCode = "city"
                            selectedRoomKey = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "globe.europe.africa.fill")
                                Text("Gesamt-Campus")
                            }
                            .font(.caption)
                            .fontWeight(selectedBuildingCode == "city" ? .semibold : .regular)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedBuildingCode == "city" ? Color.blue : Color.secondary.opacity(0.12))
                            .foregroundStyle(selectedBuildingCode == "city" ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        ForEach(buildings) { building in
                            let isSelected = selectedBuildingCode == building.lmuRaumfinderCode
                            Button {
                                selectedBuildingCode = building.lmuRaumfinderCode
                                selectedRoomKey = nil
                            } label: {
                                Text(building.name)
                                    .font(.caption)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Interactive Map Container
            VStack(spacing: 0) {
                // Map Header Bar
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isMapLoading ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)
                        Text(currentBuilding?.name ?? "LMU Stadtkarte")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Expand to Fullscreen button
                    Button {
                        showFullScreenMap = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Vollbildmodus")

                    // Open in Safari
                    Button {
                        openURL(activeMapURL)
                    } label: {
                        Image(systemName: "safari")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Im Browser öffnen")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08))

                Divider()

                // Embedded WebKit Raumfinder
                ZStack {
                    EmbeddedWebView(
                        url: activeMapURL,
                        isLoading: $isMapLoading,
                        targetRoomKey: selectedRoomKey,
                        targetRoomQuery: roomQuery
                    )
                        #if os(iOS)
                        .frame(height: 480)
                        #elseif os(macOS)
                        .frame(height: 560)
                        #endif

                    if isMapLoading {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("LMU Raumplan lädt...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal)

            // Direct Link Attribution
            HStack {
                Text("Offizielle Raumpläne der LMU München (lmu.de/raumfinder)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Link("lmu.de/raumfinder ↗", destination: URL(string: "https://www.lmu.de/raumfinder/#/")!)
                    .font(.caption2)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Buildings Directory & Guide View

    private var buildingsGuideView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Campus Gebäude & Orientierung")
                .font(.headline)
                .padding(.horizontal)

            ForEach(buildings) { building in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(building.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(building.address)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        HStack(spacing: 6) {
                            Button {
                                selectedBuildingCode = building.lmuRaumfinderCode
                                selectedRoomKey = nil
                                viewMode = .internalMap
                            } label: {
                                Label("Raumplan", systemImage: "map.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button {
                                if let url = URL(string: building.mapsURL) {
                                    openURL(url)
                                }
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("In Apple Maps öffnen")
                        }
                    }

                    Text(building.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text(building.floorRule)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }

    private func switchToBuildingFromDecoded() {
        if let decoded = decodedResult {
            selectedBuildingCode = decoded.lmuRaumfinderCode
            selectedRoomKey = decoded.lmuRoomKey
        } else {
            selectedBuildingCode = "bw0000" // Hauptgebäude GSP 1
            selectedRoomKey = nil
        }
        viewMode = .internalMap
    }
}
