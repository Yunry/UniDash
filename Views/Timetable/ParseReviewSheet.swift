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
                        Button {
                            showAddEntrySheet = true
                        } label: {
                            Label("Kurs hinzufügen", systemImage: "plus")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                entry.isSelected.toggle()
            } label: {
                Image(systemName: entry.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.isSelected ? Color.blue : Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
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
                        .frame(width: 58)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)

                    Text("–")
                        .foregroundStyle(.secondary)

                    TextField("Ende", text: $entry.endTime)
                        .frame(width: 58)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                }
                .font(.subheadline)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        TextField("Raum", text: $entry.room)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }

                    TextField("Veranstaltungstyp", text: Binding(
                        get: { entry.courseType ?? "Vorlesung" },
                        set: { entry.courseType = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(maxWidth: 110)
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

    private let courseTypes = ["Vorlesung", "Übung", "Tutorium", "Seminar", "Praktikum", "Kolloquium"]
    private let standardSlots = [
        ("08:15", "09:45"),
        ("10:15", "11:45"),
        ("12:15", "13:45"),
        ("14:15", "15:45"),
        ("16:15", "17:45"),
        ("18:15", "19:45")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Kursdetails")) {
                    LabeledContent("Kurstitel") {
                        TextField("z.B. Höhere Mathematik", text: $title)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Wochentag") {
                        Picker("", selection: $dayOfWeek) {
                            ForEach(DayOfWeek.allCases) { day in
                                Text(day.localizedName).tag(day)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Zeitraum") {
                            HStack(spacing: 6) {
                                TextField("08:15", text: $startTime)
                                    .frame(width: 58)
                                    .multilineTextAlignment(.center)
                                    .textFieldStyle(.roundedBorder)
                                Text("–")
                                    .foregroundStyle(.secondary)
                                TextField("09:45", text: $endTime)
                                    .frame(width: 58)
                                    .multilineTextAlignment(.center)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        // Quick lecture slot chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(standardSlots, id: \.0) { slot in
                                    Button("\(slot.0)–\(slot.1)") {
                                        startTime = slot.0
                                        endTime = slot.1
                                    }
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(startTime == slot.0 && endTime == slot.1 ? Color.blue : Color.secondary.opacity(0.12))
                                    .foregroundStyle(startTime == slot.0 && endTime == slot.1 ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)

                    LabeledContent("Raum / Hörsaal") {
                        TextField("z.B. Audimax", text: $room)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Veranstaltungstyp") {
                        Picker("", selection: $courseType) {
                            ForEach(courseTypes, id: \.self) { t in
                                Text(t).tag(t)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    LabeledContent("Dozent (optional)") {
                        TextField("z.B. Prof. Dr. Müller", text: $instructor)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .formStyle(.grouped)
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
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 480, idealHeight: 540)
        #endif
    }
}
