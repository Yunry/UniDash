//
//  ScheduleItem.swift
//  UniDash
//
//  SwiftData persistent model representing a saved class in the user's in-app timetable.
//

import Foundation
import SwiftData

@Model
final class ScheduleItem {
    @Attribute(.unique) var id: UUID
    var courseTitle: String
    var dayOfWeekRaw: String
    var startTime: String  // Format "HH:mm" (e.g. "08:15")
    var endTime: String    // Format "HH:mm" (e.g. "09:45")
    var room: String
    var instructor: String?
    var courseType: String
    var colorHex: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        courseTitle: String,
        dayOfWeek: DayOfWeek,
        startTime: String,
        endTime: String,
        room: String,
        instructor: String? = nil,
        courseType: String = "Vorlesung",
        colorHex: String = "#3B82F6",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.courseTitle = courseTitle
        self.dayOfWeekRaw = dayOfWeek.rawValue
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
        self.instructor = instructor
        self.courseType = courseType
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var dayOfWeek: DayOfWeek {
        get { DayOfWeek(rawValue: dayOfWeekRaw) ?? .monday }
        set { dayOfWeekRaw = newValue.rawValue }
    }

    /// Sort key based on start time (e.g. "08:15" -> 495 minutes)
    var startMinuteOfDay: Int {
        let parts = startTime.replacingOccurrences(of: ".", with: ":").split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return 0 }
        return h * 60 + m
    }

    /// Transient TimetableEntry bridge
    var asTimetableEntry: TimetableEntry {
        TimetableEntry(
            id: id,
            courseTitle: courseTitle,
            dayOfWeek: dayOfWeek,
            startTime: startTime,
            endTime: endTime,
            room: room,
            instructor: instructor,
            courseType: courseType,
            colorHex: colorHex
        )
    }

    // MARK: - Preloaded Sample Semester Schedule (LMU München)

    static var defaultSemesterSchedule: [ScheduleItem] {
        [
            ScheduleItem(
                courseTitle: "Einführung in die Informatik",
                dayOfWeek: .monday,
                startTime: "10:15",
                endTime: "11:45",
                room: "Hörsaal B 201 Geschwister-Scholl-Platz 1",
                instructor: "Prof. Dr. Kranzlmüller",
                courseType: "Vorlesung",
                colorHex: "#3B82F6"
            ),
            ScheduleItem(
                courseTitle: "Lineare Algebra für Informatiker",
                dayOfWeek: .tuesday,
                startTime: "08:15",
                endTime: "09:45",
                room: "Hörsaal A 140 Hauptgebäude",
                instructor: "Prof. Dr. Rosenschon",
                courseType: "Vorlesung",
                colorHex: "#10B981"
            ),
            ScheduleItem(
                courseTitle: "Rechnerarchitektur",
                dayOfWeek: .wednesday,
                startTime: "14:15",
                endTime: "15:45",
                room: "Raum B 052 Theresienstraße 39",
                instructor: "Prof. Dr. Schulz",
                courseType: "Vorlesung",
                colorHex: "#6366F1"
            ),
            ScheduleItem(
                courseTitle: "Algorithmen und Datenstrukturen",
                dayOfWeek: .thursday,
                startTime: "12:15",
                endTime: "13:45",
                room: "Große Aula Geschwister-Scholl-Platz 1",
                instructor: "Prof. Dr. Seidl",
                courseType: "Vorlesung",
                colorHex: "#EC4899"
            ),
            ScheduleItem(
                courseTitle: "Diskrete Strukturen",
                dayOfWeek: .friday,
                startTime: "10:15",
                endTime: "11:45",
                room: "Hörsaal C 123 Hauptgebäude",
                instructor: "Dr. Reineke",
                courseType: "Übung",
                colorHex: "#F59E0B"
            ),
            ScheduleItem(
                courseTitle: "Programmierpraktikum (Java/Swift)",
                dayOfWeek: .friday,
                startTime: "13:00",
                endTime: "15:30",
                room: "CIP-Pool Theresienstr. 39",
                instructor: "Dipl.-Inf. Schmidt",
                courseType: "Praktikum",
                colorHex: "#8B5CF6"
            )
        ]
    }
}
