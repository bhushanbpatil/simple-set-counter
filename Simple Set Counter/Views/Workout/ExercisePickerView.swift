//
//  ExercisePickerView.swift
//  Simple Set Counter
//

import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void

    @State private var search = ""
    @State private var showAddCustom = false

    private var filtered: [Exercise] {
        guard !search.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(String, [Exercise])] {
        Dictionary(grouping: filtered, by: \.category)
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { category, items in
                    Section(category) {
                        ForEach(items) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New") { showAddCustom = true }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddExerciseView()
            }
        }
    }
}

#Preview {
    ExercisePickerView(exercises: []) { _ in }
}
