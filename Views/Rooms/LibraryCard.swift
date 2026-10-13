//
//  LibraryCard.swift
//  UniDash
//
//  Rich card component for campus libraries displaying live occupancy meters,
//  opening hours status, facility tags, and seat reservation triggers.
//

import SwiftUI

struct LibraryCard: View {
    let library: CampusLibrary
    var onBookInApp: () -> Void
    var onOpenInSafari: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Code Badge & Name
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(library.occupancyLevel.color.opacity(0.14))
                        .frame(width: 46, height: 46)

                    Image(systemName: "books.vertical.fill")
                        .font(.title3)
                        .foregroundStyle(library.occupancyLevel.color)
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

            // Live Occupancy Progress Bar & Indicator
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: library.occupancyLevel.icon)
                            .font(.caption2)
                        Text(library.occupancyLevel.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(library.occupancyLevel.color)

                    Spacer()

                    Text("\(library.liveOccupancyPercentage)% belegt")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        library.occupancyLevel.color.opacity(0.8),
                                        library.occupancyLevel.color
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(library.liveOccupancyPercentage) / 100.0), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Ca. \(library.freeSeatsCount) von \(library.totalSeats) Plätzen frei")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Dynamic Opening Hours Status & Address
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(library.isOpenNow ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(library.isOpenNow ? "Jetzt geöffnet" : "Geschlossen")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(library.isOpenNow ? Color.green : Color.red)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(library.openingHoursDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(library.address)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Facilities & Equipment Badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(library.equipment) { equip in
                        HStack(spacing: 4) {
                            Image(systemName: equip.icon)
                            Text(equip.rawValue)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // Booking & Web Action Buttons
            HStack(spacing: 10) {
                Button(action: onBookInApp) {
                    HStack(spacing: 6) {
                        Image(systemName: "chair.lounge.fill")
                        Text("Platz buchen (Anny)")
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
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("In Safari mit Uni-SSO öffnen")
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}
