//
//  ExerciseLibraryView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var search = ""
    @State private var showAdd = false

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            !exercise.isHidden && (search.isEmpty || exercise.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    ForEach(filtered) { exercise in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .foregroundStyle(.white)
                                Text(exercise.category)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer()
                            if exercise.isCustom {
                                Text("Custom")
                                    .font(.caption2.bold())
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .listRowBackground(AppTheme.card)
                        .swipeActions(edge: .trailing) {
                            if exercise.isCustom {
                                Button(role: .destructive) {
                                    hideExercise(exercise)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $search, prompt: "Search exercises")
            }
            .navigationTitle("Exercises")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddExerciseView()
            }
        }
    }

    private func hideExercise(_ exercise: Exercise) {
        exercise.isHidden = true
        try? modelContext.save()
    }
}

#Preview {
    ExerciseLibraryView()
        .modelContainer(for: [Exercise.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
