//
//  AppDestination.swift
//  UniDash
//
//  Unified routing enum defining the core application modules and platform icons.
//

import SwiftUI

/// Core top-level navigation destinations across iOS and macOS.
enum AppDestination: String, CaseIterable, Identifiable, Hashable {
    case timetable
    case grades
    case mensa
    case rooms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timetable: return "Stundenplan"
        case .grades: return "Noten & ECTS"
        case .mensa: return "Mensa"
        case .rooms: return "Campus & Räume"
        }
    }

    var icon: String {
        switch self {
        case .timetable: return "calendar.badge.plus"
        case .grades: return "graduationcap.fill"
        case .mensa: return "fork.knife"
        case .rooms: return "building.columns.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .timetable: return "PDF importieren & Kalender-Sync"
        case .grades: return "ECTS-Fortschritt & Notenspiegel"
        case .mensa: return "Tagesangebote & Speiseplan"
        case .rooms: return "Bibliotheken, Fristen, Portale & Buchung"
        }
    }

    var keyboardShortcutKey: KeyEquivalent {
        switch self {
        case .timetable: return "1"
        case .grades: return "2"
        case .mensa: return "3"
        case .rooms: return "4"
        }
    }
}
