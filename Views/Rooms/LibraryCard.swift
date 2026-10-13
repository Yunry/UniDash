//
//  LibraryCard.swift
//  UniDash
//
//  Card component for campus libraries: real occupancy from the UB-Platzfinder
//  (if available), opening status, contact info, and seat reservation.
//

import SwiftUI

struct LibraryCard: View {
    let library: CampusLibrary
    let occupancy: LibraryOccupancy?
    let isLoadingOccupancy: Bool
    let now: Date
    var onBookInApp: () -> Void
    var onOpenInSafari: () -> Void

    private var isOpen: Bool { library.isOpen(at: now) }

    private var accentColor: Color {
        guard isOpen else { return .secondary }
        return occupancy?.level.color ?? .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            occupancySection
            statusAndAddress
            if !library.equipment.isEmpty { equipmentBadges }
            Divider()
            actions
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: "books.vertical.fill")
                    .font(.title3)
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(library.name)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(library.campusArea)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    // MARK: - Occupancy

    @ViewBuilder
    private var occupancySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !isOpen {
                placeholderRow(icon: "moon.zzz.fill", text: "Derzeit geschlossen – keine Auslastung")
            } else if let occ = occupancy {
                HStack {
                    Label(occ.level.rawValue, systemImage: occ.level.icon)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(occ.level.color)
                    Spacer()
                    Text("\(occ.occupiedPercent) % belegt")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                ProgressView(value: Double(occ.occupiedPercent), total: 100)
                    .tint(occ.level.color)
                    .accessibilityLabel("Auslastung \(occ.occupiedPercent) Prozent")

                HStack {
                    if let free = occ.freeSeats, let total = occ.totalSeats {
                        Text("Ca. \(free) von \(total) Plätzen frei")
                    }
                    Spacer()
                    Text("Stand \(occ.fetchedAt.formatted(date: .omitted, time: .shortened))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else if isLoadingOccupancy, library.occupancyFeedID != nil {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Auslastung wird geladen…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if library.occupancyFeedID == nil {
                placeholderRow(icon: "sensor.fill", text: "Für diesen Standort gibt es keine Live-Auslastung")
            } else {
                placeholderRow(icon: "wifi.exclamationmark", text: "Live-Auslastung derzeit nicht verfügbar")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func placeholderRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Status, Address, Contact

    private var statusAndAddress: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOpen ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(library.statusText(at: now))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOpen ? Color.green : Color.red)
            }

            Text(library.openingHoursDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(library.address, systemImage: "mappin.and.ellipse")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                if let phone = library.phone, let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                    Link(destination: url) {
                        Label(phone, systemImage: "phone.fill")
                    }
                }
                if let email = library.email, let url = URL(string: "mailto:\(email)") {
                    Link(destination: url) {
                        Label("E-Mail", systemImage: "envelope.fill")
                    }
                }
            }
            .font(.caption2)
        }
    }

    private var equipmentBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(library.equipment) { equip in
                    Label(equip.rawValue, systemImage: equip.icon)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 10) {
            if library.reservationURL != nil {
                Button(action: onBookInApp) {
                    Label("Platz reservieren (Anny)", systemImage: "chair.lounge.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Keine Reservierung nötig")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: onOpenInSafari) {
                Image(systemName: "safari")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .help("Standortseite der UB öffnen")
            .accessibilityLabel("Standortseite der UB öffnen")
        }
        .controlSize(.regular)
    }
}
