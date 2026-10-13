//
//  UniDashTests.swift
//  UniDashTests
//
//  Unit tests covering Course GPA math, PDF parsing heuristics, and Mensa data models.
//

import XCTest
import PDFKit


final class UniDashTests: XCTestCase {

    // MARK: - Course & GPA Calculations

    func testWeightedGermanGPACalculation() {
        // Course A: 8 ECTS, grade 1.3 -> 10.4
        // Course B: 6 ECTS, grade 2.0 -> 12.0
        // Course C: 6 ECTS, ungraded (pass/fail) -> should not affect GPA
        // Expected GPA: (10.4 + 12.0) / 14.0 = 22.4 / 14.0 = 1.60
        let c1 = Course(name: "Lineare Algebra", ects: 8.0, grade: 1.3, isCompleted: true)
        let c2 = Course(name: "Algorithmen", ects: 6.0, grade: 2.0, isCompleted: true)
        let c3 = Course(name: "Seminar (unbenotet)", ects: 6.0, grade: nil, isCompleted: true)
        let c4 = Course(name: "Noch nicht bestanden", ects: 5.0, grade: nil, isCompleted: false)

        let courses = [c1, c2, c3, c4]

        let gpa = Course.calculateGPA(from: courses)
        XCTAssertNotNil(gpa)
        XCTAssertEqual(gpa!, 1.6, accuracy: 0.01)

        let completedECTS = Course.calculateCompletedECTS(from: courses)
        // c1 (8) + c2 (6) + c3 (6) = 20 ECTS
        XCTAssertEqual(completedECTS, 20.0, accuracy: 0.01)
    }

    func testGradeDescriptions() {
        let excellent = Course(name: "Test", ects: 5.0, grade: 1.3, isCompleted: true)
        XCTAssertEqual(excellent.gradeDescription, "Sehr gut")

        let good = Course(name: "Test", ects: 5.0, grade: 2.3, isCompleted: true)
        XCTAssertEqual(good.gradeDescription, "Gut")

        let satisfactory = Course(name: "Test", ects: 5.0, grade: 3.0, isCompleted: true)
        XCTAssertEqual(satisfactory.gradeDescription, "Befriedigend")

        let sufficient = Course(name: "Test", ects: 5.0, grade: 3.7, isCompleted: true)
        XCTAssertEqual(sufficient.gradeDescription, "Ausreichend")

        let failed = Course(name: "Test", ects: 5.0, grade: 5.0, isCompleted: true)
        XCTAssertEqual(failed.gradeDescription, "Nicht bestanden")
    }

    // MARK: - DayOfWeek Parsing

    func testDayOfWeekParsing() {
        XCTAssertEqual(DayOfWeek.from(text: "Montag"), .monday)
        XCTAssertEqual(DayOfWeek.from(text: "Mo"), .monday)
        XCTAssertEqual(DayOfWeek.from(text: "Monday"), .monday)
        XCTAssertEqual(DayOfWeek.from(text: "Dienstag"), .tuesday)
        XCTAssertEqual(DayOfWeek.from(text: "Mittwoch"), .wednesday)
        XCTAssertEqual(DayOfWeek.from(text: "Donnerstag"), .thursday)
        XCTAssertEqual(DayOfWeek.from(text: "Freitag"), .friday)
        XCTAssertEqual(DayOfWeek.from(text: "Fr"), .friday)
    }

    // MARK: - PDF Schedule Parser Text Heuristics

    func testPDFScheduleParserTextExtraction() {
        let sampleTimetableText = """
        Stundenplan Wintersemester 2024/2025
        Montag
        08:15 - 09:45
        Höhere Mathematik I
        Hörsaal Audimax
        Vorlesung

        Mittwoch
        14:00 - 15:30
        Algorithmen und Datenstrukturen
        Gebäude 50.34 Raum 101
        Übung
        """

        let entries = PDFScheduleParser.shared.parse(text: sampleTimetableText)
        XCTAssertEqual(entries.count, 2)

        let first = entries[0]
        XCTAssertEqual(first.dayOfWeek, .monday)
        XCTAssertEqual(first.startTime, "08:15")
        XCTAssertEqual(first.endTime, "09:45")
        XCTAssertTrue(first.courseTitle.contains("Mathematik"))

        let second = entries[1]
        XCTAssertEqual(second.dayOfWeek, .wednesday)
        XCTAssertEqual(second.startTime, "14:00")
        XCTAssertEqual(second.endTime, "15:30")
        XCTAssertTrue(second.courseTitle.contains("Algorithmen"))
    }

