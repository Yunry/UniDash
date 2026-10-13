//
//  LibraryInfo.swift
//  UniDash
//
//  Rich campus library model with live occupancy indicators, opening hours,
//  equipment tags, and Anny reservation integration.
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

public struct CampusLibrary: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var codeName: String
    public var address: String
    public var campusArea: String
    public var totalSeats: Int
    public var baseOccupancy: Int // 0..100
    public var openWeekdayHour: Int
    public var closeWeekdayHour: Int
    public var openWeekendHour: Int?
    public var closeWeekendHour: Int?
    public var equipment: [LibraryEquipment]
    public var reservationURL: String
    public var webURL: String
    public var phone: String?

    public init(
        id: UUID = UUID(),
        name: String,
        codeName: String,
        address: String,
        campusArea: String,
        totalSeats: Int,
        baseOccupancy: Int,
        openWeekdayHour: Int = 8,
        closeWeekdayHour: Int = 22,
        openWeekendHour: Int? = 9,
        closeWeekendHour: Int? = 20,
        equipment: [LibraryEquipment] = [.silentZone, .powerOutlets, .printerScanner],
        reservationURL: String = "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
        webURL: String = "https://www.ub.uni-muenchen.de",
        phone: String? = "+49 89 2180-2427"
    ) {
        self.id = id
        self.name = name
        self.codeName = codeName
        self.address = address
        self.campusArea = campusArea
        self.totalSeats = totalSeats
        self.baseOccupancy = baseOccupancy
        self.openWeekdayHour = openWeekdayHour
        self.closeWeekdayHour = closeWeekdayHour
        self.openWeekendHour = openWeekendHour
        self.closeWeekendHour = closeWeekendHour
        self.equipment = equipment
        self.reservationURL = reservationURL
        self.webURL = webURL
        self.phone = phone
    }

    // MARK: - Dynamic Live Occupancy Simulation

    /// Realistic simulated occupancy based on time of day and base value
    public var liveOccupancyPercentage: Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let weekday = calendar.component(.weekday, from: Date()) // 1 = Sun, 7 = Sat

        // If outside opening hours, occupancy is 0%
        if !isOpenNow {
            return 0
        }

        // Midday peak between 11:00 and 17:00
        let timeFactor: Double = {
            switch hour {
            case 8...10: return 0.65
            case 11...14: return 1.15
            case 15...17: return 1.25
            case 18...20: return 0.90
            case 21...23: return 0.40
            default: return 0.20
            }
        }()

        let dayFactor: Double = (weekday == 1 || weekday == 7) ? 0.8 : 1.0
        let calculated = Double(baseOccupancy) * timeFactor * dayFactor
        return min(98, max(8, Int(calculated)))
    }

    public var freeSeatsCount: Int {
        let taken = Int(Double(totalSeats) * (Double(liveOccupancyPercentage) / 100.0))
        return max(0, totalSeats - taken)
    }

    public var occupancyLevel: OccupancyLevel {
        let pct = liveOccupancyPercentage
        if pct < 50 { return .low }
        if pct < 82 { return .moderate }
        return .high
    }

    // MARK: - Dynamic Opening Status

    public var isOpenNow: Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now) // 1=Sun, 7=Sat

        let isWeekend = (weekday == 1 || weekday == 7)
        if isWeekend {
            guard let open = openWeekendHour, let close = closeWeekendHour else {
                return false
            }
            return hour >= open && hour < close
        } else {
            return hour >= openWeekdayHour && hour < closeWeekdayHour
        }
    }

    public var openingHoursDescription: String {
        let weekdayStr = String(format: "Mo–Fr %02d:00–%02d:00", openWeekdayHour, closeWeekdayHour)
        if let oW = openWeekendHour, let cW = closeWeekendHour {
            return "\(weekdayStr) • Sa–So \(String(format: "%02d:00–%02d:00", oW, cW))"
        } else {
            return "\(weekdayStr) • Sa–So geschlossen"
        }
    }

    // MARK: - Default LMU & Munich Campus Libraries

    public static let defaultLibraries: [CampusLibrary] = [
        CampusLibrary(
            name: "Philologicum (Sprachen & Literaturen)",
            codeName: "UB Philologicum",
            address: "Ludwigstraße 25, 80539 München",
            campusArea: "Hauptcampus • U3/U6 Universität",
            totalSeats: 740,
            baseOccupancy: 76,
            openWeekdayHour: 8,
            closeWeekdayHour: 22,
            openWeekendHour: 9,
            closeWeekendHour: 20,
            equipment: [.silentZone, .groupRooms, .powerOutlets, .printerScanner, .cipPool, .cafe],
            reservationURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            webURL: "https://www.ub.uni-muenchen.de/standorte/fachbibliotheken/philologicum/index.html"
        ),
        CampusLibrary(
            name: "Universitätsbibliothek Hauptgebäude (UB)",
            codeName: "Zentralbibliothek",
            address: "Geschwister-Scholl-Platz 1, 80539 München",
            campusArea: "Hauptgebäude • EG & 1. OG",
            totalSeats: 580,
            baseOccupancy: 82,
            openWeekdayHour: 8,
            closeWeekdayHour: 24,
            openWeekendHour: 9,
            closeWeekendHour: 22,
            equipment: [.silentZone, .powerOutlets, .printerScanner, .cipPool],
            reservationURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            webURL: "https://www.ub.uni-muenchen.de"
        ),
        CampusLibrary(
            name: "Historicum (Geschichtswissenschaften)",
            codeName: "UB Historicum",
            address: "Geschwister-Scholl-Platz 1, 80539 München",
            campusArea: "Hauptgebäude • Schellingstraße Trakt",
            totalSeats: 320,
            baseOccupancy: 58,
            openWeekdayHour: 8,
            closeWeekdayHour: 22,
            openWeekendHour: 9,
            closeWeekendHour: 18,
            equipment: [.silentZone, .powerOutlets, .printerScanner],
            reservationURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            webURL: "https://www.ub.uni-muenchen.de/standorte/fachbibliotheken/historicum/index.html"
        ),
        CampusLibrary(
            name: "Fachbibliothek Wirtschaftswissenschaften & Statistik",
            codeName: "UB WiWi & Statistik",
            address: "Ludwigstraße 28, 80539 München",
            campusArea: "Leopoldstraße / Ludwigstr. • 2. OG",
            totalSeats: 450,
            baseOccupancy: 70,
            openWeekdayHour: 8,
            closeWeekdayHour: 22,
            openWeekendHour: 9,
            closeWeekendHour: 20,
            equipment: [.silentZone, .groupRooms, .powerOutlets, .printerScanner, .cipPool],
            reservationURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            webURL: "https://www.ub.uni-muenchen.de/standorte/fachbibliotheken/wirtschaft-statistik/index.html"
        ),
        CampusLibrary(
            name: "Fachbibliothek Rechtswissenschaft (Juridicum)",
            codeName: "UB Juridicum",
            address: "Professor-Huber-Platz 2, 80539 München",
            campusArea: "Hauptcampus • Trakt Prof.-Huber-Platz",
            totalSeats: 490,
            baseOccupancy: 88,
            openWeekdayHour: 8,
            closeWeekdayHour: 23,
            openWeekendHour: 9,
            closeWeekendHour: 20,
            equipment: [.silentZone, .powerOutlets, .printerScanner],
            reservationURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            webURL: "https://www.ub.uni-muenchen.de/standorte/fachbibliotheken/jura/index.html"
        ),
        CampusLibrary(
            name: "Fachbibliothek Mathematik & Physik",
            codeName: "UB MathPhys",
            address: "Theresienstraße 39, 80333 München",
            campusArea: "Maxvorstadt • MINT Trakt",
            totalSeats: 260,
            baseOccupancy: 45,
            openWeekdayHour: 8,
            closeWeekdayHour: 21,
            openWeekendHour: 10,
            closeWeekendHour: 18,
            equipment: [.silentZone, .groupRooms, .powerOutlets, .printerScanner, .cipPool],
            reservationURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            webURL: "https://www.ub.uni-muenchen.de/standorte/fachbibliotheken/mathe-physik/index.html"
        ),
        CampusLibrary(
            name: "Fachbibliothek Biologie & Biomedizin",
            codeName: "UB Martinsried",
            address: "Großhaderner Straße 2, 82152 Planegg-Martinsried",
            campusArea: "HighTechCampus Martinsried • Biozentrum",
            totalSeats: 210,
            baseOccupancy: 38,
            openWeekdayHour: 8,
            closeWeekdayHour: 20,
            openWeekendHour: nil,
            closeWeekendHour: nil,
            equipment: [.silentZone, .groupRooms, .powerOutlets, .printerScanner],
            reservationURL: "https://auth.anny.eu/start-session?entityId=https://lmuidp.lrz.de/idp/shibboleth",
            webURL: "https://www.ub.uni-muenchen.de/standorte/fachbibliotheken/biologie/index.html"
        )
    ]
}
