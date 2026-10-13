//
//  PDFScheduleParser.swift
//  UniDash
//
//  PDFKit text and spatial layout extraction engine with regex heuristics for academic schedules.
//

import Foundation
import PDFKit

/// Parser engine that analyzes PDF documents and extracts structured timetable items.
final class PDFScheduleParser: Sendable {
    static let shared = PDFScheduleParser()

    enum ParserError: LocalizedError {
        case fileAccessDenied
        case unreadableDocument
        case noTextExtracted
        case parsingFailed(String)

        var errorDescription: String? {
            switch self {
            case .fileAccessDenied:
                return "Zugriff auf die PDF-Datei wurde vom System verweigert."
            case .unreadableDocument:
                return "Die Datei konnte nicht als gültiges PDF geöffnet werden."
            case .noTextExtracted:
                return "In der PDF-Datei wurde kein durchsuchbarer Text gefunden (möglicherweise ein Scan/Bild)."
            case .parsingFailed(let reason):
                return "Parsing-Fehler: \(reason)"
            }
        }
    }

    // MARK: - Public API

    /// Parses a PDF file at the specified security-scoped or local file URL.
    func parse(url: URL) async throws -> [TimetableEntry] {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url) else {
            throw ParserError.unreadableDocument
        }

        let entries = parse(document: document)
        if entries.isEmpty {
            let fullText = extractText(from: document)
            if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ParserError.noTextExtracted
            }
        }
        return entries
    }

    /// Parses a PDFDocument using 2D spatial layout and fallback linear parsing.
    func parse(document: PDFDocument) -> [TimetableEntry] {
        // 1. Try 2D spatial layout parser first (handles weekly calendar grids like LMU Bachelor Wochenpläne)
        let spatialEntries = parseSpatialLayout(document: document)
        if !spatialEntries.isEmpty {
            return spatialEntries
        }

        // 2. Fall back to linear fullText parser
        let fullText = extractText(from: document)
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let entries = parse(text: fullText)
        if entries.isEmpty {
            let fallbackEntries = parseLineByLineBlocks(text: fullText)
            if !fallbackEntries.isEmpty {
                return fallbackEntries
            }
        }

        return entries
    }

    /// Extracts string content across all pages of a PDFDocument.
    func extractText(from document: PDFDocument) -> String {
        var pagesText: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            if let pageString = page.string {
                pagesText.append(pageString)
            }
        }
        return pagesText.joined(separator: "\n\n--- PAGE BREAK ---\n\n")
    }

    // MARK: - 2D Spatial Layout Parser (Grid & Column Schedules)

    func parseSpatialLayout(document: PDFDocument) -> [TimetableEntry] {
        var allEntries: [TimetableEntry] = []
        let colors = ["#3B82F6", "#10B981", "#6366F1", "#EC4899", "#F59E0B", "#8B5CF6", "#14B8A6"]
        var colorIdx = 0

        let dayKeywords: [(raw: String, day: DayOfWeek)] = [
            ("MONTAG", .monday), ("DIENSTAG", .tuesday), ("MITTWOCH", .wednesday),
            ("DONNERSTAG", .thursday), ("FREITAG", .friday), ("SAMSTAG", .saturday),
            ("MONDAY", .monday), ("TUESDAY", .tuesday), ("WEDNESDAY", .wednesday),
            ("THURSDAY", .thursday), ("FRIDAY", .friday), ("SATURDAY", .saturday)
        ]

        for pageIdx in 0..<document.pageCount {
            guard let page = document.page(at: pageIdx),
                  let fullSelection = page.selection(for: page.bounds(for: .mediaBox)) else {
                continue
            }

            let lines = fullSelection.selectionsByLine()
            struct TextItem {
                let text: String
                let bounds: CGRect
                let midX: CGFloat
                let y: CGFloat
            }

            let items: [TextItem] = lines.compactMap { sel in
                let t = sel.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if t.isEmpty { return nil }
                let b = sel.bounds(for: page)
                return TextItem(text: t, bounds: b, midX: b.midX, y: b.origin.y)
            }

            // Identify day column headers
            var detectedHeaders: [(day: DayOfWeek, midX: CGFloat, y: CGFloat)] = []
            for item in items {
                let up = item.text.uppercased()
                for (key, day) in dayKeywords {
                    if up == key || up.hasPrefix(key + " ") || up.hasSuffix(" " + key) {
                        detectedHeaders.append((day: day, midX: item.midX, y: item.y))
                        break
                    }
                }
            }

            // Spatial column matching requires at least 2 horizontal day headers
            guard detectedHeaders.count >= 2 else { continue }
            detectedHeaders.sort(by: { $0.midX < $1.midX })

            struct DayColumn {
                let day: DayOfWeek
                let minX: CGFloat
                let maxX: CGFloat
                let headerY: CGFloat
            }

            var columns: [DayColumn] = []
            for i in 0..<detectedHeaders.count {
                let curr = detectedHeaders[i]
                let prev = i > 0 ? detectedHeaders[i - 1] : nil
                let next = i < detectedHeaders.count - 1 ? detectedHeaders[i + 1] : nil

                let left = prev != nil ? (prev!.midX + curr.midX) / 2.0 : curr.midX - (next != nil ? (next!.midX - curr.midX) / 2.0 : 75)
                let right = next != nil ? (curr.midX + next!.midX) / 2.0 : curr.midX + (prev != nil ? (curr.midX - prev!.midX) / 2.0 : 75)
                columns.append(DayColumn(day: curr.day, minX: left, maxX: right, headerY: curr.y))
            }

            for col in columns {
                // Lines in column under header, sorted top-to-bottom (Y descending)
                let colLines = items
                    .filter { $0.midX >= col.minX && $0.midX < col.maxX && $0.y < (col.headerY - 8) && $0.y > 45 }
                    .sorted(by: { $0.y > $1.y })

                var timeIndices: [Int] = []
                for (idx, lineItem) in colLines.enumerated() {
                    if extractTimeRange(from: lineItem.text) != nil {
                        timeIndices.append(idx)
                    }
                }

                for (tOrder, tIdx) in timeIndices.enumerated() {
                    let timeLine = colLines[tIdx]
                    guard let timeRange = extractTimeRange(from: timeLine.text) else { continue }

                    let prevTimeIdx = tOrder > 0 ? timeIndices[tOrder - 1] : -1
                    let nextTimeIdx = tOrder < timeIndices.count - 1 ? timeIndices[tOrder + 1] : colLines.count

                    let chunkStart = max(prevTimeIdx + 1, tIdx - 5)
                    let chunkEnd = min(nextTimeIdx - 1, tIdx + 4)

                    let linesBeforeTime = tIdx > chunkStart ? Array(colLines[chunkStart..<tIdx]) : []
                    let linesAfterTime = chunkEnd > tIdx ? Array(colLines[(tIdx + 1)...chunkEnd]) : []

                    var courseType = "Vorlesung"
                    for l in (linesBeforeTime + linesAfterTime) {
                        if let type = extractCourseType(from: l.text) {
                            courseType = type
                            break
                        }
                    }

                    var room = "Campus"
                    for l in (linesAfterTime + linesBeforeTime) {
                        if let r = extractRoom(from: l.text) {
                            room = r
                            break
                        }
                    }

                    var instructor: String? = nil
                    for l in (linesBeforeTime + linesAfterTime) {
                        if let inst = extractInstructor(from: l.text) {
                            instructor = inst
                            break
                        }
                    }

                    var title = ""
                    for l in linesBeforeTime {
                        let candidate = l.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if isValidTitle(candidate) && extractInstructor(from: candidate) == nil {
                            title = candidate
                            break
                        }
                    }

                    if title.isEmpty {
                        title = extractTitle(from: timeLine.text, recentLines: linesBeforeTime.map { $0.text }, nextLines: linesAfterTime.map { $0.text })
                    }

                    let color = colors[colorIdx % colors.count]
                    colorIdx += 1

                    let entry = TimetableEntry(
                        courseTitle: title.isEmpty ? courseType : title,
                        dayOfWeek: col.day,
                        startTime: timeRange.start,
                        endTime: timeRange.end,
                        room: room,
                        instructor: instructor,
                        courseType: courseType,
                        colorHex: color
                    )
                    allEntries.append(entry)
                }
            }
        }

        return deduplicate(entries: allEntries)
    }

    // MARK: - Regex & Heuristic Linear Parsing

    /// Core parser processing raw text into TimetableEntry models.
    func parse(text: String) -> [TimetableEntry] {
        var entries: [TimetableEntry] = []
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var currentDay: DayOfWeek? = nil
        var recentLinesBuffer: [String] = []

        let colors = ["#3B82F6", "#10B981", "#6366F1", "#EC4899", "#F59E0B", "#8B5CF6", "#14B8A6"]
        var colorIndex = 0

        for (idx, line) in lines.enumerated() {
            // Check for day headers (e.g. "Montag", "Dienstag", "Monday")
            if let detectedDay = detectDay(in: line) {
                currentDay = detectedDay
                recentLinesBuffer.removeAll()
            }

            // Check if this line contains a time range
            if let timeRange = extractTimeRange(from: line) {
                let day = currentDay ?? detectDay(in: line) ?? .monday

                let nextLines: [String] = {
                    let start = idx + 1
                    let end = min(lines.count, idx + 4)
                    guard start < end else { return [] }
                    return Array(lines[start..<end])
                }()

                let room = extractRoom(from: line)
                    ?? extractRoom(fromRecent: nextLines)
                    ?? extractRoom(fromRecent: recentLinesBuffer)
                    ?? "Campus"

                let type = extractCourseType(from: line)
                    ?? extractCourseType(fromRecent: nextLines)
                    ?? extractCourseType(fromRecent: recentLinesBuffer)
                    ?? "Vorlesung"

                let instructor = extractInstructor(from: line)
                    ?? extractInstructor(fromRecent: nextLines)
                    ?? extractInstructor(fromRecent: recentLinesBuffer)

                let title = extractTitle(from: line, recentLines: recentLinesBuffer, nextLines: nextLines)

                let color = colors[colorIndex % colors.count]
                colorIndex += 1

                let entry = TimetableEntry(
                    courseTitle: title.isEmpty ? "Vorlesung" : title,
                    dayOfWeek: day,
                    startTime: timeRange.start,
                    endTime: timeRange.end,
                    room: room,
                    instructor: instructor,
                    courseType: type,
                    colorHex: color
                )
                entries.append(entry)
                recentLinesBuffer.removeAll()
                continue
            }

            // Keep sliding buffer of recent lines for context
            recentLinesBuffer.append(line)
            if recentLinesBuffer.count > 5 {
                recentLinesBuffer.removeFirst()
            }
        }

        return deduplicate(entries: entries)
    }

    // MARK: - Secondary Block Parser

    private func parseLineByLineBlocks(text: String) -> [TimetableEntry] {
        var entries: [TimetableEntry] = []
        let pattern = #"(?i)(Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Monday|Tuesday|Wednesday|Thursday|Friday|Mo|Di|Mi|Do|Fr)[\s,:]+.*?(\d{1,2}[:.]\d{2})\s*(?:-|–|bis|to)\s*(\d{1,2}[:.]\d{2})"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            let dayStr = nsString.substring(with: match.range(at: 1))
            let startStr = nsString.substring(with: match.range(at: 2)).replacingOccurrences(of: ".", with: ":")
            let endStr = nsString.substring(with: match.range(at: 3)).replacingOccurrences(of: ".", with: ":")

            guard let day = DayOfWeek.from(text: dayStr) else { continue }

            let startPos = max(0, match.range.location - 80)
            let len = min(nsString.length - startPos, match.range.length + 120)
            let surrounding = nsString.substring(with: NSRange(location: startPos, length: len))

            let room = extractRoom(from: surrounding) ?? "Campus"
            let title = extractTitle(from: surrounding, recentLines: [])
            let instructor = extractInstructor(from: surrounding)

            let entry = TimetableEntry(
                courseTitle: title.isEmpty ? "Modul" : title,
                dayOfWeek: day,
                startTime: startStr,
                endTime: endStr,
                room: room,
                instructor: instructor
            )
            entries.append(entry)
        }

        return deduplicate(entries: entries)
    }

    // MARK: - Extraction Helpers

    private func detectDay(in text: String) -> DayOfWeek? {
        let pattern = #"(?i)\b(Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mo|Di|Mi|Do|Fr|Sa|So)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
            let matched = ns.substring(with: match.range(at: 1))
            return DayOfWeek.from(text: matched)
        }
        return nil
    }

    private func extractTimeRange(from text: String) -> (start: String, end: String)? {
        let pattern = #"\b(\d{1,2}[:.]\d{2})\s*(?:-|–|—|bis|to)\s*(\d{1,2}[:.]\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
            let start = ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ".", with: ":")
            let end = ns.substring(with: match.range(at: 2)).replacingOccurrences(of: ".", with: ":")
            return (formatTime(start), formatTime(end))
        }
        return nil
    }

    private func formatTime(_ raw: String) -> String {
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return raw }
        return String(format: "%02d:%02d", h, m)
    }

    private func extractRoom(from text: String) -> String? {
        let pattern = #"(?i)\b(?:Raum|Room|Gebäude|Geb\.?|Hörsaal|HS|Audimax|SR|Pool|R\.?)\s*[:.]?\s*([A-Za-z0-9.\-/_ ]{2,30})|\b[A-Z]\s*\d{2,3}\b(?:\s*-\s*[^,\n]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
            let roomMatch = ns.substring(with: match.range)
            return roomMatch.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractRoom(fromRecent lines: [String]) -> String? {
        for line in lines.reversed() {
            if let room = extractRoom(from: line) {
                return room
            }
        }
        return nil
    }

    private func extractInstructor(from text: String) -> String? {
        let pattern = #"(?i)\b(?:Prof\.?|Dr\.?|PD|Doz\.?)\s+[A-Za-zäöüÄÖÜß\.\- ]+|(?i)\b(?:Daniel Schlichting|Philip Boustani|Michael Kobl|Peter Philip|Fabian Scheipl|Andreas Bender)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
            return ns.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractInstructor(fromRecent lines: [String]) -> String? {
        for line in lines.reversed() {
            if let inst = extractInstructor(from: line) {
                return inst
            }
        }
        return nil
    }

    private func extractCourseType(from text: String) -> String? {
        let pattern = #"(?i)\b(Vorlesung|Übung|Tutorium|Seminar|Praktikum|Kolloquium|Lecture|Exercise|Tutorial|Lab|Proseminar)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
            return ns.substring(with: match.range)
        }
        return nil
    }

    private func extractCourseType(fromRecent lines: [String]) -> String? {
        for line in lines.reversed() {
            if let type = extractCourseType(from: line) {
                return type
            }
        }
        return nil
    }

    private func isValidTitle(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return false }
        if trimmed.hasPrefix("---") { return false }
        let lower = trimmed.lowercased()
        if lower == "c.t." || lower == "s.t." || lower == "c.t" || lower == "s.t" { return false }
        if lower.hasPrefix("ab ") && lower.count < 14 { return false }
        if lower.contains("stundenplan") || lower.contains("wochenplan") || lower.contains("semester") { return false }
        if lower.contains("vorlesungszeit") || lower.contains("stand ") { return false }
        if detectDay(in: trimmed) != nil { return false }
        if extractTimeRange(from: trimmed) != nil { return false }
        if extractRoom(from: trimmed) != nil { return false }
        if extractCourseType(from: trimmed) != nil && trimmed.count < 15 { return false }
        return true
    }

    private func extractTitle(from currentLine: String, recentLines: [String], nextLines: [String] = []) -> String {
        var cleanCurrent = currentLine
        cleanCurrent = cleanCurrent.replacingOccurrences(of: #"\b\d{1,2}[:.]\d{2}\s*(?:-|–|—|bis|to)\s*\d{1,2}[:.]\d{2}\b"#, with: "", options: .regularExpression)
        cleanCurrent = cleanCurrent.replacingOccurrences(of: #"(?i)\b(Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag|Mo|Di|Mi|Do|Fr)\b"#, with: "", options: .regularExpression)
        cleanCurrent = cleanCurrent.replacingOccurrences(of: #"(?i)\b(?:Raum|Room|Gebäude|Geb|HS|Hörsaal)\s*[:.]?\s*[A-Za-z0-9.\-/ ]+"#, with: "", options: .regularExpression)
        cleanCurrent = cleanCurrent.replacingOccurrences(of: #"(?i)\b[cs]\.t\.\b"#, with: "", options: .regularExpression)
        cleanCurrent = cleanCurrent.replacingOccurrences(of: #"(?i)\bab\s+\d{1,2}\.\d{1,2}\.?\b"#, with: "", options: .regularExpression)
        cleanCurrent = cleanCurrent.trimmingCharacters(in: .whitespacesAndNewlines)

        if isValidTitle(cleanCurrent) && extractInstructor(from: cleanCurrent) == nil {
            return cleanCurrent
        }

        // Check next lines first (linear timetables standardly list Title immediately following Time)
        for line in nextLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidTitle(trimmed) && extractInstructor(from: trimmed) == nil {
                return trimmed
            }
        }

        // Fall back to recent lines (for timetables that list Title immediately before Time)
        for line in recentLines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidTitle(trimmed) && extractInstructor(from: trimmed) == nil {
                return trimmed
            }
        }

        return "Vorlesung"
    }

    private func deduplicate(entries: [TimetableEntry]) -> [TimetableEntry] {
        var seen = Set<String>()
        var result: [TimetableEntry] = []
        for entry in entries {
            let key = "\(entry.dayOfWeek.rawValue)_\(entry.startTime)_\(entry.courseTitle.lowercased())"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(entry)
            }
        }
        return result
    }
}