    // MARK: - LMU Statistics 2D Grid Timetable Parsing

    func testLMUStatisticsSpatialPDFParsing() {
        let currentFile = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sampleURL = projectRoot.appendingPathComponent("Resources/stundenplan_ba_wise_202627.pdf")
        let pdfPath = sampleURL.path
        guard FileManager.default.fileExists(atPath: pdfPath),
              let doc = PDFDocument(url: sampleURL) else {
            return
        }

        let entries = PDFScheduleParser.shared.parse(document: doc)
        XCTAssertGreaterThanOrEqual(entries.count, 9)

        // Ensure no entry has "c.t." or "s.t." as title
        for entry in entries {
            XCTAssertFalse(entry.courseTitle.lowercased() == "c.t.")
            XCTAssertFalse(entry.courseTitle.lowercased() == "s.t.")
        }

        // Check for key modules
        let hasDeskriptive = entries.contains { $0.courseTitle.contains("Deskriptive Statistik") }
        let hasAnalysis = entries.contains { $0.courseTitle.contains("Analysis") }
        let hasSoftware = entries.contains { $0.courseTitle.contains("Statistische Software") }

        XCTAssertTrue(hasDeskriptive)
        XCTAssertTrue(hasAnalysis)
        XCTAssertTrue(hasSoftware)

        // Check that courses are distributed across days, not all on Monday
        let mondayCount = entries.filter { $0.dayOfWeek == .monday }.count
        let tuesdayCount = entries.filter { $0.dayOfWeek == .tuesday }.count
        let wednesdayCount = entries.filter { $0.dayOfWeek == .wednesday }.count
        let thursdayCount = entries.filter { $0.dayOfWeek == .thursday }.count
        let fridayCount = entries.filter { $0.dayOfWeek == .friday }.count

        XCTAssertGreaterThan(mondayCount, 0)
        XCTAssertGreaterThan(tuesdayCount, 0)
        XCTAssertGreaterThan(wednesdayCount, 0)
        XCTAssertGreaterThan(thursdayCount, 0)
        XCTAssertGreaterThan(fridayCount, 0)
    }

    // MARK: - Mensa JSON Decoding and Dietary Flags

    func testMensaMealDecodingAndDietaryFlags() throws {
        let json = """
        [
            {
                "id": 401,
                "name": "Veganes Thai-Curry mit Tofu und Jasminreis",
                "category": "Wok",
                "prices": {
                    "students": 2.60,
                    "employees": 4.10,
                    "others": 5.40
                },
                "notes": ["vegan", "Soja", "Sesam"]
            },
            {
                "id": 402,
                "name": "Schweineschnitzel Wiener Art mit Pommes",
                "category": "Klassiker",
                "prices": {
                    "students": 3.80,
                    "employees": 5.50
                },
                "notes": ["Schwein", "Gluten", "Eier"]
            }
        ]
        """.data(using: .utf8)!

        let meals = try JSONDecoder().decode([MensaMeal].self, from: json)
        XCTAssertEqual(meals.count, 2)

        let curry = meals[0]
        XCTAssertTrue(curry.isVegan)
        XCTAssertTrue(curry.isVegetarian)
        XCTAssertTrue(curry.isPorkFree)
        XCTAssertEqual(curry.studentPriceFormatted, "2,60 €")

        let schnitzel = meals[1]
        XCTAssertFalse(schnitzel.isVegan)
        XCTAssertFalse(schnitzel.isVegetarian)
        XCTAssertFalse(schnitzel.isPorkFree)
        XCTAssertEqual(schnitzel.studentPriceFormatted, "3,80 €")
    }

    // MARK: - LMU Munich Timetable Text Parsing

