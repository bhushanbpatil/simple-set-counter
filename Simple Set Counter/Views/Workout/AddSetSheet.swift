//
//  AddSetSheet.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct AddSetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    let session: WorkoutSession
    let suggestedWeight: Double
    let suggestedReps: Int
    var onSetSaved: (() -> Void)? = nil

    @State private var weight: Double
    @State private var reps: Int
    @State private var isBodyweight: Bool

    init(
        exercise: Exercise,
        session: WorkoutSession,
        suggestedWeight: Double,
        suggestedReps: Int,
        onSetSaved: (() -> Void)? = nil
    ) {
        self.exercise = exercise
        self.session = session
        self.suggestedWeight = suggestedWeight
        self.suggestedReps = suggestedReps
        self.onSetSaved = onSetSaved
        _weight = State(initialValue: suggestedWeight)
        _reps = State(initialValue: max(1, suggestedReps))
        _isBodyweight = State(initialValue: Self.defaultBodyweightNames.contains(exercise.name) && suggestedWeight == 0)
    }

    private static let defaultBodyweightNames: Set<String> = ["Pull-Up", "Chin-Up", "Push-Up", "Dips"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(exercise.name)
                        .font(.headline)
                }

                Section("Set") {
                    Toggle("Bodyweight", isOn: $isBodyweight)

                    if !isBodyweight {
                        Stepper(value: $weight, in: 0...2000, step: AppSettings.weightStep) {
                            Text("Weight: \(AppSettings.formatWeight(weight))")
                        }
                    }

                    Stepper(value: $reps, in: 1...100) {
                        Text("Reps: \(reps)")
                    }
                }
            }
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSet()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveSet() {
        session.markStartedIfFirstSet()
        let sortIndex = session.sets.filter { $0.exercise?.id == exercise.id }.count
        let set = LoggedSet(
            weight: isBodyweight ? 0 : weight,
            reps: reps,
            isBodyweight: isBodyweight,
            sortIndex: sortIndex,
            exercise: exercise,
            session: session
        )
        modelContext.insert(set)
        session.sets.append(set)
        try? modelContext.save()
        onSetSaved?()
    }
}

#Preview {
    AddSetSheet(
        exercise: Exercise(name: "Squat", category: "Legs"),
        session: WorkoutSession(),
        suggestedWeight: 135,
        suggestedReps: 8
    )
    .modelContainer(for: [Exercise.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
