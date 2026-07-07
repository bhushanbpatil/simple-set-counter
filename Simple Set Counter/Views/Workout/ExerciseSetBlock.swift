//
//  ExerciseSetBlock.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct ExerciseSetBlock: View {
    @Environment(\.modelContext) private var modelContext

    let exercise: Exercise
    let session: WorkoutSession?
    let onAddSet: () -> Void

    @State private var priorSet: LoggedSet?

    private var sets: [LoggedSet] {
        guard let session else { return [] }
        return session.sortedSets.filter { $0.exercise?.id == exercise.id }
    }

    private var weightLabel: String {
        if let current = sets.last {
            return current.isBodyweight ? "BW × \(current.reps)" : "\(AppSettings.formatWeight(current.weight)) × \(current.reps)"
        }
        if let suggestion = AppSettings.smartIncreaseSuggestion(for: exercise.id) {
            return "\(AppSettings.formatWeight(suggestion.weight)) × \(suggestion.reps)"
        }
        if let last = priorSet {
            return last.isBodyweight ? "BW × \(last.reps)" : "\(AppSettings.formatWeight(last.weight)) × \(last.reps)"
        }
        return "No sets yet"
    }

    private var weightCaption: String {
        if !sets.isEmpty { return "Current" }
        if AppSettings.smartIncreaseSuggestion(for: exercise.id) != nil { return "Suggested" }
        return "Last time"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(weightCaption)
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.accent)
                    Text(weightLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(action: onAddSet) {
                    Image(systemName: "plus")
                        .font(.headline.bold())
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 52, alignment: .leading)
                    Text(set.isBodyweight ? "BW" : AppSettings.formatWeight(set.weight))
                    Text("×")
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("\(set.reps) reps")
                    Spacer()
                    Button(role: .destructive) {
                        deleteSet(set)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
                .font(.subheadline.weight(.semibold))
            }

            if let lastSet = sets.last, session != nil {
                Button("Duplicate last set") {
                    duplicateSet(lastSet)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: refreshToken) {
            priorSet = ProgressCalculator.fetchLastSet(for: exercise, before: session, context: modelContext)
        }
    }

    private var refreshToken: String {
        "\(exercise.id.uuidString)-\(session?.sets.count ?? 0)"
    }

    private func duplicateSet(_ set: LoggedSet) {
        guard let session else { return }
        session.markStartedIfFirstSet()
        let nextIndex = session.sets.filter { $0.exercise?.id == exercise.id }.count
        let copy = LoggedSet(
            weight: set.weight,
            reps: set.reps,
            isBodyweight: set.isBodyweight,
            sortIndex: nextIndex,
            exercise: exercise,
            session: session
        )
        modelContext.insert(copy)
        session.sets.append(copy)
        try? modelContext.save()
    }

    private func deleteSet(_ set: LoggedSet) {
        modelContext.delete(set)
        try? modelContext.save()
    }
}
