//
//  AcademicTimelineView.swift
//  UniDash
//
//  Academic calendar deadlines, re-registration countdowns, and EventKit sync.
//

import SwiftUI

struct AcademicTimelineView: View {
    @State private var selectedSemesterIndex: Int = 0
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @Environment(\.openURL) private var openURL

    private let semesters = AcademicSemester.sampleSemesters

    private var currentSemester: AcademicSemester {
        guard selectedSemesterIndex < semesters.count else {
            return semesters[0]
        }
        return semesters[selectedSemesterIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Semester Selector
            Picker("Semester", selection: $selectedSemesterIndex) {
                ForEach(0..<semesters.count, id: \.self) { idx in
                    Text(semesters[idx].term).tag(idx)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Critical Alert Banner (if Re-Registration or Exam registration is active/upcoming)
            if let criticalDeadline = currentSemester.deadlines.first(where: { $0.isCritical && !$0.isPast }) {
                CriticalDeadlineBanner(deadline: criticalDeadline) {
                    addDeadlineToCalendar(criticalDeadline)
                }
                .padding(.horizontal)
            }

            // Deadlines List
            VStack(spacing: 12) {
                ForEach(currentSemester.deadlines) { deadline in
                    DeadlineRowCard(deadline: deadline, onSyncCalendar: {
                        addDeadlineToCalendar(deadline)
                    }, onOpenURL: {
                        if let urlStr = deadline.url, let url = URL(string: urlStr) {
                            openURL(url)
                        }
                    })
                }
            }
            .padding(.horizontal)
        }
        .alert("Kalender", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func addDeadlineToCalendar(_ deadline: AcademicDeadline) {
        Task {
            do {
                _ = try await CalendarSyncService.shared.saveDeadlineToCalendar(deadline: deadline)
                alertMessage = "„\(deadline.title)“ wurde mit Erinnerung in Ihren Apple Kalender eingetragen."
                showAlert = true
            } catch {
                alertMessage = "Fehler beim Kalender-Export: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

// MARK: - Critical Deadline Banner

struct CriticalDeadlineBanner: View {
    let deadline: AcademicDeadline
    var onSyncCalendar: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(deadline.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Text(deadline.statusBadgeText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }

                Text(deadline.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Deadline Row Card

struct DeadlineRowCard: View {
    let deadline: AcademicDeadline
    var onSyncCalendar: () -> Void
    var onOpenURL: () -> Void

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: "de_DE")
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(deadline.category.badgeColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: deadline.category.icon)
                        .font(.headline)
                        .foregroundStyle(deadline.category.badgeColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(deadline.title)
                            .font(.headline)
                        Spacer()
                        Text(deadline.statusBadgeText)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(deadline.category.badgeColor.opacity(0.15))
                            .foregroundStyle(deadline.category.badgeColor)
                            .clipShape(Capsule())
                    }

                    Text(deadline.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(dateFormatter.string(from: deadline.startDate)) – \(dateFormatter.string(from: deadline.endDate))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }

            Divider()

            HStack {
                if deadline.url != nil {
                    Button(action: onOpenURL) {
                        Label("Info-Webseite", systemImage: "arrow.up.right")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button(action: onSyncCalendar) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                        Text("In Apple Kalender")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
