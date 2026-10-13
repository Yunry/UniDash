//
//  TimetableImportView.swift
//  UniDash
//
//  PDF timetable file selection, PDFKit preview, 2D spatial extraction,
//  and integrated review & save workflow (no nested sheets, no duplicate loops).
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import SwiftData

struct TimetableImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    enum ImportStep {
        case selectPDF
        case reviewParsed
    }

    @State private var currentStep: ImportStep = .selectPDF
    @State private var selectedFileURL: URL? = nil
    @State private var pdfDocument: PDFDocument? = nil
    @State private var isImporting: Bool = false
    @State private var isParsing: Bool = false
    @State private var parsedEntries: [TimetableEntry] = []
    @State private var errorMessage: String? = nil

    // Import Configuration
    @State private var clearExistingSchedule: Bool = true
    @State private var syncToAppleCalendar: Bool = false
    @State private var selectedCalendarName: String = CalendarSyncService.defaultCalendarName
    @State private var isSyncingCalendar: Bool = false

    // Semester Dates (WS 2026/27 default)
    @State private var semesterStartDate: Date = {
        let comp = DateComponents(year: 2026, month: 10, day: 12)
        return Calendar.current.date(from: comp) ?? Date()
    }()

    @State private var semesterEndDate: Date = {
        let comp = DateComponents(year: 2027, month: 2, day: 5)
        return Calendar.current.date(from: comp) ?? Date()
    }()

    private let parser = PDFScheduleParser.shared

    private var selectedEntriesCount: Int {
        parsedEntries.filter { $0.isSelected }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .selectPDF:
                    selectPDFView
                case .reviewParsed:
                    reviewParsedView
                }
            }
            .navigationTitle(currentStep == .selectPDF ? "Stundenplan importieren" : "Stundenplan überprüfen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                if currentStep == .reviewParsed {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            saveScheduleAndDismiss()
                        } label: {
                            HStack(spacing: 4) {
                                if isSyncingCalendar {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text("In Stundenplan übernehmen (\(selectedEntriesCount))")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(selectedEntriesCount == 0 || isSyncingCalendar)
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
        #if os(macOS)
        .frame(minWidth: 780, idealWidth: 880, maxWidth: 1100, minHeight: 600, idealHeight: 700, maxHeight: 900)
        #endif
    }

    // MARK: - Step 1: Select & Preview PDF

    private var selectPDFView: some View {
        VStack(spacing: 0) {
            if let document = pdfDocument {
                // PDF Preview with file info
                VStack(spacing: 8) {
                    HStack {
                        Label(selectedFileURL?.lastPathComponent ?? "Stundenplan.pdf", systemImage: "doc.text.fill")
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        Text("\(document.pageCount) Seite(n)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Andere Datei wählen") {
                            isImporting = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    PDFKitRepresentedView(document: document)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal)
                }
            } else {
                // Upload Dropzone
                VStack(spacing: 20) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                    }

                    VStack(spacing: 8) {
                        Text("Uni-Stundenplan importieren")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Laden Sie Ihren offiziellen PDF-Stundenplan hoch (z.B. LMU München, TUM, HISinOne, CampusOnline).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    VStack(spacing: 12) {
                        Button(action: { isImporting = true }) {
                            Label("PDF-Stundenplan auswählen", systemImage: "doc.badge.plus")
                                .font(.headline)
                                .frame(maxWidth: 300)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: loadLMUSamplePDF) {
                            Label("LMU WiSe 2026/27 (PDF) testen", systemImage: "sparkles")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            // Bottom Action Bar when PDF loaded
            if pdfDocument != nil {
                VStack(spacing: 12) {
                    Divider()
                    HStack {
                        Button(action: {
                            self.pdfDocument = nil
                            self.selectedFileURL = nil
                        }) {
                            Text("Zurücksetzen")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: parseCurrentDocument) {
                            HStack {
                                if isParsing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                    Text("Analysiere Raster...")
                                } else {
                                    Image(systemName: "wand.and.stars")
                                    Text("Termine extrahieren & überprüfen →")
                                }
                            }
                            .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isParsing)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .background(.bar)
            }
        }
    }

    // MARK: - Step 2: Review & Edit Parsed Entries

    private var reviewParsedView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Status Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(parsedEntries.count) Lehrveranstaltungen erkannt")
                                    .font(.headline)
                                Text("Wintersemester 2026/27")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                withAnimation { currentStep = .selectPDF }
                            } label: {
                                Label("Anderes PDF", systemImage: "arrow.uturn.backward")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                        }

                        Text("Überprüfe die Details und passe sie vor der Übernahme nach Bedarf an.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Settings & Duplication Protection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Einstellungen & Zeitraum")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Toggle(isOn: $clearExistingSchedule) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bestehenden Stundenplan vorher leeren (Empfohlen)")
                                    .fontWeight(.medium)
                                Text("Verhindert doppelte Vorlesungseinträge, falls bereits Kurse gespeichert sind.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Toggle(isOn: $syncToAppleCalendar) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auch direkt in Apple Kalender synchronisieren")
                                    .fontWeight(.medium)
                                Text("Trägt die Kurse wöchentlich in den Kalender 'Uni Schedule' ein.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        #if os(macOS)
                        HStack(spacing: 16) {
                            DatePicker("Semesterbeginn:", selection: $semesterStartDate, displayedComponents: .date)
                            DatePicker("Vorlesungsende:", selection: $semesterEndDate, displayedComponents: .date)
                        }
                        .font(.subheadline)
                        #else
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker("Semesterbeginn:", selection: $semesterStartDate, displayedComponents: .date)
                            DatePicker("Vorlesungsende:", selection: $semesterEndDate, displayedComponents: .date)
                        }
                        .font(.subheadline)
                        #endif

                        HStack {
                            Button("Alle auswählen (\(parsedEntries.count))") {
                                for i in 0..<parsedEntries.count {
                                    parsedEntries[i].isSelected = true
                                }
                            }
                            .font(.footnote)
                            .buttonStyle(.borderless)

                            Text("•")
                                .foregroundStyle(.secondary)

                            Button("Alle abwählen") {
                                for i in 0..<parsedEntries.count {
                                    parsedEntries[i].isSelected = false
                                }
                            }
                            .font(.footnote)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(selectedEntriesCount) von \(parsedEntries.count) aktiv")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    )

                    // List of parsed courses
                    VStack(spacing: 10) {
                        HStack {
                            Text("Erkannte Kurse (\(parsedEntries.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                            Button {
                                addEmptyCourse()
                            } label: {
                                Label("Kurs hinzufügen", systemImage: "plus.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }

                        if parsedEntries.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                                Text("Keine Kurse gefunden.")
                                    .foregroundStyle(.secondary)
                                Button("Beispiel-Kurse laden") {
                                    parsedEntries = TimetableEntry.sampleEntries
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            ForEach($parsedEntries) { $entry in
                                TimetableEntryCard(entry: $entry, onDelete: {
                                    if let idx = parsedEntries.firstIndex(where: { $0.id == entry.id }) {
                                        parsedEntries.remove(at: idx)
                                    }
                                })
                            }
                        }
                    }
                }
                .padding()
            }

            // Bottom sticky action bar
            Divider()
            HStack {
                Button("Abbrechen") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    saveScheduleAndDismiss()
                } label: {
                    HStack(spacing: 6) {
                        if isSyncingCalendar {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Image(systemName: "checkmark")
                        Text("In Stundenplan übernehmen (\(selectedEntriesCount) Kurse)")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedEntriesCount == 0 || isSyncingCalendar)
            }
            .padding()
            .background(.bar)
        }
    }

    // MARK: - Actions

    private func addEmptyCourse() {
        let colors = ["#3B82F6", "#10B981", "#6366F1", "#EC4899", "#F59E0B"]
        let newEntry = TimetableEntry(
            courseTitle: "Neue Lehrveranstaltung",
            dayOfWeek: .monday,
            startTime: "10:00",
            endTime: "12:00",
            room: "Hauptgebäude",
            instructor: nil,
            courseType: "Vorlesung",
            colorHex: colors.randomElement() ?? "#3B82F6"
        )
        parsedEntries.append(newEntry)
    }

    private func saveScheduleAndDismiss() {
        // 1. Clear existing schedule if user opted in (prevents duplicates)
        if clearExistingSchedule {
            let descriptor = FetchDescriptor<ScheduleItem>()
            if let existing = try? modelContext.fetch(descriptor) {
                for item in existing {
                    modelContext.delete(item)
                }
            }
        }

        // 2. Insert selected parsed entries
        let selected = parsedEntries.filter { $0.isSelected }
        for entry in selected {
            let item = ScheduleItem(
                courseTitle: entry.courseTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                dayOfWeek: entry.dayOfWeek,
                startTime: entry.startTime,
                endTime: entry.endTime,
                room: entry.room.trimmingCharacters(in: .whitespacesAndNewlines),
                instructor: entry.instructor?.trimmingCharacters(in: .whitespacesAndNewlines),
                courseType: entry.courseType ?? "Vorlesung",
                colorHex: entry.colorHex
            )
            modelContext.insert(item)
        }

        try? modelContext.save()

        // 3. Optional Calendar Sync
        if syncToAppleCalendar {
            isSyncingCalendar = true
            Task {
                do {
                    _ = try await CalendarSyncService.shared.syncEvents(
                        entries: selected,
                        semesterStartDate: semesterStartDate,
                        semesterEndDate: semesterEndDate,
                        targetCalendarName: selectedCalendarName,
                        clearExisting: true
                    )
                } catch {
                    // Ignore background sync errors on dismissal
                }
                await MainActor.run {
                    isSyncingCalendar = false
                    dismiss()
                }
            }
        } else {
            // Dismiss immediately
            dismiss()
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            self.selectedFileURL = url
            self.errorMessage = nil

            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }

            if let doc = PDFDocument(url: url) {
                self.pdfDocument = doc
                // Auto-trigger parsing for immediate preview
                parseCurrentDocument()
            } else {
                self.errorMessage = "Konnte das PDF-Dokument nicht laden."
            }
        } catch {
            self.errorMessage = "Dateiauswahl fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func parseCurrentDocument() {
        guard let doc = pdfDocument else {
            self.errorMessage = "Kein PDF-Dokument ausgewählt."
            return
        }

        isParsing = true
        errorMessage = nil

        let url = selectedFileURL
        Task {
            let isScoped = url?.startAccessingSecurityScopedResource() ?? false
            defer {
                if isScoped {
                    url?.stopAccessingSecurityScopedResource()
                }
            }

            let entries = parser.parse(document: doc)

            await MainActor.run {
                self.isParsing = false
                if entries.isEmpty {
                    self.parsedEntries = TimetableEntry.sampleEntries
                    self.errorMessage = "Aus dem PDF konnte kein Text extrahiert werden. Beispiel-Einträge geladen."
                } else {
                    self.parsedEntries = entries
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.currentStep = .reviewParsed
                }
            }
        }
    }

    private func loadLMUSamplePDF() {
        var candidates: [URL?] = [
            Bundle.main.url(forResource: "stundenplan_ba_wise_202627", withExtension: "pdf"),
            Bundle.main.url(forResource: "LMU_Stundenplan_WS24", withExtension: "pdf")
        ]

        #if targetEnvironment(simulator) || DEBUG
        // Fallback for SwiftUI Previews and Xcode debug runs
        let currentFile = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        candidates.append(projectRoot.appendingPathComponent("Resources/stundenplan_ba_wise_202627.pdf"))
        candidates.append(projectRoot.appendingPathComponent("Resources/LMU_Stundenplan_WS24.pdf"))
        #endif

        guard let url = candidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            self.errorMessage = "Muster-Stundenplan LMU konnte nicht geladen werden."
            return
        }

        self.selectedFileURL = url
        self.errorMessage = nil

        if let doc = PDFDocument(url: url) {
            self.pdfDocument = doc
            parseCurrentDocument()
        } else {
            self.errorMessage = "Konnte das PDF-Dokument nicht initialisieren."
        }
    }
}

// MARK: - Modern Course Row Card

private struct TimetableEntryCard: View {
    @Binding var entry: TimetableEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button {
                entry.isSelected.toggle()
            } label: {
                Image(systemName: entry.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.isSelected ? Color.blue : Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            // Color bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: entry.colorHex))
                .frame(width: 4)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: Day, Time & Delete
                HStack(spacing: 6) {
                    Picker("Tag", selection: $entry.dayOfWeek) {
                        ForEach(DayOfWeek.allCases) { day in
                            Text(day.localizedName).tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 110, alignment: .leading)

                    HStack(spacing: 2) {
                        TextField("Start", text: $entry.startTime)
                            .frame(width: 48)
                            .textFieldStyle(.roundedBorder)
                        Text("–")
                            .foregroundStyle(.secondary)
                        TextField("Ende", text: $entry.endTime)
                            .frame(width: 48)
                            .textFieldStyle(.roundedBorder)
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .help("Diesen Kurs entfernen")
                }

                // Row 2: Title
                TextField("Kurstitel", text: $entry.courseTitle)
                    .font(.headline)
                    .textFieldStyle(.plain)
                    .padding(4)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Row 3: Room, Instructor, Type
                #if os(macOS)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        TextField("Raum", text: $entry.room)
                            .font(.caption)
                            .textFieldStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {
                        Image(systemName: "person")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        TextField("Dozent (optional)", text: Binding(
                            get: { entry.instructor ?? "" },
                            set: { entry.instructor = $0.isEmpty ? nil : $0 }
                        ))
                        .font(.caption)
                        .textFieldStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Typ", text: Binding(
                        get: { entry.courseType ?? "Vorlesung" },
                        set: { entry.courseType = $0 }
                    ))
                    .font(.caption)
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                }
                #else
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        TextField("Raum", text: $entry.room)
                            .font(.caption)
                            .textFieldStyle(.plain)

                        Spacer()

                        TextField("Typ", text: Binding(
                            get: { entry.courseType ?? "Vorlesung" },
                            set: { entry.courseType = $0 }
                        ))
                        .font(.caption)
                        .frame(width: 85)
                        .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        TextField("Dozent (optional)", text: Binding(
                            get: { entry.instructor ?? "" },
                            set: { entry.instructor = $0.isEmpty ? nil : $0 }
                        ))
                        .font(.caption)
                        .textFieldStyle(.plain)
                    }
                }
                #endif
            }
        }
        .padding(12)
        .background(entry.isSelected ? Color.secondary.opacity(0.06) : Color.secondary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(entry.isSelected ? Color.blue.opacity(0.25) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
