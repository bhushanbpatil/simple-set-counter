//
//  WorkoutDetailView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession

    @State private var showDeleteConfirm = false

    private var groupedSets: [(Exercise, [LoggedSet])] {
        let exercises = session.sets.compactMap(\.exercise)
        let unique = Dictionary(grouping: exercises, by: \.id).compactMap { $0.value.first }
        return unique.sorted { $0.name < $1.name }.map { exercise in
            let sets = session.sortedSets.filter { $0.exercise?.id == exercise.id }
            return (exercise, sets)
        }
    }

    private var isQuickLogOnly: Bool {
        session.isQuickLogSession && session.sets.isEmpty && !session.checkedExercises.isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            List {
                Section {
                    Text(session.startedAt, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                    if let ended = session.endedAt {
                        Text("Finished \(ended, format: .dateTime.hour().minute())")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    if !session.sets.isEmpty, let ended = session.endedAt {
                        Text("Duration \(AppSettings.formatDuration(ended.timeIntervalSince(session.startedAt)))")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    if isQuickLogOnly {
                        Text("Quick log — exercises only")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                if isQuickLogOnly {
                    Section("Exercises") {
                        ForEach(session.checkedExercises.sorted { $0.name < $1.name }) { exercise in
                            Text(exercise.name)
                        }
                    }
                }

                ForEach(groupedSets, id: \.0.id) { exercise, sets in
                    Section(exercise.name) {
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text("Set \(index + 1)")
                                    .foregroundStyle(AppTheme.secondaryText)
                                Spacer()
                                Text(set.isBodyweight ? "BW" : AppSettings.formatWeight(set.weight))
                                Text("× \(set.reps)")
                            }
                        }
                    }
                }

                Section {
                    Button("Delete Workout") {
                        showDeleteConfirm = true
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Delete this workout?", isPresented: $showDeleteConfirm) {
            Button("Delete") {
                modelContext.delete(session)
                try? modelContext.save()
                dismiss()
            }
            .foregroundStyle(AppTheme.accent)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(session: WorkoutSession(endedAt: .now))
    }
    .modelContainer(for: [Exercise.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
