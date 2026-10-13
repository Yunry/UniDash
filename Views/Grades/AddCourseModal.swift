//
//  AddCourseModal.swift
//  UniDash
//
//  Modal sheet for adding or editing academic courses and grades.
//

import SwiftUI
import SwiftData

struct AddCourseModal: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var courseToEdit: Course?

    @State private var name: String = ""
    @State private var semester: String = "WS 2026/27"
    @State private var ects: Double = 5.0
    @State private var isGraded: Bool = true
    @State private var grade: Double = 1.7
    @State private var isCompleted: Bool = true

    private let semesterPresets = [
        "WS 2026/27", "SoSe 2026", "WS 2025/26",
        "1. Semester", "2. Semester", "3. Semester",
        "4. Semester", "5. Semester", "6. Semester",
        "Master 1. Sem.", "Master 2. Sem."
    ]

    private let standardGrades: [Double] = [
        1.0, 1.3, 1.7, 2.0, 2.3, 2.7, 3.0, 3.3, 3.7, 4.0, 5.0
    ]

    private let commonECTS: [Double] = [3.0, 5.0, 6.0, 8.0, 9.0, 10.0, 12.0]

    init(courseToEdit: Course? = nil) {
        self.courseToEdit = courseToEdit
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Course Details
                Section(header: Text("Moduldetails")) {
                    TextField("Modulname (z.B. Softwaretechnik)", text: $name)

                    Picker("Semester", selection: $semester) {
                        ForEach(semesterPresets, id: \.self) { sem in
                            Text(sem).tag(sem)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("ECTS-Leistungspunkte")
                            Spacer()
                            Text("\(String(format: "%.1f", ects)) ECTS")
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }

                        // Quick ECTS selector chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(commonECTS, id: \.self) { value in
                                    Button {
                                        ects = value
                                    } label: {
                                        Text("\(Int(value))")
                                            .font(.caption)
                                            .fontWeight(ects == value ? .bold : .regular)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(ects == value ? Color.blue : Color.secondary.opacity(0.15))
                                            .foregroundStyle(ects == value ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Stepper("", value: $ects, in: 1...30, step: 0.5)
                            .labelsHidden()
                    }
                }

                // MARK: - Completion & Grade
                Section(header: Text("Status & Benotung")) {
                    Toggle("Modul abgeschlossen", isOn: $isCompleted)

                    if isCompleted {
                        Toggle("Benotetes Modul", isOn: $isGraded)

                        if isGraded {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Note:")
                                    Spacer()
                                    Text(String(format: "%.1f", grade))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(grade <= 4.0 ? .green : .red)
                                    Text("(\(gradeDescription(for: grade)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Picker("Deutsche Note", selection: $grade) {
                                    ForEach(standardGrades, id: \.self) { g in
                                        Text(String(format: "%.1f", g)).tag(g)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.vertical, 4)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.blue)
                                Text("Unbenoteter Schein (Pass/Fail) — zählt für ECTS-Punkte, beeinflusst den Notenschnitt nicht.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(courseToEdit == nil ? "Kurs hinzufügen" : "Kurs bearbeiten")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveCourse()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let course = courseToEdit {
                    self.name = course.name
                    self.semester = course.semester
                    self.ects = course.ects
                    self.isCompleted = course.isCompleted
                    self.isGraded = course.isGraded
                    if let g = course.grade {
                        self.grade = g
                    }
                }
            }
        }
    }

    private func saveCourse() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let finalGrade: Double? = (isCompleted && isGraded) ? grade : nil

        if let course = courseToEdit {
            course.name = trimmedName
            course.semester = semester
            course.ects = ects
            course.isCompleted = isCompleted
            course.isGraded = isGraded
            course.grade = finalGrade
        } else {
            let newCourse = Course(
                name: trimmedName,
                semester: semester,
                ects: ects,
                grade: finalGrade,
                isCompleted: isCompleted,
                isGraded: isGraded
            )
            modelContext.insert(newCourse)
        }

        try? modelContext.save()
        dismiss()
    }

    private func gradeDescription(for grade: Double) -> String {
        switch grade {
        case 1.0...1.5: return "Sehr gut"
        case 1.6...2.5: return "Gut"
        case 2.6...3.5: return "Befriedigend"
        case 3.6...4.0: return "Ausreichend"
        default: return "Nicht bestanden"
        }
    }
}
