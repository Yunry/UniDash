//
//  TimetableEntry.swift
//  UniDash
//
//  Transient model representing an extracted timetable class schedule item.
//

import Foundation
import EventKit

/// Represents the academic days of the week, with multi-language parsing support.
enum DayOfWeek: String, Codable, CaseIterable, Identifiable, Sendable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .monday: return "Montag"
        case .tuesday: return "Dienstag"
        case .wednesday: return "Mittwoch"
        case .thursday: return "Donnerstag"
        case .friday: return "Freitag"
        case .saturday: return "Samstag"
        case .sunday: return "Sonntag"
        }
    }

    var shortName: String {
        switch self {
        case .monday: return "Mo"
        case .tuesday: return "Di"
        case .wednesday: return "Mi"
        case .thursday: return "Do"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        case .sunday: return "So"
        }
    }

    /// EKWeekday mapping for EventKit recurrence rules
    var ekWeekday: EKWeekday {
        switch self {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        }
    }

    /// Calendar weekday integer (Sunday = 1, Monday = 2, ...)
    var weekdayNumber: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    /// Parse from German or English text
    static func from(text: String) -> DayOfWeek? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if clean.contains("montag") || clean.contains("monday") || clean == "mo" || clean == "mon" {
            return .monday
        } else if clean.contains("dienstag") || clean.contains("tuesday") || clean == "di" || clean == "die" || clean == "tue" {
            return .tuesday
        } else if clean.contains("mittwoch") || clean.contains("wednesday") || clean == "mi" || clean == "mit" || clean == "wed" {
            return .wednesday
        } else if clean.contains("donnerstag") || clean.contains("thursday") || clean == "do" || clean == "don" || clean == "thu" {
            return .thursday
        } else if clean.contains("freitag") || clean.contains("friday") || clean == "fr" || clean == "fre" || clean == "fri" {
            return .friday
        } else if clean.contains("samstag") || clean.contains("saturday") || clean == "sa" || clean == "sam" || clean == "sat" {
            return .saturday
        } else if clean.contains("sonntag") || clean.contains("sunday") || clean == "so" || clean == "son" || clean == "sun" {
            return .sunday
        }
        return nil
    }
}

/// Transient model for schedule items parsed from PDF or entered manually.
struct TimetableEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var courseTitle: String
    var dayOfWeek: DayOfWeek
    var startTime: String  // Format: "HH:mm" (e.g. "08:15")
    var endTime: String    // Format: "HH:mm" (e.g. "09:45")
    var room: String
    var instructor: String?
    var courseType: String? // e.g. "Vorlesung", "Übung", "Tutorium", "Seminar"
    var colorHex: String
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        courseTitle: String,
        dayOfWeek: DayOfWeek,
        startTime: String,
        endTime: String,
        room: String,
        instructor: String? = nil,
        courseType: String? = "Vorlesung",
        colorHex: String = "#3B82F6",
        isSelected: Bool = true
    ) {
        self.id = id
        self.courseTitle = courseTitle
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
        self.instructor = instructor
        self.courseType = courseType
        self.colorHex = colorHex
        self.isSelected = isSelected
    }

    /// Parse hour and minute components from "HH:mm"
    var startTimeComponents: DateComponents? {
        parseTime(string: startTime)
    }

    var endTimeComponents: DateComponents? {
        parseTime(string: endTime)
    }

    private func parseTime(string: String) -> DateComponents? {
        let parts = string.replacingOccurrences(of: ".", with: ":").split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let minute = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        var comp = DateComponents()
        comp.hour = hour
        comp.minute = minute
        return comp
    }

    /// Sample dummy entries for previews and initial test runs
    static var sampleEntries: [TimetableEntry] {
        [
            TimetableEntry(
                courseTitle: "Algorithmen & Datenstrukturen",
                dayOfWeek: .monday,
                startTime: "08:15",
                endTime: "09:45",
                room: "Audimax 1",
                instructor: "Prof. Dr. Weber",
                courseType: "Vorlesung",
                colorHex: "#3B82F6"
            ),
            TimetableEntry(
                courseTitle: "Softwaretechnik",
                dayOfWeek: .tuesday,
                startTime: "10:15",
                endTime: "11:45",
                room: "Gebäude 50.34 Rm 101",
                instructor: "Prof. Dr. Schmidt",
                courseType: "Vorlesung",
                colorHex: "#10B981"
            ),
            TimetableEntry(
                courseTitle: "Algorithmen & Datenstrukturen Übung",
                dayOfWeek: .wednesday,
                startTime: "14:00",
                endTime: "15:30",
                room: "Seminarraum 3",
                instructor: "M.Sc. Fischer",
                courseType: "Übung",
                colorHex: "#6366F1"
            ),
            TimetableEntry(
                courseTitle: "Theoretische Informatik",
                dayOfWeek: .thursday,
                startTime: "12:00",
                endTime: "13:30",
                room: "Hörsaal Zoologie",
                instructor: "Prof. Dr. Becker",
                courseType: "Vorlesung",
                colorHex: "#EC4899"
            ),
            TimetableEntry(
                courseTitle: "Softwaretechnik Praktikum",
                dayOfWeek: .friday,
                startTime: "09:00",
                endTime: "12:00",
                room: "Poolraum Informatik 2",
                instructor: "Team SWT",
                courseType: "Praktikum",
                colorHex: "#F59E0B"
            )
        ]
    }
}
