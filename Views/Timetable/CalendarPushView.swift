//
//  CalendarPushView.swift
//  UniDash
//
//  EventKit target calendar selection, permission handling, and weekly recurrence sync action.
//

import SwiftUI
import EventKit

struct CalendarPushView: View {
    let entries: [TimetableEntry]
    let semesterStartDate: Date
    let semesterEndDate: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject private var syncService = CalendarSyncService.shared

    @State private var selectedCalendarName: String = CalendarSyncService.defaultCalendarName
    @State private var clearExisting: Bool = true
    @State private var syncCompleted: Bool = false
    @State private var syncedCount: Int = 0
    @State private var errorMessage: String? = nil

    private var activeEntries: [TimetableEntry] {
        entries.filter { $0.isSelected }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Summary Section
                Section(header: Text("Übersicht")) {
                    LabeledContent {
                        Text("\(activeEntries.count) von \(entries.count)")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    } label: {
                        Label("Ausgewählte Kurse", systemImage: "books.vertical.fill")
                    }

                    LabeledContent {
                        Text("\(semesterStartDate.formatted(date: .abbreviated, time: .omitted)) – \(semesterEndDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Laufzeit", systemImage: "calendar")
                    }

                    LabeledContent {
                        Text("Wöchentlich")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Wiederholung", systemImage: "repeat")
                    }
                }

                // MARK: - Calendar Selection
                Section(
                    header: Text("Zielkalender"),
                    footer: Text("UniDash legt standardmäßig einen separaten Kalender 'Uni Schedule' an, um Ihre persönlichen Kalender sauber zu halten.")
                ) {
                    LabeledContent("Kalendername") {
                        TextField("z.B. Uni Schedule", text: $selectedCalendarName)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }

                    if !syncService.availableCalendars.isEmpty {
                        LabeledContent("Bestehender Kalender") {
                            Picker("", selection: $selectedCalendarName) {
                                Text("Uni Schedule (Empfohlen)").tag(CalendarSyncService.defaultCalendarName)
                                ForEach(syncService.availableCalendars, id: \.calendarIdentifier) { cal in
                                    Text(cal.title).tag(cal.title)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }

                    Toggle("Bestehende Termine im Zeitraum überschreiben", isOn: $clearExisting)
                }

                // MARK: - Permissions Check
                if !syncService.isAuthorized {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Kalenderzugriff erforderlich")
                                    .font(.headline)
                            }
                            Text("UniDash benötigt Schreibzugriff auf Ihren Kalender, um die Lehrveranstaltungen automatisch eintragen zu können.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Zugriff jetzt anfordern") {
                                Task {
                                    _ = await syncService.requestAccess()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: - Status & Success
                if syncCompleted {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)
                            Text("Erfolgreich synchronisiert!")
                                .font(.headline)
                            Text("\(syncedCount) wöchentliche Termine wurden in den Kalender '\(selectedCalendarName)' eingetragen.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                openCalendarApp()
                            } label: {
                                Label("Im Kalender anzeigen", systemImage: "calendar")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                // MARK: - Action Button
                Section {
                    Button(action: startSync) {
                        HStack(spacing: 8) {
                            Spacer()
                            if syncService.isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Synchronisiere...")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                Text("Jetzt in Kalender exportieren")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(syncService.isSyncing || activeEntries.isEmpty)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Kalender-Export")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, idealWidth: 560, minHeight: 480, idealHeight: 560)
        #endif
    }

    private func startSync() {
        errorMessage = nil
        Task {
            do {
                let count = try await syncService.syncEvents(
                    entries: entries,
                    semesterStartDate: semesterStartDate,
                    semesterEndDate: semesterEndDate,
                    targetCalendarName: selectedCalendarName,
                    clearExisting: clearExisting
                )
                self.syncedCount = count
                self.syncCompleted = true
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func openCalendarApp() {
        #if os(iOS)
        if let url = URL(string: "calshow:\(semesterStartDate.timeIntervalSinceReferenceDate)") {
            openURL(url)
        }
        #elseif os(macOS)
        if let url = URL(string: "ical:") {
            openURL(url)
        }
        #endif
    }
}
