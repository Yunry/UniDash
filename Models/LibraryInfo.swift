//
//  LibraryInfo.swift
//  UniDash
//
//  Campus library model with official opening hours (incl. Bavarian holiday
//  closures), contact data, and the feed ID used for live occupancy from the
//  UB-Platzfinder (see LibraryOccupancyService).
//
//  Data source: https://www.ub.lmu.de/de/standorte/ (Stand: Oktober 2026)
//

import Foundation
import SwiftUI

public enum LibraryEquipment: String, CaseIterable, Identifiable, Codable, Hashable {
    case printerScanner = "Drucker & Scanner"
    case silentZone = "Stille Zone"
    case groupRooms = "Gruppenräume"
    case powerOutlets = "Steckdosen"
    case cipPool = "CIP-Pools"
    case cafe = "Cafeteria / Snacks"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .printerScanner: return "printer.fill"
        case .silentZone: return "speaker.slash.fill"
        case .groupRooms: return "person.3.fill"
        case .powerOutlets: return "bolt.fill"
        case .cipPool: return "desktopcomputer"
        case .cafe: return "cup.and.saucer.fill"
        }
    }
}

public enum OccupancyLevel: String, Codable {
    case low = "Viele Plätze frei"
    case moderate = "Mäßig belegt"
    case high = "Sehr voll"

    public init(occupiedPercent pct: Int) {
        if pct < 50 { self = .low } else if pct < 82 { self = .moderate } else { self = .high }
    }

    public var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }

    public var icon: String {
        switch self {
        case .low: return "person.fill"
        case .moderate: return "person.2.fill"
        case .high: return "person.3.sequence.fill"
        }
    }
}

// MARK: - Opening Hours

/// Opening window on a single day, in minutes since midnight (close may be 1440 = 24:00).
public struct DailyHours: Codable, Hashable, Sendable {
    public var open: Int
    public var close: Int

    public init(_ openHour: Int, _ openMinute: Int = 0, to closeHour: Int, _ closeMinute: Int = 0) {
        self.open = openHour * 60 + openMinute
        self.close = closeHour * 60 + closeMinute
    }

    public func contains(minuteOfDay m: Int) -> Bool { m >= open && m < close }

    public var formatted: String { "\(Self.fmt(open))–\(Self.fmt(close))" }

