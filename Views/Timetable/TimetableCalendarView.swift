//
//  TimetableCalendarView.swift
//  UniDash
//
//  Interactive in-app timetable and calendar with Day/Week views, timeline cards, and PDF/EventKit sync.
//

import SwiftUI
import SwiftData

enum TimetableViewMode: String, CaseIterable, Identifiable {
    case day = "Tagesansicht"
    case week = "Wochenplan"

    var id: String { rawValue }
}

struct TimetableCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduleItem.startTime, order: .forward) private var allScheduleItems: [ScheduleItem]

    @State private var selectedDay: DayOfWeek = {
        // Defaults to today's weekday, or Monday if weekend
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        switch weekday {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .monday
        }
    }()

    @State private var viewMode: TimetableViewMode = .day
    @State private var showImportPDFSheet: Bool = false
    @State private var showCalendarPushSheet: Bool = false
    @State private var showAddClassSheet: Bool = false
    @State private var itemToEdit: ScheduleItem? = nil
    @State private var showDeleteAllConfirmation: Bool = false
    @AppStorage("hasInitializedSchedule") private var hasInitializedSchedule: Bool = false

    private var activeDays: [DayOfWeek] {
        let hasSaturday = allScheduleItems.contains { $0.dayOfWeek == .saturday }
        if hasSaturday {
            return [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        }
        return [.monday, .tuesday, .wednesday, .thursday, .friday]
    }

    private var itemsForSelectedDay: [ScheduleItem] {
        allScheduleItems
            .filter { $0.dayOfWeek == selectedDay }
            .sorted(by: { $0.startMinuteOfDay < $1.startMinuteOfDay })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - View Mode & Weekday Selector
                VStack(spacing: 8) {
                    HStack {
                        Picker("Ansicht", selection: $viewMode) {
                            ForEach(TimetableViewMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)

                    // Weekday Strip
                    if viewMode == .day {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(activeDays) { day in
                                    let count = allScheduleItems.filter { $0.dayOfWeek == day }.count
                                    let isToday = isDayToday(day)

                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedDay = day
                                        }
                                    } label: {
                                        VStack(spacing: 4) {
                                            HStack(spacing: 4) {
                                                Text(day.shortName)
                                                    .font(.subheadline)
                                                    .fontWeight(selectedDay == day ? .bold : .medium)

                                                if isToday {
                                                    Circle()
                                                        .fill(selectedDay == day ? .white : .blue)
                                                        .frame(width: 6, height: 6)
                                                }
                                            }

                                            Text("\(count) \(count == 1 ? "Kurs" : "Kurse")")
                                                .font(.caption2)
                                                .opacity(0.85)
                                        }
                                        .frame(minWidth: 62)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 10)
                                        .background(selectedDay == day ? Color.blue : Color.secondary.opacity(0.1))
                                        .foregroundStyle(selectedDay == day ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .background(.bar)

                Divider()

                // MARK: - Main Timetable Content
                if allScheduleItems.isEmpty {
                    emptyTimetableState
                } else if viewMode == .day {
                    dayAgendaView
                } else {
                    weekScheduleView
                }
            }
            .navigationTitle("Stundenplan")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddClassSheet = true
                        } label: {
                            Label("Kurs hinzufügen", systemImage: "plus")
                        }

                        Button {
                            showImportPDFSheet = true
                        } label: {
                            Label("Aus PDF importieren", systemImage: "doc.badge.plus")
                        }

                        Divider()

                        Button {
                            showCalendarPushSheet = true
                        } label: {
                            Label("In Apple Kalender exportieren", systemImage: "calendar.badge.plus")
                        }

                        Button {
                            deduplicateScheduleItems()
                        } label: {
                            Label("Duplikate bereinigen", systemImage: "sparkles")
                        }
                        .disabled(allScheduleItems.isEmpty)

                        Button {
                            loadSampleSchedule()
                        } label: {
                            Label("Beispiel-Stundenplan laden", systemImage: "arrow.clockwise")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label("Alle Einträge löschen", systemImage: "trash")
                        }
                        .disabled(allScheduleItems.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button {
                        showAddClassSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog(
                "Stundenplan zurücksetzen",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Alle Einträge löschen", role: .destructive) {
                    deleteAllScheduleItems()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Möchten Sie wirklich alle \(allScheduleItems.count) Lehrveranstaltungen aus Ihrem Stundenplan entfernen? Dies kann nicht rückgängig gemacht werden.")
            }
            .sheet(isPresented: $showImportPDFSheet) {
                TimetableImportView()
                    #if os(macOS)
                    .frame(minWidth: 780, idealWidth: 880, minHeight: 600, idealHeight: 700)
                    #endif
            }
            .sheet(isPresented: $showCalendarPushSheet) {
                CalendarPushView(
                    entries: allScheduleItems.map { $0.asTimetableEntry },
                    semesterStartDate: Date(),
                    semesterEndDate: Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
                )
                #if os(macOS)
                .frame(minWidth: 500, idealWidth: 560, minHeight: 480, idealHeight: 560)
                #endif
            }
            .sheet(isPresented: $showAddClassSheet) {
                AddScheduleItemModal(onSave: { newItem in
                    modelContext.insert(newItem)
                    try? modelContext.save()
                    hasInitializedSchedule = true
                })
                #if os(macOS)
                .frame(minWidth: 440, idealWidth: 480, minHeight: 500, idealHeight: 560)
                #endif
            }
            .sheet(item: $itemToEdit) { item in
                AddScheduleItemModal(
                    itemToEdit: item,
                    onSave: { _ in
                        try? modelContext.save()
                    },
                    onDelete: { toDelete in
                        modelContext.delete(toDelete)
                        try? modelContext.save()
                    }
                )
                #if os(macOS)
                .frame(minWidth: 440, idealWidth: 480, minHeight: 500, idealHeight: 560)
                #endif
            }
            .onAppear {
                deduplicateScheduleItems()
                if allScheduleItems.isEmpty && !hasInitializedSchedule {
                    loadSampleSchedule()
                }
            }
        }
    }

    // MARK: - Day Agenda View

    private var dayAgendaView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if itemsForSelectedDay.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Keine Lehrveranstaltungen am \(selectedDay.localizedName)")
                            .font(.headline)
                        Text("Genießen Sie die freie Zeit oder bereiten Sie Ihre Vorlesungen nach.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Kurs für \(selectedDay.localizedName) hinzufügen") {
                            showAddClassSheet = true
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    HStack {
                        Text("\(selectedDay.localizedName)s Plan")
                            .font(.headline)
                        Spacer()
                        Text("\(itemsForSelectedDay.count) Veranstaltungen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    ForEach(itemsForSelectedDay) { item in
                        ClassTimelineCard(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                itemToEdit = item
                            }
                            .contextMenu {
                                Button("Bearbeiten") {
                                    itemToEdit = item
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                    try? modelContext.save()
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Week Overview Grid View

    private var weekScheduleView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(activeDays) { day in
                    let dayItems = allScheduleItems
                        .filter { $0.dayOfWeek == day }
                        .sorted(by: { $0.startMinuteOfDay < $1.startMinuteOfDay })

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(day.localizedName)
                                .font(.headline)
                            if isDayToday(day) {
                                Text("Heute")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text("\(dayItems.count) Kurse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if dayItems.isEmpty {
                            Text("Keine Vorlesungen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(dayItems) { item in
                                    CompactClassRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            itemToEdit = item
                                        }
                                        .contextMenu {
                                            Button("Bearbeiten") {
                                                itemToEdit = item
                                            }
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                                try? modelContext.save()
                                            } label: {
                                                Label("Löschen", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyTimetableState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 54))
                .foregroundStyle(.blue)

            Text("Ihr persönlicher Stundenplan")
                .font(.title2)
                .fontWeight(.bold)

            Text("Importieren Sie Ihren Stundenplan direkt aus einer PDF-Datei oder erfassen Sie Ihre Vorlesungen manuell.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Button {
                    showImportPDFSheet = true
                } label: {
                    Label("PDF-Stundenplan importieren", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showAddClassSheet = true
                } label: {
                    Label("Kurs manuell hinzufügen", systemImage: "plus")
                        .font(.subheadline)
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)

                Button {
                    loadSampleSchedule()
                } label: {
                    Label("Beispiel-Stundenplan laden", systemImage: "sparkles")
                        .font(.subheadline)
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func isDayToday(_ day: DayOfWeek) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        return day.weekdayNumber == weekday
    }

    private func loadSampleSchedule() {
        for item in ScheduleItem.defaultSemesterSchedule {
            modelContext.insert(item)
        }
        try? modelContext.save()
        hasInitializedSchedule = true
    }

    private func deleteAllScheduleItems() {
        for item in allScheduleItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
        hasInitializedSchedule = true
    }

    private func deduplicateScheduleItems() {
        var seen = Set<String>()
        var duplicatesToDelete: [ScheduleItem] = []
        for item in allScheduleItems {
            let key = "\(item.dayOfWeekRaw)_\(item.startTime)_\(item.endTime)_\(item.courseTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
            if seen.contains(key) {
                duplicatesToDelete.append(item)
            } else {
                seen.insert(key)
            }
        }
        if !duplicatesToDelete.isEmpty {
            for dup in duplicatesToDelete {
                modelContext.delete(dup)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Class Timeline Card

struct ClassTimelineCard: View {
    let item: ScheduleItem

    var body: some View {
        HStack(spacing: 12) {
            // Color vertical indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: item.colorHex))
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    // Time Range
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("\(item.startTime) – \(item.endTime)")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                    Spacer()

                    // Course Type Pill
                    Text(item.courseType)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: item.colorHex).opacity(0.15))
                        .foregroundStyle(Color(hex: item.colorHex))
                        .clipShape(Capsule())
                }

                // Title
                Text(item.courseTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Location & Instructor
                HStack(spacing: 12) {
                    Label(item.room, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    if let instructor = item.instructor, !instructor.isEmpty {
                        Label(instructor, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.trailing, 10)
        }
        .padding(.leading, 8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Compact Class Row for Week View

struct CompactClassRow: View {
    let item: ScheduleItem

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: item.colorHex))
                .frame(width: 8, height: 8)

            Text("\(item.startTime) – \(item.endTime)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(item.courseTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            Text(item.room)
                .font(.caption2)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add / Edit Schedule Item Modal

struct AddScheduleItemModal: View {
    @Environment(\.dismiss) private var dismiss
    var itemToEdit: ScheduleItem?
    var onSave: (ScheduleItem) -> Void
    var onDelete: ((ScheduleItem) -> Void)? = nil

    @State private var courseTitle: String = ""
    @State private var dayOfWeek: DayOfWeek = .monday
    @State private var startTime: String = "08:15"
    @State private var endTime: String = "09:45"
    @State private var room: String = "Audimax 1"
    @State private var instructor: String = ""
    @State private var courseType: String = "Vorlesung"
    @State private var colorHex: String = "#3B82F6"

    private let colors = ["#3B82F6", "#10B981", "#6366F1", "#EC4899", "#F59E0B", "#8B5CF6", "#14B8A6"]
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
                Section(header: Text("Lehrveranstaltung")) {
                    LabeledContent("Kurstitel") {
                        TextField("z.B. Höhere Mathematik I", text: $courseTitle)
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
                        TextField("z.B. Audimax, A 140", text: $room)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Dozent (optional)") {
                        TextField("z.B. Prof. Dr. Müller", text: $instructor)
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
                }

                Section(header: Text("Farbe")) {
                    HStack(spacing: 14) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                    if colorHex.lowercased() == hex.lowercased() {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let existing = itemToEdit {
                    Section {
                        Button(role: .destructive) {
                            onDelete?(existing)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Diesen Kurs löschen", systemImage: "trash")
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(itemToEdit == nil ? "Kurs eintragen" : "Kurs bearbeiten")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if let existing = itemToEdit {
                            existing.courseTitle = courseTitle
                            existing.dayOfWeek = dayOfWeek
                            existing.startTime = startTime
                            existing.endTime = endTime
                            existing.room = room
                            existing.instructor = instructor.isEmpty ? nil : instructor
                            existing.courseType = courseType
                            existing.colorHex = colorHex
                            onSave(existing)
                        } else {
                            let newItem = ScheduleItem(
                                courseTitle: courseTitle.trimmingCharacters(in: .whitespaces).isEmpty ? "Neuer Kurs" : courseTitle,
                                dayOfWeek: dayOfWeek,
                                startTime: startTime,
                                endTime: endTime,
                                room: room.isEmpty ? "Campus" : room,
                                instructor: instructor.isEmpty ? nil : instructor,
                                courseType: courseType,
                                colorHex: colorHex
                            )
                            onSave(newItem)
                        }
                        dismiss()
                    }
                    .disabled(courseTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let item = itemToEdit {
                    self.courseTitle = item.courseTitle
                    self.dayOfWeek = item.dayOfWeek
                    self.startTime = item.startTime
                    self.endTime = item.endTime
                    self.room = item.room
                    self.instructor = item.instructor ?? ""
                    self.courseType = item.courseType
                    self.colorHex = item.colorHex
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 520, idealHeight: 580)
        #endif
    }
}
