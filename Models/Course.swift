//
//  Course.swift
//  UniDash
//
//  SwiftData model representing academic courses, ECTS credits, and grades.
//

import Foundation
import SwiftData

@Model
final class Course {
    @Attribute(.unique) var id: UUID
    var name: String
    var semester: String
    var ects: Double
    var grade: Double?
    var isCompleted: Bool
    var isGraded: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        semester: String = "Semester 1",
        ects: Double = 5.0,
        grade: Double? = nil,
        isCompleted: Bool = false,
        isGraded: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.semester = semester
        self.ects = ects
        self.grade = grade
        self.isCompleted = isCompleted
        self.isGraded = isGraded
        self.createdAt = createdAt
    }

    /// Whether the course is passed according to the German academic grading system (<= 4.0 or Pass/Fail)
    var isPassed: Bool {
        guard isCompleted else { return false }
        if !isGraded { return true }
        if let grade = grade {
            return grade <= 4.0
        }
        return true
    }

    /// German academic grade description label
    var gradeDescription: String {
        guard isGraded else { return "Bestanden (Pass)" }
        guard let grade = grade else { return "Ausstehend" }
        switch grade {
        case 1.0...1.5:
            return "Sehr gut"
        case 1.6...2.5:
            return "Gut"
        case 2.6...3.5:
            return "Befriedigend"
        case 3.6...4.0:
            return "Ausreichend"
        default:
            return "Nicht bestanden"
        }
    }

    /// Formatted grade string (e.g. "1.3", "Pass", or "—")
    var formattedGrade: String {
        guard isGraded else { return "Pass" }
        guard let grade = grade else { return "—" }
        return String(format: "%.1f", grade)
    }

    // MARK: - Metric Calculations

    /// Computes the weighted German GPA: Sum(grade * ects) / Sum(ects for graded modules)
    static func calculateGPA(from courses: [Course]) -> Double? {
        let gradedCourses = courses.filter { $0.isCompleted && $0.isGraded && $0.grade != nil }
        let totalWeighted = gradedCourses.reduce(0.0) { $0 + (($1.grade ?? 0.0) * $1.ects) }
        let totalEcts = gradedCourses.reduce(0.0) { $0 + $1.ects }

        guard totalEcts > 0 else { return nil }
        return totalWeighted / totalEcts
    }

    /// Computes total completed ECTS credits: Sum of ects where isCompleted == true and passed
    static func calculateCompletedECTS(from courses: [Course]) -> Double {
        courses.filter { $0.isPassed }.reduce(0.0) { $0 + $1.ects }
    }

    /// Graded completed ECTS credits contributing to the GPA
    static func calculateGradedCompletedECTS(from courses: [Course]) -> Double {
        courses.filter { $0.isPassed && $0.isGraded }.reduce(0.0) { $0 + $1.ects }
    }

    /// Ungraded completed ECTS credits (Pass/Fail)
    static func calculateUngradedCompletedECTS(from courses: [Course]) -> Double {
        courses.filter { $0.isPassed && !$0.isGraded }.reduce(0.0) { $0 + $1.ects }
    }

    /// Total enrolled ECTS across all listed courses
    static func calculateTotalEnrolledECTS(from courses: [Course]) -> Double {
        courses.reduce(0.0) { $0 + $1.ects }
    }

    // MARK: - Previews & Sample Data

    static var sampleCourses: [Course] {
        [
            Course(name: "Lineare Algebra I", semester: "1. Semester", ects: 8.0, grade: 1.3, isCompleted: true, isGraded: true),
            Course(name: "Analysis I", semester: "1. Semester", ects: 8.0, grade: 1.7, isCompleted: true, isGraded: true),
            Course(name: "Programmieren I (Java)", semester: "1. Semester", ects: 6.0, grade: 1.0, isCompleted: true, isGraded: true),
            Course(name: "Allgemeine Schlüsselqualifikation", semester: "1. Semester", ects: 3.0, grade: nil, isCompleted: true, isGraded: false),
            Course(name: "Algorithmen & Datenstrukturen", semester: "2. Semester", ects: 8.0, grade: 2.0, isCompleted: true, isGraded: true),
            Course(name: "Softwaretechnik", semester: "2. Semester", ects: 6.0, grade: 1.3, isCompleted: true, isGraded: true),
            Course(name: "Theoretische Informatik", semester: "2. Semester", ects: 6.0, grade: 2.7, isCompleted: true, isGraded: true),
            Course(name: "Fachpraktikum Softwareentwicklung", semester: "2. Semester", ects: 6.0, grade: nil, isCompleted: true, isGraded: false),
            Course(name: "Datenbanksysteme", semester: "3. Semester", ects: 6.0, grade: nil, isCompleted: false, isGraded: true),
            Course(name: "Computernetze & Verteilte Systeme", semester: "3. Semester", ects: 6.0, grade: nil, isCompleted: false, isGraded: true),
            Course(name: "Rechnerarchitektur", semester: "3. Semester", ects: 6.0, grade: nil, isCompleted: false, isGraded: true)
        ]
    }
}