    func testLMUTimetableParsing() {
        let lmuText = """
        LUDWIG-MAXIMILIANS-UNIVERSITÄT MÜNCHEN
        Stundenplan Wintersemester 2024/2025
        Studiengang: Informatik (B.Sc.)

        Montag
        10:15 - 11:45
        Einführung in die Informatik
        Hörsaal B 201 Geschwister-Scholl-Platz 1
        Vorlesung
        Dozent: Prof. Dr. Kranzlmüller

        Dienstag
        08:15 - 09:45
        Lineare Algebra für Informatiker
        Hörsaal A 140 Hauptgebäude
        Vorlesung
        Dozent: Prof. Dr. Rosenschon

        Mittwoch
        14:15 - 15:45
        Rechnerarchitektur
        Raum B 052 Theresienstraße 39
        Vorlesung
        Dozent: Prof. Dr. Schulz

        Donnerstag
        12:15 - 13:45
        Algorithmen und Datenstrukturen
        Große Aula Geschwister-Scholl-Platz 1
        Vorlesung
        Dozent: Prof. Dr. Seidl

        Freitag
        10:15 - 11:45
        Diskrete Strukturen
        Hörsaal C 123 Hauptgebäude
        Übung
        Dozent: Dr. Reineke
        """

        let entries = PDFScheduleParser.shared.parse(text: lmuText)
        XCTAssertEqual(entries.count, 5)

        let mondayEntry = entries.first(where: { $0.dayOfWeek == .monday })
        XCTAssertNotNil(mondayEntry)
        XCTAssertEqual(mondayEntry?.startTime, "10:15")
        XCTAssertEqual(mondayEntry?.endTime, "11:45")
        XCTAssertTrue(mondayEntry?.courseTitle.contains("Informatik") ?? false)
        XCTAssertTrue(mondayEntry?.room.contains("B 201") ?? false)

        let tuesdayEntry = entries.first(where: { $0.dayOfWeek == .tuesday })
        XCTAssertNotNil(tuesdayEntry)
        XCTAssertEqual(tuesdayEntry?.startTime, "08:15")
        XCTAssertTrue(tuesdayEntry?.courseTitle.contains("Lineare Algebra") ?? false)
    }

    // MARK: - Munich Live API Decoding

