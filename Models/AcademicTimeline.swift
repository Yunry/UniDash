//
//  AcademicTimeline.swift
//  UniDash
//
//  Academic calendar deadlines, semester schedules, and EventKit deadline reminders.
//

import Foundation
import EventKit
import SwiftUI

public enum DeadlineCategory: String, CaseIterable, Codable, Hashable {
    case reRegistration = "Rückmeldung"
    case examRegistration = "Prüfungsanmeldung"
    case lecturePeriod = "Vorlesungszeit"
    case examPeriod = "Klausurenphase"
    case semesterBreak = "Semesterferien"
    case general = "Allgemein"

    public var icon: String {
        switch self {
        case .reRegistration: return "creditcard.and.123"
        case .examRegistration: return "pencil.and.list.clipboard"
        case .lecturePeriod: return "graduationcap.fill"
        case .examPeriod: return "doc.text.fill"
        case .semesterBreak: return "sun.max.fill"
        case .general: return "calendar"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .reRegistration: return .red
        case .examRegistration: return .orange
        case .lecturePeriod: return .blue
        case .examPeriod: return .purple
        case .semesterBreak: return .green
        case .general: return .gray
        }
    }
}

public struct AcademicDeadline: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var title: String
    public var subtitle: String
    public var category: DeadlineCategory
    public var startDate: Date
    public var endDate: Date
    public var isCritical: Bool
    public var url: String?

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        category: DeadlineCategory,
        startDate: Date,
        endDate: Date,
        isCritical: Bool = false,
        url: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.isCritical = isCritical
        self.url = url
    }

    /// Days remaining until the end date
    public var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfEnd = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfEnd)
        return components.day ?? 0
    }

    /// Whether this deadline is currently ongoing
    public var isOngoing: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    /// Whether this deadline is in the future
    public var isUpcoming: Bool {
        Date() < startDate
    }

    /// Whether this deadline has already passed
    public var isPast: Bool {
        Date() > endDate
    }

    public var statusBadgeText: String {
        if isPast {
            return "Beendet"
        } else if isOngoing {
            let left = daysRemaining
            if left == 0 {
                return "Endet heute!"
            } else if left == 1 {
                return "Noch 1 Tag!"
            } else {
                return "Noch \(left) Tage"
            }
        } else {
            let daysUntilStart = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: startDate)).day ?? 0
            return "In \(daysUntilStart) Tagen"
        }
    }
}

public struct AcademicSemester: Identifiable, Hashable {
    public var id: String { name }
    public var name: String
    public var term: String // e.g. "Wintersemester 2024/25"
    public var deadlines: [AcademicDeadline]

    public static let sampleSemesters: [AcademicSemester] = {
        let cal = Calendar.current

        func makeDate(year: Int, month: Int, day: Int) -> Date {
            var comp = DateComponents()
            comp.year = year
            comp.month = month
            comp.day = day
            comp.timeZone = TimeZone(identifier: "Europe/Berlin")
            return cal.date(from: comp) ?? Date()
        }

        // Current & Upcoming Academic Schedule (LMU / TUM / Bavarian Universities)
        let ws2627Deadlines: [AcademicDeadline] = [
            AcademicDeadline(
                title: "Vorlesungszeit Wintersemester",
                subtitle: "Beginn der regulären Lehrveranstaltungen & Vorlesungen",
                category: .lecturePeriod,
                startDate: makeDate(year: 2026, month: 10, day: 12),
                endDate: makeDate(year: 2027, month: 2, day: 5),
                isCritical: false
            ),
            AcademicDeadline(
                title: "Prüfungsanmeldephase (LSF)",
                subtitle: "Verbindliche Prüfungsanmeldung für Klausuren & Hausarbeiten",
                category: .examRegistration,
                startDate: makeDate(year: 2026, month: 12, day: 7),
                endDate: makeDate(year: 2027, month: 1, day: 15),
                isCritical: true,
                url: "https://lsf.verwaltung.uni-muenchen.de"
            ),
            AcademicDeadline(
                title: "Rückmeldefrist & Semesterbeitrag",
                subtitle: "85,00 € Grundbeitrag für das Sommersemester 2027 überweisen",
                category: .reRegistration,
                startDate: makeDate(year: 2027, month: 1, day: 15),
                endDate: makeDate(year: 2027, month: 2, day: 15),
                isCritical: true,
                url: "https://www.lmu.de/de/studium/rund-ums-studium/studienorganisation/rueckmeldung/index.html"
            ),
            AcademicDeadline(
                title: "Hauptklausurenphase",
                subtitle: "Zentrale schriftliche und mündliche Semesterprüfungen",
                category: .examPeriod,
                startDate: makeDate(year: 2027, month: 2, day: 8),
                endDate: makeDate(year: 2027, month: 3, day: 5),
                isCritical: false
            ),
            AcademicDeadline(
                title: "Vorlesungsfreie Zeit (Semesterferien)",
                subtitle: "Praktika, Seminararbeiten und Vorbereitung auf das Sommersemester",
                category: .semesterBreak,
                startDate: makeDate(year: 2027, month: 2, day: 6),
                endDate: makeDate(year: 2027, month: 4, day: 16),
                isCritical: false
            )
        ]

        let ss27Deadlines: [AcademicDeadline] = [
            AcademicDeadline(
                title: "Vorlesungszeit Sommersemester",
                subtitle: "Beginn der Vorlesungen des Sommersemesters 2027",
                category: .lecturePeriod,
                startDate: makeDate(year: 2027, month: 4, day: 19),
                endDate: makeDate(year: 2027, month: 7, day: 23),
                isCritical: false
            ),
            AcademicDeadline(
                title: "Rückmeldung zum Wintersemester 27/28",
                subtitle: "Fristgerechte Überweisung des Semesterbeitrags",
                category: .reRegistration,
                startDate: makeDate(year: 2027, month: 6, day: 15),
                endDate: makeDate(year: 2027, month: 7, day: 15),
                isCritical: true,
                url: "https://www.lmu.de/rueckmeldung"
            ),
            AcademicDeadline(
                title: "Vorlesungsfreie Zeit (Sommerpause)",
                subtitle: "Große Semesterferien im Sommer",
                category: .semesterBreak,
                startDate: makeDate(year: 2027, month: 7, day: 24),
                endDate: makeDate(year: 2027, month: 10, day: 8),
                isCritical: false
            )
        ]

        return [
            AcademicSemester(name: "WS 26/27", term: "Wintersemester 2026/27", deadlines: ws2627Deadlines),
            AcademicSemester(name: "SoSe 27", term: "Sommersemester 2027", deadlines: ss27Deadlines)
        ]
    }()
}
