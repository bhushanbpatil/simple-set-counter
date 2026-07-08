//
//  WorkoutSummaryBuilder.swift
//  Simple Set Counter
//

import Foundation

struct ExerciseSummaryRow: Identifiable {
    let id: UUID
    let name: String
    let setCount: Int
    let repCount: Int
}

struct WorkoutSummaryData: Identifiable {
    let id: UUID
    let duration: TimeInterval
    let totalSets: Int
    let totalReps: Int
    let exerciseCount: Int
    let totalVolume: Double
    let exerciseRows: [ExerciseSummaryRow]
}

enum WorkoutSummaryBuilder {
    static func build(from session: WorkoutSession) -> WorkoutSummaryData {
        let sets = session.sortedSets
        let end = session.endedAt ?? .now
        let duration = max(0, end.timeIntervalSince(session.startedAt))

        let totalReps = sets.reduce(0) { $0 + $1.reps }
        let totalVolume = sets
            .filter { !$0.isBodyweight }
            .reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

        let grouped = Dictionary(grouping: sets) { $0.exercise?.id }
        let exerciseRows = grouped
            .compactMap { exerciseID, exerciseSets -> ExerciseSummaryRow? in
                guard let exerciseID, let name = exerciseSets.first?.exercise?.name else { return nil }
                return ExerciseSummaryRow(
                    id: exerciseID,
                    name: name,
                    setCount: exerciseSets.count,
                    repCount: exerciseSets.reduce(0) { $0 + $1.reps }
                )
            }
            .sorted { lhs, rhs in
                if lhs.setCount != rhs.setCount { return lhs.setCount > rhs.setCount }
                return lhs.name < rhs.name
            }

        return WorkoutSummaryData(
            id: session.id,
            duration: duration,
            totalSets: sets.count,
            totalReps: totalReps,
            exerciseCount: exerciseRows.count,
            totalVolume: totalVolume,
            exerciseRows: exerciseRows
        )
    }
}
