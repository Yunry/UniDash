//
//  CampusLink.swift
//  UniDash
//
//  Campus portal quick-links model with categories, icons, and SSO integration.
//

import Foundation
import SwiftUI

public enum CampusLinkCategory: String, CaseIterable, Codable, Hashable {
    case all = "Alle"
    case study = "Studium & Lehre"
    case library = "Bibliothek"
    case it = "IT & Mail"
    case studentLife = "Campus-Leben"

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .study: return "graduationcap.fill"
        case .library: return "books.vertical.fill"
        case .it: return "network"
        case .studentLife: return "sparkles"
        }
    }
}

public struct CampusLink: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var title: String
    public var subtitle: String
    public var url: String
    public var category: CampusLinkCategory
    public var iconName: String
    public var colorHex: String
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        url: String,
        category: CampusLinkCategory,
        iconName: String,
        colorHex: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.url = url
        self.category = category
        self.iconName = iconName
        self.colorHex = colorHex
        self.isPinned = isPinned
    }

    public static let defaultLinks: [CampusLink] = [
        CampusLink(
            title: "Moodle / Lernplattform",
            subtitle: "Kursmaterialien, Vorlesungsfolien & Übungsabgaben",
            url: "https://moodle.lmu.de",
            category: .study,
            iconName: "graduationcap.fill",
            colorHex: "#EA580C",
            isPinned: true
        ),
        CampusLink(
            title: "LSF / CampusOnline",
            subtitle: "Vorlesungsverzeichnis, Prüfungsanmeldung & Notenspiegel",
            url: "https://lsf.verwaltung.uni-muenchen.de",
            category: .study,
            iconName: "doc.plaintext.fill",
            colorHex: "#2563EB",
            isPinned: true
        ),
        CampusLink(
            title: "LRZ Webmail",
            subtitle: "Studentische E-Mail-Adresse (@campus.lmu.de)",
            url: "https://webmail.campus.lmu.de",
            category: .it,
            iconName: "envelope.badge.fill",
            colorHex: "#0D9488",
            isPinned: true
        ),
        CampusLink(
            title: "UB Katalog (OPAC)",
            subtitle: "Bücher suchen, Ausleihen verlängern & Fernleihe",
            url: "https://opac.ub.uni-muenchen.de",
            category: .library,
            iconName: "book.closed.fill",
            colorHex: "#7C3AED",
            isPinned: true
        ),
        CampusLink(
            title: "Eduroam & LRZ VPN",
            subtitle: "Campus-WLAN Konfiguration & sicherer VPN-Zugang",
            url: "https://www.lrz.de/services/netz/mobil/eduroam/",
            category: .it,
            iconName: "wifi",
            colorHex: "#0284C7"
        ),
        CampusLink(
            title: "ZHS Hochschulsport München",
            subtitle: "Sportprogramm, Hallensport & Kursbuchungen",
            url: "https://www.zhs-muenchen.de",
            category: .studentLife,
            iconName: "figure.run",
            colorHex: "#16A34A"
        ),
        CampusLink(
            title: "U-Kino München",
            subtitle: "Studentisches Campus-Kino im Hörsaal für 2–3 €",
            url: "https://u-kino.de",
            category: .studentLife,
            iconName: "film.fill",
            colorHex: "#E11D48"
        ),
        CampusLink(
            title: "Studierendenwerk München",
            subtitle: "BAföG, Mensa-Preise, Wohnheime & Beratung",
            url: "https://www.studierendenwerk-muenchen-oberbayern.de",
            category: .studentLife,
            iconName: "building.columns.fill",
            colorHex: "#D97706"
        )
    ]
}
