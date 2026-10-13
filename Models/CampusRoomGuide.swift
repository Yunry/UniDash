//
//  CampusRoomGuide.swift
//  UniDash
//
//  Room code decoding logic and campus buildings directory integrated with LMU Raumfinder.
//

import Foundation

public struct CampusBuildingGuide: Identifiable, Hashable {
    public var id: String { code }
    public var code: String
    public var name: String
    public var address: String
    public var description: String
    public var floorRule: String
    public var mapsURL: String
    public var lmuRaumfinderCode: String
    public var latitude: Double
    public var longitude: Double

    public var raumfinderURL: String {
        "https://www.lmu.de/raumfinder/#/building/\(lmuRaumfinderCode)/map"
    }

    public static let defaultBuildings: [CampusBuildingGuide] = [
        CampusBuildingGuide(
            code: "A / B / C / D / E / F / M",
            name: "LMU Hauptgebäude (GSP 1)",
            address: "Geschwister-Scholl-Platz 1, 80539 München",
            description: "Große Trakte rund um den Lichthof. Raum-Buchstabe zeigt den Trakt (z.B. A = Südflügel, B = Nordflügel, M = Mittelbau).",
            floorRule: "Erste Ziffer ist das Stockwerk: 0xx = EG, 1xx = 1. OG, 2xx = 2. OG.",
            mapsURL: "https://maps.apple.com/?q=Geschwister-Scholl-Platz+1+Muenchen",
            lmuRaumfinderCode: "bw0000",
            latitude: 48.15067,
            longitude: 11.58054
        ),
        CampusBuildingGuide(
            code: "Theresienstr.",
            name: "MINT-Zentrum (Mathe / Physik)",
            address: "Theresienstraße 37–41, 80333 München",
            description: "Gebäude A bis C. Große Hörsäle B 051, B 052 im EG/UG.",
            floorRule: "Buchstabe A/B/C bezeichnet den Bauteil.",
            mapsURL: "https://maps.apple.com/?q=Theresienstrasse+39+Muenchen",
            lmuRaumfinderCode: "bw1003",
            latitude: 48.14799,
            longitude: 11.57350
        ),
        CampusBuildingGuide(
            code: "Leopoldstr.",
            name: "Campus Leopoldstraße (Schweinchenbau)",
            address: "Leopoldstraße 13, 80802 München",
            description: "Pädagogik, Psychologie und Mensa Leopoldstraße.",
            floorRule: "Haus 1, 2 und 3 mit Raumbezeichnungen wie 1201.",
            mapsURL: "https://maps.apple.com/?q=Leopoldstrasse+13+Muenchen",
            lmuRaumfinderCode: "bw0601",
            latitude: 48.15575,
            longitude: 11.58302
        ),
        CampusBuildingGuide(
            code: "Oettingenstr.",
            name: "Institut für Informatik",
            address: "Oettingenstraße 67, 80538 München",
            description: "Informatik, Medieninformatik und Bioinformatik Hörsäle B 001, L 155.",
            floorRule: "Buchstabe + Raumnummer (B = Bauteil B, L = Labor).",
            mapsURL: "https://maps.apple.com/?q=Oettingenstrasse+67+Muenchen",
            lmuRaumfinderCode: "bw7070",
            latitude: 48.15043,
            longitude: 11.59508
        ),
        CampusBuildingGuide(
            code: "Prof.-Huber-Pl.",
            name: "Juridicum / Rechtswissenschaften",
            address: "Professor-Huber-Platz 2, 80539 München",
            description: "Hörsäle W 101, W 201 und juristische Fachbibliothek.",
            floorRule: "Direkt gegenüber dem Hauptgebäude über die Ludwigstraße.",
            mapsURL: "https://maps.apple.com/?q=Professor-Huber-Platz+2+Muenchen",
            lmuRaumfinderCode: "bw0420",
            latitude: 48.15083,
            longitude: 11.58205
        ),
        CampusBuildingGuide(
            code: "Ludwigstr. 28",
            name: "Wirtschaftswissenschaften (WiWi)",
            address: "Ludwigstraße 28, 80539 München",
            description: "Fakultät für Betriebswirtschaft und Volkswirtschaftslehre.",
            floorRule: "Vorder- und Rückgebäude mit Fachbibliothek.",
            mapsURL: "https://maps.apple.com/?q=Ludwigstrasse+28+Muenchen",
            lmuRaumfinderCode: "bw0407",
            latitude: 48.15165,
            longitude: 11.58237
        ),
        CampusBuildingGuide(
            code: "Martinsried",
            name: "HighTechCampus Biozentrum",
            address: "Großhaderner Str. 2, 82152 Planegg-Martinsried",
            description: "Biologie, Biomedizin und molekulare Forschung.",
            floorRule: "Großflächiger Forschungscampus mit Haus A bis G.",
            mapsURL: "https://maps.apple.com/?q=Grosshaderner+Strasse+2+Planegg",
            lmuRaumfinderCode: "bw2970",
            latitude: 48.10915,
            longitude: 11.45844
        )
    ]

