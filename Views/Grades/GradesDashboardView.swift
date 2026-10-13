//
//  GradesDashboardView.swift
//  UniDash
//
//  Grades and ECTS dashboard with weighted German GPA, degree progress gauge, and semester grouping.
//

import SwiftUI
import SwiftData

struct GradesDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.createdAt, order: .forward) private var allCourses: [Course]

    @AppStorage("targetECTS") private var targetECTS: Double = 180.0
    @State private var showAddCourseSheet: Bool = false
    @State private var courseToEdit: Course? = nil
    @State private var showTargetSettings: Bool = false

    // MARK: - Computed Metrics

    private var completedECTS: Double {
        Course.calculateCompletedECTS(from: allCourses)
    }

    private var currentGPA: Double? {
        Course.calculateGPA(from: allCourses)
    }

    private var degreeProgressRatio: Double {
        guard targetECTS > 0 else { return 0 }
        return min(1.0, max(0.0, completedECTS / targetECTS))
    }

    private var groupedBySemester: [String: [Course]] {
        Dictionary(grouping: allCourses, by: { $0.semester })
    }

    private var sortedSemesters: [String] {
        groupedBySemester.keys.sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - KPI Hero Metrics Cards
                Section {
                    VStack(spacing: 16) {
                        // Degree Progress Gauge
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                                    .frame(width: 84, height: 84)

                                Circle()
                                    .trim(from: 0.0, to: CGFloat(degreeProgressRatio))
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [.blue, .indigo, .purple]),
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 84, height: 84)

                                VStack(spacing: 2) {
                                    Text("\(Int(degreeProgressRatio * 100))%")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                    Text("Fortschritt")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Studienfortschritt")
                                    .font(.headline)

                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(String(format: "%.1f", completedECTS))")
                                        .font(.system(size: 26, weight: .bold, design: .rounded))
                                        .foregroundStyle(.blue)
                                    Text("/ \(Int(targetECTS)) ECTS")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                let remaining = max(0, targetECTS - completedECTS)
                                let gradedECTS = Course.calculateGradedCompletedECTS(from: allCourses)
                                let ungradedECTS = Course.calculateUngradedCompletedECTS(from: allCourses)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Noch \(String(format: "%.1f", remaining)) ECTS bis zum Abschluss")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if ungradedECTS > 0 {
                                        Text("\(String(format: "%.0f", gradedECTS)) benotet • \(String(format: "%.0f", ungradedECTS)) Pass/Fail")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary.opacity(0.8))
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Divider()

                        // Key Stats Grid
                        HStack(spacing: 12) {
                            // Weighted GPA Card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notendurchschnitt")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                if let gpa = currentGPA {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(String(format: "%.2f", gpa))
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundStyle(gpaColor(for: gpa))
                                        Text(gpaLabel(for: gpa))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("—")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            // Modules Count Card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Abgeschlossen")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                let passedCount = allCourses.filter { $0.isPassed }.count
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(passedCount)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                    Text("/ \(allCourses.count) Module")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)

                // MARK: - Grouped Courses by Semester
                if allCourses.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "graduationcap")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue.opacity(0.6))
                            Text("Noch keine Kurse eingetragen")
                                .font(.headline)
                            Text("Erfassen Sie Ihre Vorlesungen, Prüfungen und Noten, um Ihren Notenschnitt automatisch zu berechnen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button("Beispiel-Kurse laden") {
                                loadSampleCourses()
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    ForEach(sortedSemesters, id: \.self) { semester in
                        if let courses = groupedBySemester[semester] {
                            let semECTS = courses.filter { $0.isPassed }.reduce(0.0) { $0 + $1.ects }
                            let semGPA = Course.calculateGPA(from: courses)

                            Section(header: HStack {
                                Text(semester)
                                    .font(.headline)
                                Spacer()
                                if let gpa = semGPA {
                                    Text("Ø \(String(format: "%.2f", gpa))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 4)
                                }
                                Text("\(String(format: "%.0f", semECTS)) ECTS")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }) {
                                ForEach(courses) { course in
                                    CourseRow(course: course)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            courseToEdit = course
                                        }
                                }
                                .onDelete { offsets in
                                    deleteCourses(in: courses, at: offsets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Noten & ECTS")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddCourseSheet = true
                    } label: {
                        Label("Kurs hinzufügen", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .navigation) {
                    Menu {
                        Button("Bachelor-Ziel (180 ECTS)") { targetECTS = 180.0 }
                        Button("Master-Ziel (120 ECTS)") { targetECTS = 120.0 }
                        Button("Diplom/Staatsexamen (240 ECTS)") { targetECTS = 240.0 }
                        Divider()
                        Button("Beispiel-Notenspiegel laden") { loadSampleCourses() }
                    } label: {
                        Label("Optionen", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showAddCourseSheet) {
                AddCourseModal()
            }
            .sheet(item: $courseToEdit) { course in
                AddCourseModal(courseToEdit: course)
            }
        }
    }

    // MARK: - Actions

    private func deleteCourses(in list: [Course], at offsets: IndexSet) {
        for index in offsets {
            let course = list[index]
            modelContext.delete(course)
        }
        try? modelContext.save()
    }

    private func loadSampleCourses() {
        for course in Course.sampleCourses {
            modelContext.insert(course)
        }
        try? modelContext.save()
    }

    private func gpaColor(for gpa: Double) -> Color {
        switch gpa {
        case 1.0...2.0: return .green
        case 2.1...3.0: return .blue
        case 3.1...4.0: return .orange
        default: return .red
        }
    }

    private func gpaLabel(for gpa: Double) -> String {
        switch gpa {
        case 1.0...1.5: return "Sehr gut"
        case 1.6...2.5: return "Gut"
        case 2.6...3.5: return "Befriedigend"
        case 3.6...4.0: return "Ausreichend"
        default: return "Nicht bestanden"
        }
    }
}

// MARK: - Course Row Component

struct CourseRow: View {
    let course: Course

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: course.isCompleted ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(course.isPassed ? .green : (course.isCompleted ? .red : .secondary))

            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Text("\(String(format: "%.1f", course.ects)) ECTS")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)

                    if !course.isCompleted {
                        Text("• In Arbeit")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Grade Badge
            if let grade = course.grade {
                Text(course.formattedGrade)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(gradeColor(for: grade).opacity(0.15))
                    .foregroundStyle(gradeColor(for: grade))
                    .clipShape(Capsule())
            } else if course.isCompleted {
                Text(course.isGraded ? "Bestanden" : "Pass/Fail")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(course.isGraded ? Color.secondary.opacity(0.12) : Color.blue.opacity(0.15))
                    .foregroundStyle(course.isGraded ? Color.secondary : Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private func gradeColor(for grade: Double) -> Color {
        switch grade {
        case 1.0...1.5: return .green
        case 1.6...2.5: return .blue
        case 2.6...3.5: return .orange
        default: return .red
        }
    }
}
