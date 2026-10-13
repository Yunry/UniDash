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
        return URL(string: "https://www.lmu.de/raumfinder/#/building/\(selectedBuildingCode)/map")!
    }

    private var decodedResult: (building: String, floor: String, tip: String, raumfinderURL: String)? {
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
                    TextField("Raumnummer eingeben (z.B. B 201, A 014, Theresienstr. 39)...", text: $roomQuery)
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

                // Instant Decoded Room Info Pill
                if let result = decodedResult {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.building)
                                .font(.subheadline)
                                .fontWeight(.bold)

                            HStack(spacing: 8) {
                                Label(result.floor, systemImage: "stairs")
                                    .font(.caption)
                                    .foregroundStyle(.blue)

                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Label(result.tip, systemImage: "tram.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Quick Jump into Internal Raumfinder Map
                            HStack(spacing: 8) {
                                Button {
                                    switchToBuildingFromDecoded()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "map.fill")
                                        Text("Auf Raumkarte öffnen")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                if let current = currentBuilding, let url = URL(string: current.mapsURL) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                            Text("Apple Maps")
                                        }
                                        .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
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
            EmbeddedWebView(url: activeMapURL, isLoading: $isMapLoading)
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
                    EmbeddedWebView(url: activeMapURL, isLoading: $isMapLoading)
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
        let clean = roomQuery.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.contains("THERESIEN") || clean.contains("TH39") || clean.contains("TH41") {
            selectedBuildingCode = "bw1003"
        } else if clean.contains("LEOPOLD") || clean.contains("LEO13") {
            selectedBuildingCode = "bw0601"
        } else if clean.contains("OETTINGEN") || clean.contains("OETT") {
            selectedBuildingCode = "bw7070"
        } else if clean.contains("JURIDICUM") || clean.contains("PROF") {
            selectedBuildingCode = "bw0420"
        } else {
            selectedBuildingCode = "bw0000" // Hauptgebäude GSP 1
        }
        viewMode = .internalMap
    }
}