    func testMunichLiveAPIDecoding() throws {
        let json = """
        {
            "canteen_id": "mensa-leopoldstr",
            "name": "Mensa Leopoldstraße",
            "days": [
                {
                    "date": "2024-10-14",
                    "dishes": [
                        {
                            "name": "Bio-Gemüse-Curry mit Duftreis",
                            "dish_type": "Tagesgericht",
                            "prices": {
                                "students": { "base_price": 2.50, "price_per_unit": null, "unit": null },
                                "staff": { "base_price": 4.50, "price_per_unit": null, "unit": null },
                                "guests": { "base_price": 6.00, "price_per_unit": null, "unit": null }
                            },
                            "labels": ["VEGETARIAN", "GLUTEN_FREE"]
                        }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MunichCanteenResponse.self, from: json)
        XCTAssertEqual(response.canteen_id, "mensa-leopoldstr")
        XCTAssertEqual(response.days?.count, 1)
        XCTAssertEqual(response.days?.first?.dishes.first?.name, "Bio-Gemüse-Curry mit Duftreis")
        XCTAssertEqual(response.days?.first?.dishes.first?.prices?.students?.base_price, 2.50)
    }

    // MARK: - Ungraded Pass/Fail Course Calculations

    func testUngradedPassFailCourseMath() {
        // Course 1: Graded, 6 ECTS, 1.0 -> 6.0
        // Course 2: Graded, 6 ECTS, 2.0 -> 12.0
        // Course 3: Ungraded (Pass/Fail), 6 ECTS -> counts toward total ECTS, not GPA
        // Expected GPA: (6.0 + 12.0) / 12.0 = 1.50
        let c1 = Course(name: "Mathematik", ects: 6.0, grade: 1.0, isCompleted: true, isGraded: true)
        let c2 = Course(name: "Informatik", ects: 6.0, grade: 2.0, isCompleted: true, isGraded: true)
        let c3 = Course(name: "Soft Skills Praktikum", ects: 6.0, grade: nil, isCompleted: true, isGraded: false)

        let courses = [c1, c2, c3]

        let gpa = Course.calculateGPA(from: courses)
        XCTAssertNotNil(gpa)
        XCTAssertEqual(gpa!, 1.5, accuracy: 0.01)

        let totalCompleted = Course.calculateCompletedECTS(from: courses)
        XCTAssertEqual(totalCompleted, 18.0)

        let gradedECTS = Course.calculateGradedCompletedECTS(from: courses)
        XCTAssertEqual(gradedECTS, 12.0)

        let ungradedECTS = Course.calculateUngradedCompletedECTS(from: courses)
        XCTAssertEqual(ungradedECTS, 6.0)

        XCTAssertEqual(c3.formattedGrade, "Pass")
        XCTAssertEqual(c3.gradeDescription, "Bestanden (Pass)")
    }

    // MARK: - Campus Library Occupancy & Opening

    func testCampusLibraryOccupancyAndOpening() {
        let libraries = CampusLibrary.defaultLibraries
        XCTAssertGreaterThan(libraries.count, 5)

        let philo = libraries.first(where: { $0.id == "phil" })
        XCTAssertNotNil(philo)
        XCTAssertEqual(philo?.totalSeats, 600)
        XCTAssertEqual(philo?.occupancyFeedID, "phil")

        // Test weekday opening hours (Monday = 2 in Gregorian)
        let mondayHours = philo?.hours.hours(onWeekday: 2)
        XCTAssertNotNil(mondayHours)
        XCTAssertEqual(mondayHours?.open, 8 * 60)
        XCTAssertEqual(mondayHours?.close, 22 * 60)

        // Test Bavarian holiday calendar
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let neujahr = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        XCTAssertTrue(UBClosureCalendar.isClosedDay(neujahr))
        XCTAssertFalse(philo?.isOpen(at: neujahr) ?? true)

        // Test Platzfinder live widget HTML parsing
        let sampleHTML = """
        <script>
        var data = google.visualization.arrayToDataTable([['Lesesaal', 'belegte Plätze', 'freie Plätze'],['FB Philologicum',68,32]]);
        </script>
        <div id="chart_text1">FB Philologicum<br>Plätze gesamt: 600</div>
        """
        let parsed = LibraryOccupancyService.parse(html: sampleHTML)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.occupiedPercent, 68)
        XCTAssertEqual(parsed?.totalSeats, 600)
        XCTAssertEqual(parsed?.level, .moderate)
        XCTAssertEqual(parsed?.freeSeats, 192)
    }

    // MARK: - Academic Deadlines & Timeline

    func testAcademicDeadlinesAndCountdown() {
        let semesters = AcademicSemester.sampleSemesters
        XCTAssertEqual(semesters.count, 2)

        let ws = semesters.first(where: { $0.name == "WS 26/27" })
        XCTAssertNotNil(ws)

        let rereg = ws?.deadlines.first(where: { $0.category == .reRegistration })
        XCTAssertNotNil(rereg)
        XCTAssertTrue(rereg?.isCritical ?? false)
    }

    // MARK: - Campus Room Decoder

    func testCampusRoomDecoder() {
        let res1 = CampusBuildingGuide.decode(roomCode: "B 201")
        XCTAssertNotNil(res1)
        XCTAssertTrue(res1?.building.contains("Hauptgebäude") ?? false)
        XCTAssertTrue(res1?.floor.contains("2. Obergeschoss") ?? false)
        XCTAssertTrue(res1?.raumfinderURL.contains("bw0000") ?? false)

        let res2 = CampusBuildingGuide.decode(roomCode: "A 014")
        XCTAssertNotNil(res2)
        XCTAssertTrue(res2?.building.contains("Trakt A") ?? false)
        XCTAssertTrue(res2?.floor.contains("Erdgeschoss") ?? false)
        XCTAssertTrue(res2?.raumfinderURL.contains("bw0000") ?? false)

        let res3 = CampusBuildingGuide.decode(roomCode: "Theresienstr. 39")
        XCTAssertNotNil(res3)
        XCTAssertTrue(res3?.building.contains("MINT") ?? false)
        XCTAssertTrue(res3?.raumfinderURL.contains("bw1003") ?? false)
    }
}
