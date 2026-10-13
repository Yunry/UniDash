//
//  ParseReviewSheet.swift
//  UniDash
//
//  Verification editor for parsed classes with recurrence configuration and inline editing.
//

import SwiftUI
import SwiftData

struct ParseReviewSheet: View {
    @Binding var entries: [TimetableEntry]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var semesterStartDate: Date = {
        var comp = Calendar.current.dateComponents([.year, .month], from: Date())
        let month = comp.month ?? 10
        if month >= 4 && month < 10 {
            comp.month = 4
            comp.day = 1
        } else {
            comp.month = 10
            comp.day = 1
        }
        return Calendar.current.date(from: comp) ?? Date()
    }()

    @State private var semesterEndDate: Date = {
        var comp = Calendar.current.dateComponents([.year, .month], from: Date())
        let month = comp.month ?? 10
        if month >= 4 && month < 10 {
            comp.month = 7
            comp.day = 20
        } else {
            let currentYear = comp.year ?? Calendar.current.component(.year, from: Date())
            comp.year = currentYear + (month >= 10 ? 1 : 0)
            comp.month = 2
            comp.day = 15
        }
        return Calendar.current.date(from: comp) ?? Date()
    }()

    @State private var showCalendarPushSheet: Bool = false
    @State private var showAddEntrySheet: Bool = false
    @State private var savedNotice: Bool = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Recurrence Settings
                Section(header: Text("Semester-Zeitraum & Wiederholung")) {
                    DatePicker("Semesterbeginn", selection: $semesterStartDate, displayedComponents: .date)
                    DatePicker("Vorlesungsende", selection: $semesterEndDate, displayedComponents: .date)

                    HStack {
                        Button(action: selectAll) {
                            Text("Alle auswählen")
                                .font(.footnote)
                        }
                        Spacer()
                        Button(action: deselectAll) {
                            Text("Alle abwählen")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.borderless)
                }

                // MARK: - Parsed Classes List
                Section(
                    header: HStack {
                        Text("Erkannte Kurse (\(entries.count))")
                        Spacer()
                        Button(action: { showAddEntrySheet = true }) {
                            Label("Kurs hinzufügen", systemImage: "plus.circle")
                                .font(.footnote)
                        }
                    },
                    footer: Text("Tippen Sie auf einen Eintrag, um Details zu korrigieren. Abgewählte Kurse werden nicht in den Kalender übertragen.")
                ) {
                    if entries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("Keine Kurse gefunden.")
                                .foregroundStyle(.secondary)
                            Button("Beispiel-Stundenplan laden") {
                                entries = TimetableEntry.sampleEntries
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach($entries) { $entry in
                            TimetableEntryRow(entry: $entry)
                        }
                        .onDelete(perform: deleteEntry)
                    }
                }
            }
            .navigationTitle("Stundenplan überprüfen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveToInAppSchedule()
                        dismiss()
                    } label: {
                        Text("Speichern")
                            .fontWeight(.semibold)
                    }
                    .disabled(entries.filter { $0.isSelected }.isEmpty)
                }
            }
            .sheet(isPresented: $showCalendarPushSheet) {
                CalendarPushView(
                    entries: entries,
                    semesterStartDate: semesterStartDate,
                    semesterEndDate: semesterEndDate
                )
                .frame(minWidth: 500, idealWidth: 560, minHeight: 480, idealHeight: 560)
            }
            .sheet(isPresented: $showAddEntrySheet) {
                AddTimetableEntryModal { newEntry in
                    entries.append(newEntry)
                }
                .frame(minWidth: 440, idealWidth: 480, minHeight: 500, idealHeight: 560)
            }
        }
        #if os(macOS)
        .frame(minWidth: 780, idealWidth: 880, minHeight: 600, idealHeight: 700)
        #endif
    }

    private func saveToInAppSchedule() {
        let selected = entries.filter { $0.isSelected }
        for entry in selected {
            let item = ScheduleItem(
                courseTitle: entry.courseTitle,
                dayOfWeek: entry.dayOfWeek,
                startTime: entry.startTime,
                endTime: entry.endTime,
                room: entry.room,
                instructor: entry.instructor,
                courseType: entry.courseType ?? "Vorlesung",
                colorHex: entry.colorHex
            )
            modelContext.insert(item)
        }
        try? modelContext.save()
    }

    private func selectAll() {
        for i in 0..<entries.count {
            entries[i].isSelected = true
        }
    }

    private func deselectAll() {
        for i in 0..<entries.count {
            entries[i].isSelected = false
        }
    }

    private func deleteEntry(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }
}

// MARK: - Entry Row Editor

struct TimetableEntryRow: View {
    @Binding var entry: TimetableEntry
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Toggle("", isOn: $entry.isSelected)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Kurstitel", text: $entry.courseTitle)
                        .font(.headline)

                    HStack(spacing: 6) {
                        Picker("Tag", selection: $entry.dayOfWeek) {
                            ForEach(DayOfWeek.allCases) { day in
                                Text(day.localizedName).tag(day)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Text("•")
                            .foregroundStyle(.secondary)

                        TextField("Start", text: $entry.startTime)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)

                        Text("–")
                            .foregroundStyle(.secondary)

                        TextField("Ende", text: $entry.endTime)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                    }
                    .font(.subheadline)

                    HStack(spacing: 8) {
                        Label {
                            TextField("Raum", text: $entry.room)
                                .textFieldStyle(.plain)
                        } icon: {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.blue)
                        }
                        .font(.caption)

                        TextField("Veranstaltungstyp", text: Binding(
                            get: { entry.courseType ?? "Vorlesung" },
                            set: { entry.courseType = $0 }
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Entry Modal

struct AddTimetableEntryModal: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (TimetableEntry) -> Void

    @State private var title: String = ""
    @State private var dayOfWeek: DayOfWeek = .monday
    @State private var startTime: String = "08:15"
    @State private var endTime: String = "09:45"
    @State private var room: String = "Hörsaal 1"
    @State private var courseType: String = "Vorlesung"
    @State private var instructor: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Kursdetails")) {
                    TextField("Kursname (z.B. Höhere Mathematik)", text: $title)
                    Picker("Wochentag", selection: $dayOfWeek) {
                        ForEach(DayOfWeek.allCases) { day in
                            Text(day.localizedName).tag(day)
                        }
                    }
                    HStack {
                        TextField("Startzeit (HH:mm)", text: $startTime)
                        TextField("Endzeit (HH:mm)", text: $endTime)
                    }
                    TextField("Raum / Hörsaal", text: $room)
                    TextField("Typ (Vorlesung, Übung, etc.)", text: $courseType)
                    TextField("Dozent (optional)", text: $instructor)
                }
            }
            .navigationTitle("Kurs hinzufügen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let newEntry = TimetableEntry(
                            courseTitle: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Neuer Kurs" : title,
                            dayOfWeek: dayOfWeek,
                            startTime: startTime,
                            endTime: endTime,
                            room: room.isEmpty ? "Campus" : room,
                            instructor: instructor.isEmpty ? nil : instructor,
                            courseType: courseType
                        )
                        onAdd(newEntry)
                        dismiss()
                    }
                }
            }
        }
    }
}
