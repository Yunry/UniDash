//
//  CalendarSyncService.swift
//  UniDash
//
//  EventKit calendar creation and EKRecurrenceRule recurring event synchronization.
//

import Foundation
import EventKit
import SwiftUI

/// Service responsible for managing EventKit calendar permissions, calendar creation,
/// and batch syncing timetable entries with weekly recurrence.
@MainActor
final class CalendarSyncService: ObservableObject {
    static let shared = CalendarSyncService()

    let eventStore = EKEventStore()

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isSyncing: Bool = false
    @Published var lastSyncCount: Int = 0
    @Published var errorMessage: String? = nil
    @Published var availableCalendars: [EKCalendar] = []

    nonisolated static let defaultCalendarName = "Uni Schedule"

    init() {
        checkAuthorizationStatus()
    }

    // MARK: - Permission Handling

    /// Checks the current authorization status for EventKit calendar events.
    func checkAuthorizationStatus() {
        if #available(iOS 17.0, macOS 14.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
        if isAuthorized {
            loadCalendars()
        }
    }

    var isAuthorized: Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
        } else {
            return authorizationStatus == .authorized
        }
    }

    /// Requests calendar access with fallback support across iOS 17+ and earlier versions.
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                checkAuthorizationStatus()
                return granted
            } catch {
                do {
                    let writeOnly = try await eventStore.requestWriteOnlyAccessToEvents()
                    checkAuthorizationStatus()
                    return writeOnly
                } catch {
                    self.errorMessage = "Kalenderzugriff abgelehnt: \(error.localizedDescription)"
                    checkAuthorizationStatus()
                    return false
                }
            }
        } else {
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                checkAuthorizationStatus()
                return granted
            } catch {
                self.errorMessage = "Kalenderzugriff fehlgeschlagen: \(error.localizedDescription)"
                checkAuthorizationStatus()
                return false
            }
        }
    }

    /// Loads user calendars eligible for storing course events.
    func loadCalendars() {
        let calendars = eventStore.calendars(for: .event)
        self.availableCalendars = calendars.filter { $0.allowsContentModifications }
    }

    // MARK: - Calendar Management

    /// Finds or creates a dedicated calendar (e.g. "Uni Schedule") to avoid polluting personal calendars.
    func findOrCreateUniCalendar(named name: String = defaultCalendarName) throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == name && $0.allowsContentModifications }) {
            return existing
        }

        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = name

        // Pick appropriate source (local or iCloud/CalDAV)
        let source: EKSource? = {
            if let defaultCal = eventStore.defaultCalendarForNewEvents, defaultCal.source.sourceType != .birthdays {
                return defaultCal.source
            }
            return eventStore.sources.first(where: { $0.sourceType == .calDAV })
                ?? eventStore.sources.first(where: { $0.sourceType == .local })
                ?? eventStore.sources.first
        }()

        guard let targetSource = source else {
            throw NSError(domain: "CalendarSyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Keine gültige Kalenderquelle auf dem Gerät gefunden."])
        }

        newCalendar.source = targetSource
        #if canImport(AppKit)
        newCalendar.cgColor = CGColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)
        #elseif canImport(UIKit)
        newCalendar.cgColor = UIColor.systemBlue.cgColor
        #endif

        try eventStore.saveCalendar(newCalendar, commit: true)
        loadCalendars()
        return newCalendar
    }

    // MARK: - Event Synchronization

    /// Batch syncs selected timetable entries into the target calendar with weekly recurrence.
    func syncEvents(
        entries: [TimetableEntry],
        semesterStartDate: Date,
        semesterEndDate: Date,
        targetCalendarName: String = defaultCalendarName,
        clearExisting: Bool = true
    ) async throws -> Int {
        if !isAuthorized {
            let granted = await requestAccess()
            guard granted else {
                throw NSError(domain: "CalendarSyncService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Kalenderzugriff wurde nicht erteilt."])
            }
        }

        isSyncing = true
        defer { isSyncing = false }

        let targetCalendar = try findOrCreateUniCalendar(named: targetCalendarName)

        // Clear existing events in date range if requested to prevent duplicates
        if clearExisting {
            purgeExistingEvents(in: targetCalendar, from: semesterStartDate, to: semesterEndDate)
        }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        let selectedEntries = entries.filter { $0.isSelected }
        var createdCount = 0

        for entry in selectedEntries {
            guard let firstOccurrence = calculateFirstOccurrence(
                dayOfWeek: entry.dayOfWeek,
                startTime: entry.startTime,
                after: semesterStartDate,
                calendar: calendar
            ),
            let firstEnd = calculateEndTime(
                from: firstOccurrence,
                endTime: entry.endTime,
                calendar: calendar
            ) else {
                continue
            }

            let event = EKEvent(eventStore: eventStore)
            event.title = entry.courseTitle
            event.location = entry.room
            event.notes = """
            UniDash Stundenplan
            Typ: \(entry.courseType ?? "Veranstaltung")
            Raum: \(entry.room)
            Dozent: \(entry.instructor ?? "k.A.")
            Wöchentlich wiederholend bis \(semesterEndDate.formatted(date: .abbreviated, time: .omitted))
            """
            event.calendar = targetCalendar
            event.startDate = firstOccurrence
            event.endDate = firstEnd

            // Weekly recurrence rule until semesterEndDate
            let recurrenceEnd = EKRecurrenceEnd(end: semesterEndDate)
            let recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: [EKRecurrenceDayOfWeek(entry.dayOfWeek.ekWeekday)],
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: recurrenceEnd
            )
            event.recurrenceRules = [recurrenceRule]

            // Default 15-minute alert before class
            event.addAlarm(EKAlarm(relativeOffset: -15 * 60))

            try eventStore.save(event, span: .futureEvents, commit: false)
            createdCount += 1
        }

        try eventStore.commit()
        self.lastSyncCount = createdCount
        return createdCount
    }

    /// Saves a single academic deadline (e.g. Rückmeldefrist) with an alarm into Apple Calendar
    func saveDeadlineToCalendar(deadline: AcademicDeadline, targetCalendarName: String = defaultCalendarName) async throws -> Bool {
        if !isAuthorized {
            let granted = await requestAccess()
            guard granted else {
                throw NSError(domain: "CalendarSyncService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Kalenderzugriff wurde nicht erteilt."])
            }
        }

        let targetCalendar = try findOrCreateUniCalendar(named: targetCalendarName)

        let event = EKEvent(eventStore: eventStore)
        event.title = "Uni-Frist: \(deadline.title)"
        event.notes = """
        UniDash Semestertermin
        \(deadline.subtitle)
        Kategorie: \(deadline.category.rawValue)
        """
        event.calendar = targetCalendar
        event.isAllDay = true
        event.startDate = deadline.endDate
        event.endDate = deadline.endDate

        // Add 3-day and 1-day reminder alarms
        event.addAlarm(EKAlarm(relativeOffset: -86400 * 3))
        event.addAlarm(EKAlarm(relativeOffset: -86400))

        try eventStore.save(event, span: .thisEvent, commit: true)
        return true
    }

    // MARK: - Helper Methods

    private func purgeExistingEvents(in targetCalendar: EKCalendar, from start: Date, to end: Date) {
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [targetCalendar])
        let existingEvents = eventStore.events(matching: predicate)
        for event in existingEvents {
            try? eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try? eventStore.commit()
    }

    private func calculateFirstOccurrence(dayOfWeek: DayOfWeek, startTime: String, after baseDate: Date, calendar: Calendar) -> Date? {
        var eventDate = baseDate
        var loopGuard = 0
        while calendar.component(.weekday, from: eventDate) != dayOfWeek.weekdayNumber && loopGuard < 8 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: eventDate) else { break }
            eventDate = next
            loopGuard += 1
        }

        let timeParts = startTime.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: eventDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }

    private func calculateEndTime(from startDate: Date, endTime: String, calendar: Calendar) -> Date? {
        let timeParts = endTime.split(separator: ":")
        guard timeParts.count == 2,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]) else {
            return calendar.date(byAdding: .minute, value: 90, to: startDate)
        }

        var components = calendar.dateComponents([.year, .month, .day], from: startDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }
}
