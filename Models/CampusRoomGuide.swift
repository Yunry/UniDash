//
//  CampusRoomGuide.swift
//  UniDash
//
//  Room code decoding logic and campus buildings directory integrated with LMU Raumfinder.
//

import Foundation

public struct DecodedRoom: Identifiable, Hashable {
    public var id: String { roomCode }
    public var roomCode: String
    public var building: String
    public var buildingName: String
    public var address: String
    public var floor: String
    public var tip: String
    public var lmuRaumfinderCode: String
    public var lmuRoomKey: String?
    public var raumfinderURL: String
    public var mapsURL: String

    public init(
        roomCode: String,
        building: String,
        buildingName: String,
        address: String,
        floor: String,
        tip: String,
        lmuRaumfinderCode: String,
        lmuRoomKey: String? = nil,
        raumfinderURL: String? = nil,
        mapsURL: String
    ) {
        self.roomCode = roomCode
        self.building = building
        self.buildingName = buildingName
        self.address = address
        self.floor = floor
        self.tip = tip
        self.lmuRaumfinderCode = lmuRaumfinderCode
        self.lmuRoomKey = lmuRoomKey
        if let customURL = raumfinderURL {
            self.raumfinderURL = customURL
        } else if let key = lmuRoomKey, !key.isEmpty {
            self.raumfinderURL = "https://www.lmu.de/raumfinder/#/building/\(lmuRaumfinderCode)/map?room=\(key)"
        } else {
            self.raumfinderURL = "https://www.lmu.de/raumfinder/#/building/\(lmuRaumfinderCode)/map"
        }
        self.mapsURL = mapsURL
    }
}

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
            code: "A / B / C / D / E / F / M / N",
            name: "LMU Hauptgebäude (GSP 1)",
            address: "Geschwister-Scholl-Platz 1, 80539 München",
            description: "Große Trakte rund um den Lichthof. Raum-Buchstabe zeigt den Trakt (z.B. A = Südflügel, B = Nordflügel, M = Mittelbau, N = Nordtrakt).",
            floorRule: "Erste Ziffer ist das Stockwerk: 0xx = EG, 1xx = 1. OG, 2xx = 2. OG.",
            mapsURL: "https://maps.apple.com/?q=Geschwister-Scholl-Platz+1+Muenchen",
            lmuRaumfinderCode: "bw0000",
            latitude: 48.15067,
            longitude: 11.58054
        ),
        CampusBuildingGuide(
            code: "S (Schellingstr. 3)",
            name: "Hörsaalgebäude Schellingstraße 3",
            address: "Schellingstraße 3, 80799 München",
            description: "Zentrales LMU-Hörsaalgebäude direkt hinter dem Hauptgebäude mit den großen Hörsälen S 001, S 002, S 004 und Seminarräumen.",
            floorRule: "S 001/002 = Erdgeschoss (EG), S 101 = 1. OG, S 201 = 2. OG.",
            mapsURL: "https://maps.apple.com/?q=Schellingstrasse+3+Muenchen",
            lmuRaumfinderCode: "bw0200",
            latitude: 48.14930,
            longitude: 11.57909
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
            code: "Ludwigstr. 33",
            name: "Institutsgebäude Ludwigstraße 33",
            address: "Ludwigstraße 33, 80539 München",
            description: "Seminarräume (z.B. Raum 144), Fachschaftsräume und Institute.",
            floorRule: "Raumnummern 1xx = 1. OG, 2xx = 2. OG.",
            mapsURL: "https://maps.apple.com/?q=Ludwigstrasse+33+Muenchen",
            lmuRaumfinderCode: "bw0120",
            latitude: 48.15209,
            longitude: 11.58163
        ),
        CampusBuildingGuide(
            code: "Kaulbachstr. 37",
            name: "Seminargebäude Kaulbachstraße 37",
            address: "Kaulbachstraße 37, 80539 München",
            description: "Seminarräume (z.B. Raum 023) und Institute nahe dem Englischen Garten.",
            floorRule: "Raumnummern 0xx = EG, 1xx = 1. OG.",
            mapsURL: "https://maps.apple.com/?q=Kaulbachstrasse+37+Muenchen",
            lmuRaumfinderCode: "bw0310",
            latitude: 48.14947,
            longitude: 11.58355
        ),
        CampusBuildingGuide(
            code: "Luisenstr. 37",
            name: "Campus Luisenstraße (Geowissenschaften)",
            address: "Luisenstraße 37, 80333 München",
            description: "Fakultät für Geowissenschaften, Hörsäle B 005, C 006 und Fachbibliothek.",
            floorRule: "Gebäudeteile A/B/C mit Stockwerk nach 1. Ziffer.",
            mapsURL: "https://maps.apple.com/?q=Luisenstrasse+37+Muenchen",
            lmuRaumfinderCode: "bw1120",
            latitude: 48.14734,
            longitude: 11.56480
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

    // MARK: - Intelligent Room Code Decoder

    public static func decode(roomCode: String) -> DecodedRoom? {
        let raw = roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let clean = raw.uppercased()

        // 1. Schellingstraße 3 (e.g. S002, S 002, S 001, S 004, S 101, S 201, Schellingstr. 3)
        if isSchellingstraßenRoom(clean) {
            let digits = clean.filter { $0.isNumber }
            let roomLabel = digits.isEmpty ? "Hörsäle" : "Hörsaal S \(digits)"
            let floorDesc: String
            if let first = digits.first {
                switch first {
                case "0": floorDesc = "Erdgeschoss (EG) • \(roomLabel)"
                case "1": floorDesc = "1. Obergeschoss (1. OG) • \(roomLabel)"
                case "2": floorDesc = "2. Obergeschoss (2. OG) • \(roomLabel)"
                default: floorDesc = "Stockwerk laut Raumnummer • \(roomLabel)"
                }
            } else {
                floorDesc = "Erdgeschoss / Obergeschosse"
            }

            // Exact LMU Raumfinder room keys for Schellingstr. 3 (bw0200)
            let roomKey: String?
            if digits.hasSuffix("002") || digits.hasSuffix("02") {
                roomKey = "020300002_" // S 002
            } else if digits.hasSuffix("001") || digits.hasSuffix("01") {
                roomKey = "020300001_" // S 001
            } else if digits.hasSuffix("004") || digits.hasSuffix("04") {
                roomKey = "020300004_" // S 004
            } else if digits.hasSuffix("101") {
                roomKey = "020301001_" // S 101
            } else if digits.hasSuffix("201") {
                roomKey = "020302001_" // S 201
            } else {
                roomKey = nil
            }

            return DecodedRoom(
                roomCode: raw,
                building: "Hörsaalgebäude Schellingstraße 3",
                buildingName: "Schellingstraße 3",
                address: "Schellingstraße 3, 80799 München",
                floor: floorDesc,
                tip: "U-Bahn U3/U6 Universität (Ausgang Schellingstraße, ca. 2–3 Min. Fußweg)",
                lmuRaumfinderCode: "bw0200",
                lmuRoomKey: roomKey,
                mapsURL: "https://maps.apple.com/?q=Schellingstrasse+3+Muenchen"
            )
        }

        // 2. Theresienstraße 37–41 (MINT-Campus Mathe/Physik)
        // Includes famous lecture halls B 051, B 052, A 027
        if clean.contains("THERESIEN") || clean.contains("TH39") || clean.contains("TH41") ||
           clean.contains("B 051") || clean.contains("B051") ||
           clean.contains("B 052") || clean.contains("B052") {
            let floorDesc: String
            let roomKey: String?
            if clean.contains("052") {
                floorDesc = "Erdgeschoss / Untergeschoss • Großer Hörsaal B 052"
                roomKey = "100200052_"
            } else if clean.contains("051") {
                floorDesc = "Erdgeschoss / Untergeschoss • Großer Hörsaal B 051"
                roomKey = "100200051_"
            } else {
                floorDesc = "Bauteil A/B/C & Hörsäle"
                roomKey = nil
            }
            return DecodedRoom(
                roomCode: raw,
                building: "Theresienstraße 37–41 (MINT-Campus)",
                buildingName: "Theresienstraße 37–41",
                address: "Theresienstraße 39, 80333 München",
                floor: floorDesc,
                tip: "U-Bahn U2 Theresienstraße oder Tram 20/21/22",
                lmuRaumfinderCode: "bw1003",
                lmuRoomKey: roomKey,
                mapsURL: "https://maps.apple.com/?q=Theresienstrasse+39+Muenchen"
            )
        }

        // 3. Leopoldstraße 13 (Campus Leopoldstraße / Schweinchenbau)
        if clean.contains("LEOPOLD") || clean.contains("LEO13") || clean.contains("LEO 13") ||
           isLeopoldRoomNumber(clean) {
            let floorDesc = decodeLeopoldFloor(clean)
            return DecodedRoom(
                roomCode: raw,
                building: "Leopoldstraße 13 (Schweinchenbau)",
                buildingName: "Campus Leopoldstraße",
                address: "Leopoldstraße 13, 80802 München",
                floor: floorDesc,
                tip: "U-Bahn U3/U6 Giselastraße (ca. 1 Min. Fußweg)",
                lmuRaumfinderCode: "bw0601",
                lmuRoomKey: nil,
                mapsURL: "https://maps.apple.com/?q=Leopoldstrasse+13+Muenchen"
            )
        }

        // 4. Oettingenstraße 67 (Informatik / Bioinformatik)
        if clean.contains("OETTINGEN") || clean.contains("OETT") ||
           clean.contains("L 155") || clean.contains("L155") ||
           clean.contains("B 001") || clean.contains("B001") {
            return DecodedRoom(
                roomCode: raw,
                building: "Oettingenstraße 67 (Informatik)",
                buildingName: "Oettingenstraße 67",
                address: "Oettingenstraße 67, 80538 München",
                floor: "Hörsaal B 001 (EG) / L 155 (1. OG)",
                tip: "Tram 16 / Bus 100 Nationalmuseum/Haus der Kunst",
                lmuRaumfinderCode: "bw7070",
                lmuRoomKey: nil,
                mapsURL: "https://maps.apple.com/?q=Oettingenstrasse+67+Muenchen"
            )
        }

        // 5. Professor-Huber-Platz 2 (Juridicum / Rechtswissenschaften)
        if clean.contains("JURIDICUM") || clean.contains("HUBER") ||
           isJuridicumRoom(clean) {
            let digits = clean.filter { $0.isNumber }
            let floorDesc: String
            if let first = digits.first {
                switch first {
                case "0": floorDesc = "Trakt W • Erdgeschoss (EG)"
                case "1": floorDesc = "Trakt W • 1. Obergeschoss (1. OG)"
                case "2": floorDesc = "Trakt W • 2. Obergeschoss (2. OG)"
                default: floorDesc = "Trakt W"
                }
            } else {
                floorDesc = "Trakt W"
            }
            let roomKey = (clean.contains("101") || digits == "101") ? "042291101_" : nil
            return DecodedRoom(
                roomCode: raw,
                building: "Professor-Huber-Platz 2 (Juridicum)",
                buildingName: "Juridicum",
                address: "Professor-Huber-Platz 2, 80539 München",
                floor: floorDesc,
                tip: "U-Bahn U3/U6 Universität (Ausgang Professor-Huber-Platz)",
                lmuRaumfinderCode: "bw0420",
                lmuRoomKey: roomKey,
                mapsURL: "https://maps.apple.com/?q=Professor-Huber-Platz+2+Muenchen"
            )
        }

        // 6. Kaulbachstraße 37
        if clean.contains("KAULBACH") || clean.contains("RAUM 023") || clean == "023" || clean == "RAUM 23" {
            return DecodedRoom(
                roomCode: raw,
                building: "Seminargebäude Kaulbachstraße 37",
                buildingName: "Kaulbachstraße 37",
                address: "Kaulbachstraße 37, 80539 München",
                floor: "Erdgeschoss (EG) • Raum 023",
                tip: "U-Bahn U3/U6 Universität (Richtung Englischer Garten)",
                lmuRaumfinderCode: "bw0310",
                lmuRoomKey: "031000023_",
                mapsURL: "https://maps.apple.com/?q=Kaulbachstrasse+37+Muenchen"
            )
        }

        // 7. Ludwigstraße 33
        if clean.contains("LUDWIGSTR. 33") || clean.contains("LUDWIGSTRASSE 33") || clean.contains("RAUM 144") || clean == "144" {
            return DecodedRoom(
                roomCode: raw,
                building: "Institutsgebäude Ludwigstraße 33",
                buildingName: "Ludwigstraße 33",
                address: "Ludwigstraße 33, 80539 München",
                floor: "1. Obergeschoss (1. OG) • Raum 144",
                tip: "U-Bahn U3/U6 Universität",
                lmuRaumfinderCode: "bw0120",
                lmuRoomKey: "012001144_",
                mapsURL: "https://maps.apple.com/?q=Ludwigstrasse+33+Muenchen"
            )
        }

        // 8. Ludwigstraße 28 (WiWi)
        if clean.contains("LUDWIGSTR") || clean.contains("WIWI") {
            return DecodedRoom(
                roomCode: raw,
                building: "Wirtschaftswissenschaften (Ludwigstraße 28)",
                buildingName: "Ludwigstraße 28",
                address: "Ludwigstraße 28, 80539 München",
                floor: "Vorder- und Rückgebäude (WiWi & Statistik)",
                tip: "U-Bahn U3/U6 Universität",
                lmuRaumfinderCode: "bw0407",
                lmuRoomKey: nil,
                mapsURL: "https://maps.apple.com/?q=Ludwigstrasse+28+Muenchen"
            )
        }

        // 9. Luisenstraße 37 (Geowissenschaften)
        if clean.contains("LUISEN") {
            return DecodedRoom(
                roomCode: raw,
                building: "Campus Luisenstraße (Geowissenschaften)",
                buildingName: "Luisenstraße 37",
                address: "Luisenstraße 37, 80333 München",
                floor: "Gebäudeteile A/B/C (z. B. C 006, B 005)",
                tip: "U-Bahn U2 Königsplatz / Theresienstraße",
                lmuRaumfinderCode: "bw1120",
                lmuRoomKey: nil,
                mapsURL: "https://maps.apple.com/?q=Luisenstrasse+37+Muenchen"
            )
        }

        // 10. Martinsried Biozentrum
        if clean.contains("MARTINSRIED") || clean.contains("BIOZENTRUM") || clean.contains("GROSSHADERNER") {
            return DecodedRoom(
                roomCode: raw,
                building: "HighTechCampus Biozentrum (Martinsried)",
                buildingName: "Biozentrum Martinsried",
                address: "Großhaderner Str. 2, 82152 Planegg-Martinsried",
                floor: "Hörsaal- und Institutsgebäude",
                tip: "U-Bahn U6 Klinikum Großhadern + Bus 266 nach Martinsried",
                lmuRaumfinderCode: "bw2970",
                lmuRoomKey: nil,
                mapsURL: "https://maps.apple.com/?q=Grosshaderner+Strasse+2+Planegg"
            )
        }

        // 11. Special Halls in Hauptgebäude (GSP 1)
        if clean.contains("AUDIMAX") || clean.contains("AUDITORIUM") {
            return DecodedRoom(
                roomCode: raw,
                building: "LMU Hauptgebäude (Geschwister-Scholl-Platz 1)",
                buildingName: "Hauptgebäude (GSP 1)",
                address: "Geschwister-Scholl-Platz 1, 80539 München",
                floor: "Erdgeschoss (EG) • Nordflügel (Hörsaal A 030 / Audimax)",
                tip: "U-Bahn U3/U6 Universität (direkter Ausgang zum Lichthof)",
                lmuRaumfinderCode: "bw0000",
                lmuRoomKey: "000000100_",
                mapsURL: "https://maps.apple.com/?q=Geschwister-Scholl-Platz+1+Muenchen"
            )
        }

        if clean.contains("GROSSE AULA") || clean.contains("GROßE AULA") || clean.contains("AULA") {
            return DecodedRoom(
                roomCode: raw,
                building: "LMU Hauptgebäude (Geschwister-Scholl-Platz 1)",
                buildingName: "Hauptgebäude (GSP 1)",
                address: "Geschwister-Scholl-Platz 1, 80539 München",
                floor: "1. Obergeschoss (1. OG) • Lichthof (Große Aula / E 004)",
                tip: "U-Bahn U3/U6 Universität (direkter Ausgang zum Lichthof)",
                lmuRaumfinderCode: "bw0000",
                lmuRoomKey: "001900147_",
                mapsURL: "https://maps.apple.com/?q=Geschwister-Scholl-Platz+1+Muenchen"
            )
        }

        if clean.contains("LICHTHOF") || clean.contains("THOMAS-MANN") || clean.contains("SENATSSAAL") {
            return DecodedRoom(
                roomCode: raw,
                building: "LMU Hauptgebäude (Geschwister-Scholl-Platz 1)",
                buildingName: "Hauptgebäude (GSP 1)",
                address: "Geschwister-Scholl-Platz 1, 80539 München",
                floor: "Zentraler Lichthof / Thomas-Mann-Halle (1. OG)",
                tip: "U-Bahn U3/U6 Universität",
                lmuRaumfinderCode: "bw0000",
                lmuRoomKey: nil,
                mapsURL: "https://maps.apple.com/?q=Geschwister-Scholl-Platz+1+Muenchen"
            )
        }

        // 12. Main Building Tract Letters (A, B, C, D, E, F, M, N, U, V)
        // Matches patterns like "B 201", "B201", "A 140", "M 010", "N 120", "D 123", "F 012"
        let tracts = ["A", "B", "C", "D", "E", "F", "M", "N", "U", "V"]
        for tract in tracts {
            if clean.hasPrefix(tract) {
                let numberPart = clean.dropFirst().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                if let firstDigit = numberPart.first, firstDigit.isNumber || firstDigit == "U" {
                    let floorDesc: String
                    switch firstDigit {
                    case "0": floorDesc = "Erdgeschoss (EG)"
                    case "1": floorDesc = "1. Obergeschoss (1. OG)"
                    case "2": floorDesc = "2. Obergeschoss (2. OG)"
                    case "U": floorDesc = "Untergeschoss (UG)"
                    default: floorDesc = "Stockwerk laut Raumnummer"
                    }

                    let tractName: String
                    switch tract {
                    case "A": tractName = "Südflügel"
                    case "B": tractName = "Nordflügel"
                    case "C", "D": tractName = "Ostflügel"
                    case "E": tractName = "Südhof-Trakt"
                    case "F": tractName = "Nordhof-Trakt"
                    case "M": tractName = "Mittelbau / Lichthof"
                    case "N": tractName = "Nordtrakt"
                    default: tractName = "Trakt \(tract)"
                    }

                    let tractRoomKey: String?
                    let cleanNoSpace = clean.replacingOccurrences(of: " ", with: "")
                    switch cleanNoSpace {
                    case "B201": tractRoomKey = "001102201_"
                    case "N120": tractRoomKey = "002001120_"
                    case "A140": tractRoomKey = "000001225_"
                    case "M018": tractRoomKey = "002100133_"
                    case "E004": tractRoomKey = "001900147_"
                    default: tractRoomKey = nil
                    }

                    return DecodedRoom(
                        roomCode: raw,
                        building: "LMU Hauptgebäude (Geschwister-Scholl-Platz 1) • Trakt \(tract)",
                        buildingName: "Hauptgebäude (GSP 1)",
                        address: "Geschwister-Scholl-Platz 1, 80539 München",
                        floor: "\(floorDesc) (\(tractName))",
                        tip: "U-Bahn U3/U6 Universität (direkter Ausgang zum Lichthof)",
                        lmuRaumfinderCode: "bw0000",
                        lmuRoomKey: tractRoomKey,
                        mapsURL: "https://maps.apple.com/?q=Geschwister-Scholl-Platz+1+Muenchen"
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Private Matching Helpers

    private static func isSchellingstraßenRoom(_ clean: String) -> Bool {
        if clean.contains("SCHELLING") { return true }
        // Match S001, S002, S 001, S 002, S 004, S-002, S101, S201, S 101, etc.
        if clean.hasPrefix("S") {
            let remainder = clean.dropFirst().trimmingCharacters(in: CharacterSet(charactersIn: " -_."))
            if let first = remainder.first, first.isNumber {
                return true
            }
        }
        return false
    }

    private static func isJuridicumRoom(_ clean: String) -> Bool {
        if clean.hasPrefix("W") {
            let remainder = clean.dropFirst().trimmingCharacters(in: CharacterSet(charactersIn: " -_."))
            if let first = remainder.first, first.isNumber {
                return true
            }
        }
        return false
    }

    private static func isLeopoldRoomNumber(_ clean: String) -> Bool {
        // Rooms like 1201, 1301, 2101, 1001B
        let trimmed = clean.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard trimmed.count >= 4, trimmed.count <= 5 else { return false }
        let digits = trimmed.prefix(4)
        return digits.allSatisfy { $0.isNumber } && (digits.hasPrefix("1") || digits.hasPrefix("2") || digits.hasPrefix("3"))
    }

    private static func decodeLeopoldFloor(_ clean: String) -> String {
        let digits = clean.filter { $0.isNumber }
        if digits.count >= 2 {
            let house = digits.prefix(1)
            let floorDigit = digits.dropFirst().prefix(1)
            let floorName: String
            switch floorDigit {
            case "0": floorName = "Erdgeschoss (EG)"
            case "1": floorName = "1. Obergeschoss (1. OG)"
            case "2": floorName = "2. Obergeschoss (2. OG)"
            case "3": floorName = "3. Obergeschoss (3. OG)"
            default: floorName = "OG"
            }
            return "Haus \(house) • \(floorName)"
        }
        return "Haus 1–3"
    }
}