    public static func decode(roomCode: String) -> (building: String, floor: String, tip: String, raumfinderURL: String)? {
        let clean = roomCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return nil }

        if clean.contains("THERESIEN") || clean.contains("TH39") || clean.contains("TH41") {
            return (
                "Theresienstraße 37–41 (MINT-Campus)",
                "Bauteil A/B/C & Hörsäle",
                "U-Bahn U2 Theresienstraße",
                "https://www.lmu.de/raumfinder/#/building/bw1003/map"
            )
        } else if clean.contains("LEOPOLD") || clean.contains("LEO13") {
            return (
                "Leopoldstraße 13 (Schweinchenbau)",
                "Haus 1–3",
                "U-Bahn U3/U6 Giselastraße",
                "https://www.lmu.de/raumfinder/#/building/bw0601/map"
            )
        } else if clean.contains("OETTINGEN") || clean.contains("OETT") {
            return (
                "Oettingenstraße 67 (Informatik)",
                "Hörsäle EG/1. OG",
                "Tram 16 Nationalmuseum/Haus der Kunst",
                "https://www.lmu.de/raumfinder/#/building/bw7070/map"
            )
        } else if clean.contains("JURIDICUM") || clean.contains("PROF") || clean.contains("HUBER") {
            return (
                "Professor-Huber-Platz 2 (Juridicum)",
                "Trakt W",
                "U-Bahn U3/U6 Universität",
                "https://www.lmu.de/raumfinder/#/building/bw0420/map"
            )
        } else if clean.hasPrefix("A") || clean.hasPrefix("B") || clean.hasPrefix("C") || clean.hasPrefix("D") || clean.hasPrefix("E") || clean.hasPrefix("F") || clean.hasPrefix("M") {
            let firstLetter = String(clean.prefix(1))
            let numberPart = clean.dropFirst().trimmingCharacters(in: .whitespaces)
            let floorDesc: String
            if let firstDigit = numberPart.first {
                switch firstDigit {
                case "0": floorDesc = "Erdgeschoss (EG)"
                case "1": floorDesc = "1. Obergeschoss (1. OG)"
                case "2": floorDesc = "2. Obergeschoss (2. OG)"
                case "U": floorDesc = "Untergeschoss (UG)"
                default: floorDesc = "Stockwerk laut Raumnummer"
                }
            } else {
                floorDesc = "Hauptgebäude"
            }
            return (
                "LMU Hauptgebäude (Geschwister-Scholl-Platz 1) • Trakt \(firstLetter)",
                floorDesc,
                "U-Bahn U3/U6 Universität (direkter Ausgang zum Lichthof)",
                "https://www.lmu.de/raumfinder/#/building/bw0000/map"
            )
        }

        return nil
    }
}
