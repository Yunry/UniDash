//
//  LibraryOccupancyService.swift
//  UniDash
//
//  Fetches real seat occupancy from the LMU UB-Platzfinder
//  (https://www.ub.lmu.de/de/standorte/platzfinder/). Each location exposes a
//  small HTML widget at auslastung.ub.uni-muenchen.de that embeds a Google
//  Charts data row like ['FB Philologicum',68,32] (belegt %, frei %) and the
//  text "Plätze gesamt: 600". There is no official JSON API, so parsing is
//  deliberately defensive: on any mismatch the location simply shows
//  "keine Live-Daten".
//

import Foundation

public struct LibraryOccupancy: Equatable, Sendable {
    public let occupiedPercent: Int
    public let totalSeats: Int?
    public let fetchedAt: Date

    public var level: OccupancyLevel { OccupancyLevel(occupiedPercent: occupiedPercent) }

    public var freeSeats: Int? {
        guard let totalSeats else { return nil }
        return max(0, Int((Double(totalSeats) * Double(100 - occupiedPercent) / 100.0).rounded()))
    }
}

@MainActor
final class LibraryOccupancyService: ObservableObject {
    @Published private(set) var occupancy: [String: LibraryOccupancy] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var failedAll: Bool = false

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated static func feedURL(for feedID: String) -> URL? {
        var comps = URLComponents(string: "https://auslastung.ub.uni-muenchen.de/index.php")
        comps?.queryItems = [
            URLQueryItem(name: "r", value: "site/grafik"),
            URLQueryItem(name: "user", value: feedID)
        ]
        return comps?.url
    }

    /// Refreshes all given feeds concurrently. Feeds that fail keep their previous value.
    func refresh(feedIDs: [String]) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let session = self.session
        let results: [(String, LibraryOccupancy?)] = await withTaskGroup(of: (String, LibraryOccupancy?).self) { group in
            for id in Set(feedIDs) {
                group.addTask {
                    (id, await Self.fetch(feedID: id, session: session))
                }
            }
            var collected: [(String, LibraryOccupancy?)] = []
            for await r in group { collected.append(r) }
            return collected
        }

        var successCount = 0
        for (id, value) in results {
            if let value {
                occupancy[id] = value
                successCount += 1
            }
        }
        failedAll = successCount == 0 && !results.isEmpty
        if successCount > 0 { lastUpdated = Date() }
    }

    private nonisolated static func fetch(feedID: String, session: URLSession) async -> LibraryOccupancy? {
        guard let url = feedURL(for: feedID) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("UniDash/1.0 (iOS/macOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return parse(html: String(decoding: data, as: UTF8.self), fetchedAt: Date())
        } catch {
            return nil
        }
    }

    /// Parses the Platzfinder widget HTML. Returns nil if the expected data row is missing or implausible.
    nonisolated static func parse(html: String, fetchedAt: Date = Date()) -> LibraryOccupancy? {
        // Data row: ['<name>',<occupied>,<free>]  (the header row contains no numbers and won't match)
        guard let row = firstMatch(#"\[\s*'[^']*'\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\]"#, in: html),
              row.count == 2,
              let occupied = Int(row[0]), let free = Int(row[1]),
              (0...100).contains(occupied), (0...100).contains(free),
              abs(occupied + free - 100) <= 2 else {
            return nil
        }
        let total = firstMatch(#"Pl(?:ä|&auml;|&#228;)tze\s+gesamt:\s*(\d+)"#, in: html).flatMap { $0.first }.flatMap(Int.init)
        return LibraryOccupancy(occupiedPercent: occupied, totalSeats: total, fetchedAt: fetchedAt)
    }

    private nonisolated static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        return (1..<m.numberOfRanges).compactMap { idx in
            Range(m.range(at: idx), in: text).map { String(text[$0]) }
        }
    }
}