    static func fmt(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

/// Weekly schedule. Keys use `Calendar` weekday numbering (1 = Sonntag … 7 = Samstag).
public struct WeeklyHours: Codable, Hashable, Sendable {
    public var days: [Int: DailyHours]

    public init(weekdays: DailyHours?, saturday: DailyHours? = nil, sunday: DailyHours? = nil) {
        var d: [Int: DailyHours] = [:]
        if let weekdays { for wd in 2...6 { d[wd] = weekdays } }
        if let saturday { d[7] = saturday }
        if let sunday { d[1] = sunday }
        self.days = d
    }

    public func hours(onWeekday weekday: Int) -> DailyHours? { days[weekday] }

    /// Compact German description, e.g. "Mo–Fr 08:00–22:00 • Sa–So 10:00–20:00".
    public var description: String {
        var parts: [String] = []
        if let wd = days[2] { parts.append("Mo–Fr \(wd.formatted)") }
        switch (days[7], days[1]) {
        case let (sa?, so?) where sa == so: parts.append("Sa–So \(sa.formatted)")
        case let (sa?, so?): parts.append("Sa \(sa.formatted) • So \(so.formatted)")
        case let (sa?, nil): parts.append("Sa \(sa.formatted)")
        case let (nil, so?): parts.append("So \(so.formatted)")
        case (nil, nil): parts.append("Sa–So geschlossen")
        }
        return parts.joined(separator: " • ")
    }
}

/// Days on which all UB locations are closed (bayerische gesetzliche Feiertage
/// plus 24./31.12., as listed on the UB opening hours page).
public enum UBClosureCalendar {
    public static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return cal
    }()

    public static func isClosedDay(_ date: Date) -> Bool {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = c.year, let month = c.month, let day = c.day else { return false }

        let fixed: [(Int, Int)] = [(1, 1), (1, 6), (5, 1), (8, 15), (10, 3), (11, 1), (12, 24), (12, 25), (12, 26), (12, 31)]
        if fixed.contains(where: { $0.0 == month && $0.1 == day }) { return true }

        // Easter-based: Karfreitag … Ostermontag, Christi Himmelfahrt, Pfingsten (So+Mo), Fronleichnam
        guard let easter = easterSunday(year: year),
              let target = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let offset = calendar.dateComponents([.day], from: easter, to: target).day else { return false }
        return [-2, -1, 0, 1, 39, 49, 50, 60].contains(offset)
    }

    /// Anonymous Gregorian algorithm (Meeus/Jones/Butcher).
    public static func easterSunday(year: Int) -> Date? {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

// MARK: - Campus Library

public struct CampusLibrary: Identifiable, Codable, Hashable {
    /// Stable identifier (also used as key for occupancy lookups).
    public var id: String
    public var name: String
    public var address: String
    public var campusArea: String
    public var hours: WeeklyHours
    /// `user=` parameter of the UB-Platzfinder feed, nil if the location has no live counter.
    public var occupancyFeedID: String?
    /// Seat count published by the UB (used if the live feed is unavailable).
    public var totalSeats: Int?
    public var equipment: [LibraryEquipment]
    public var reservationURL: String?
    public var webURL: String
    public var phone: String?
    public var email: String?

    public init(
        id: String,
        name: String,
        address: String,
        campusArea: String,
        hours: WeeklyHours,
        occupancyFeedID: String? = nil,
        totalSeats: Int? = nil,
        equipment: [LibraryEquipment] = [],
        reservationURL: String? = CampusLibrary.annyURL,
        webURL: String,
        phone: String? = nil,
        email: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.campusArea = campusArea
        self.hours = hours
        self.occupancyFeedID = occupancyFeedID
        self.totalSeats = totalSeats
        self.equipment = equipment
        self.reservationURL = reservationURL
        self.webURL = webURL
        self.phone = phone
        self.email = email
    }

    public static let annyURL = "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth"
    public static let openingHoursURL = "https://www.ub.lmu.de/de/standorte/regulaere-oeffnungszeiten.html"
    public static let platzfinderURL = "https://www.ub.lmu.de/de/standorte/platzfinder/"

    // MARK: - Opening Status

    public var isOpenNow: Bool { isOpen() }

    public func isOpen(at date: Date = Date()) -> Bool {
        if UBClosureCalendar.isClosedDay(date) { return false }
        let cal = UBClosureCalendar.calendar
        let c = cal.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = c.weekday, let today = hours.hours(onWeekday: weekday) else { return false }
        return today.contains(minuteOfDay: (c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    /// Short status line, e.g. "Geöffnet bis 22:00", "Öffnet um 10:00", "Heute geschlossen (Feiertag)".
    public func statusText(at date: Date = Date()) -> String {
        let cal = UBClosureCalendar.calendar
        if UBClosureCalendar.isClosedDay(date) { return "Heute geschlossen (Feiertag)" }
        let c = cal.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = c.weekday, let today = hours.hours(onWeekday: weekday) else {
            return "Heute geschlossen"
        }
        let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if today.contains(minuteOfDay: minute) { return "Geöffnet bis \(DailyHours.fmt(today.close))" }
        if minute < today.open { return "Öffnet um \(DailyHours.fmt(today.open))" }
        return "Geschlossen"
    }

    public var openingHoursDescription: String { hours.description }

    // MARK: - Default LMU Libraries (verified against ub.lmu.de, Oktober 2026)

    private static let mainBuildingPage = "https://www.ub.lmu.de/de/standorte/standorte-am-lmu-hauptgebaeude/"
    private static let innerCityPage = "https://www.ub.lmu.de/de/standorte/weitere-innenstadtstandorte/"
    private static let martinsriedPage = "https://www.ub.lmu.de/de/standorte/standorte-grosshadern-martinsried/"

    public static let defaultLibraries: [CampusLibrary] = [
        CampusLibrary(
            id: "phil",
            name: "Fachbibliothek Philologicum",
            address: "Ludwigstraße 25, 80539 München",
            campusArea: "Hauptcampus • U3/U6 Universität",
            hours: WeeklyHours(weekdays: DailyHours(8, to: 22), saturday: DailyHours(10, to: 20), sunday: DailyHours(10, to: 20)),
            occupancyFeedID: "phil",
            totalSeats: 600,
            equipment: [.silentZone, .groupRooms],
            webURL: mainBuildingPage,
            phone: "+49 89 2180-1858",
            email: "philologicum@ub.uni-muenchen.de"
        ),
        CampusLibrary(
            id: "histo",
            name: "Fachbibliothek Historicum",
            address: "Schellingstraße 12, 80799 München",
            campusArea: "Gebäudeteil K • Erdgeschoss (K048)",
            hours: WeeklyHours(weekdays: DailyHours(8, to: 22), saturday: DailyHours(10, to: 20), sunday: DailyHours(10, to: 20)),
            occupancyFeedID: "histo",
            totalSeats: 348,
            equipment: [.silentZone],
            webURL: mainBuildingPage,
            phone: "+49 89 2180-5586",
            email: "historicum@ub.uni-muenchen.de"
        ),
        CampusLibrary(
            id: "jura1",
            name: "Fachbibliothek Rechtswissenschaft (Bürgerliches & Öffentliches Recht)",
            address: "Professor-Huber-Platz 2, 80539 München",
            campusArea: "Hauptcampus • Prof.-Huber-Platz",
            hours: WeeklyHours(weekdays: DailyHours(8, to: 22), saturday: DailyHours(9, to: 20), sunday: DailyHours(9, to: 20)),
            occupancyFeedID: "jura1",
            totalSeats: 470,
            equipment: [.silentZone],
            webURL: mainBuildingPage,
            phone: "+49 89 2180-2743",
            email: "rechtswissenschaft@ub.uni-muenchen.de"
        ),
        CampusLibrary(
            id: "jura2",
            name: "Fachbibliothek Rechtswissenschaft (Strafrecht)",
            address: "Professor-Huber-Platz 2, 80539 München",
            campusArea: "Hauptcampus • Prof.-Huber-Platz",
            hours: WeeklyHours(weekdays: DailyHours(8, to: 20), saturday: DailyHours(10, to: 20), sunday: DailyHours(10, to: 20)),
            occupancyFeedID: "jura2",
            totalSeats: 148,
            equipment: [.silentZone],
            webURL: mainBuildingPage,
            phone: "+49 89 2180-17807",
            email: "rechtswissenschaft@ub.uni-muenchen.de"
        ),
        CampusLibrary(
            id: "wiwi",
            name: "Fachbibliothek Wirtschaftswissenschaften & Statistik",
            address: "Ludwigstraße 28, 80539 München",
            campusArea: "Ludwigstraße • Eingang Raum 108",
            hours: WeeklyHours(weekdays: DailyHours(8, to: 22), saturday: DailyHours(10, to: 20), sunday: DailyHours(10, to: 20)),
            occupancyFeedID: "wiwi",
            totalSeats: 230,
            equipment: [.silentZone],
            webURL: mainBuildingPage,
            phone: "+49 89 2180-2601"
        ),
        CampusLibrary(
            id: "theo",
            name: "Fachbibliothek Theologie & Philosophie",
            address: "Geschwister-Scholl-Platz 1, 80539 München",
            campusArea: "Hauptgebäude • Gebäudeteil D, 1. OG (D123)",
            hours: WeeklyHours(weekdays: DailyHours(8, to: 22), saturday: DailyHours(10, to: 20)),
            occupancyFeedID: "theo",
            totalSeats: 166,
            equipment: [.silentZone],
            webURL: mainBuildingPage,
            phone: "+49 89 2180-3486"
        ),
        CampusLibrary(
            id: "lz-gsp",
            name: "Lernzentrum Geschwister-Scholl-Platz",
            address: "Geschwister-Scholl-Platz 1, 80539 München",
            campusArea: "Hauptgebäude • Gebäudeteil F, 2. OG (F208)",
            hours: WeeklyHours(weekdays: DailyHours(6, 30, to: 24), saturday: DailyHours(8, to: 22), sunday: DailyHours(8, to: 20)),
            occupancyFeedID: nil,
            equipment: [.groupRooms],
            reservationURL: nil,
            webURL: mainBuildingPage,
            phone: "+49 89 2180-2427",
            email: "lernzentren@ub.uni-muenchen.de"
        ),
        CampusLibrary(
            id: "zlbs",
            name: "Lernzentrum Leo 13",
            address: "Leopoldstraße 13, Haus 1, 80802 München",
            campusArea: "Schwabing • Erdgeschoss (1001B)",
            hours: WeeklyHours(weekdays: DailyHours(9, to: 20)),
            occupancyFeedID: "zlbs",
            totalSeats: 96,
            equipment: [.groupRooms],
            webURL: innerCityPage,
            phone: "+49 89 2180-9489",
            email: "lernzentrumleo13@ub.uni-muenchen.de"
        ),
        CampusLibrary(
            id: "mathe",
            name: "Fachbibliothek Mathematik & Physik",
            address: "Theresienstraße 37, 80333 München",
            campusArea: "Maxvorstadt • 1. OG (A106)",
            hours: WeeklyHours(weekdays: DailyHours(8, to: 22), saturday: DailyHours(10, to: 20), sunday: DailyHours(10, to: 20)),
            occupancyFeedID: "mathe",
            totalSeats: 189,
            equipment: [.silentZone],
            webURL: innerCityPage,
            email: "bmp@ub.uni-muenchen.de"
        ),
        CampusLibrary(
            id: "bio",
            name: "Fachbibliothek Biologie & Biomedizin",
            address: "Großhaderner Straße 4, 82152 Planegg-Martinsried",
            campusArea: "Campus Martinsried • Erdgeschoss",
            hours: WeeklyHours(weekdays: DailyHours(9, to: 20)),
            occupancyFeedID: "bio",
            totalSeats: 72,
            equipment: [.silentZone],
            webURL: martinsriedPage,
            email: "biomed@ub.uni-muenchen.de"
        )
    ]
}
