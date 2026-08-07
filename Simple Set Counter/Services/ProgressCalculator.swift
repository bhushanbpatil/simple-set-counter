//
//  ProgressCalculator.swift
//  Simple Set Counter
//

import Foundation
import SwiftData

enum ProgressRange: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneMonth: return "1 month"
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .oneYear: return "1 year"
        case .all: return "All time"
        }
    }

    func startDate(from end: Date = .now) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .oneMonth: return calendar.date(byAdding: .month, value: -1, to: end)
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: end)
        case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: end)
        case .oneYear: return calendar.date(byAdding: .year, value: -1, to: end)
        case .all: return nil
        }
    }
}

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Double
    let totalReps: Int
    let totalVolume: Double
}

struct ProgressSummary {
    let points: [ProgressDataPoint]
    let deltaWeight: Double?
    let deltaVolume: Double?
    let workoutDays: Int
    let latestMax: Double?
    let latestVolume: Double?
}

enum ProgressCalculator {
    static func summary(for sets: [LoggedSet], range: ProgressRange) -> ProgressSummary {
        let calendar = Calendar.current
        let filtered: [LoggedSet]
        if let start = range.startDate() {
            filtered = sets.filter { $0.completedAt >= start }
        } else {
            filtered = sets
        }

        let grouped = Dictionary(grouping: filtered) { set in
            calendar.startOfDay(for: set.completedAt)
        }

        let points = grouped.keys.sorted().map { day -> ProgressDataPoint in
            let daySets = grouped[day] ?? []
            let weighted = daySets.filter { !$0.isBodyweight && $0.weight > 0 }
            let maxWeight = weighted.map(\.weight).max() ?? 0
            let reps = daySets.map(\.reps).reduce(0, +)
            let volume = weighted.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
            return ProgressDataPoint(
                date: day,
                maxWeight: maxWeight,
                totalReps: reps,
                totalVolume: volume
            )
        }

        let weightPoints = points.filter { $0.maxWeight > 0 }
        let volumePoints = points.filter { $0.totalVolume > 0 }

        let deltaWeight: Double?
        if weightPoints.count >= 2,
           let first = weightPoints.first?.maxWeight,
           let last = weightPoints.last?.maxWeight {
            deltaWeight = last - first
        } else {
            deltaWeight = nil
        }

        let deltaVolume: Double?
        if volumePoints.count >= 2,
           let first = volumePoints.first?.totalVolume,
           let last = volumePoints.last?.totalVolume {
            deltaVolume = last - first
        } else {
            deltaVolume = nil
        }

        let workoutDays = Set(filtered.compactMap { $0.session?.id }).count

        return ProgressSummary(
            points: points,
            deltaWeight: deltaWeight,
            deltaVolume: deltaVolume,
            workoutDays: workoutDays,
            latestMax: weightPoints.last?.maxWeight,
            latestVolume: volumePoints.last?.totalVolume
        )
    }

    struct NextSetSuggestion {
        let weight: Double
        let reps: Int
        let isBodyweight: Bool
        let isSmartIncrease: Bool

        var caption: String { isSmartIncrease ? "Suggested" : "Last time" }

        var label: String {
            if isBodyweight || weight <= 0 {
                return "BW × \(reps)"
            }
            return "\(AppSettings.formatWeight(weight)) × \(reps)"
        }
    }

    static func lastSet(for exercise: Exercise, before session: WorkoutSession?, in sets: [LoggedSet]) -> LoggedSet? {
        sets
            .filter { $0.exercise?.id == exercise.id && $0.session?.id != session?.id }
            .sorted { $0.completedAt > $1.completedAt }
            .first
    }

    static func fetchLastSet(for exercise: Exercise, before session: WorkoutSession?, context: ModelContext) -> LoggedSet? {
        priorSets(for: exercise, before: session, context: context).first
    }

    /// Heaviest weighted set from the most recent prior workout for this exercise.
    /// Falls back to the latest bodyweight set when there is no weighted history.
    static func fetchWorkingSet(for exercise: Exercise, before session: WorkoutSession?, context: ModelContext) -> LoggedSet? {
        let prior = priorSets(for: exercise, before: session, context: context)
        guard !prior.isEmpty else { return nil }

        let latestSessionID = prior.first?.session?.id
        let fromLatestWorkout = prior.filter { $0.session?.id == latestSessionID }
        let candidates = fromLatestWorkout.isEmpty ? prior : fromLatestWorkout

        if let heaviest = candidates
            .filter({ !$0.isBodyweight && $0.weight > 0 })
            .max(by: { lhs, rhs in
                if lhs.weight != rhs.weight { return lhs.weight < rhs.weight }
                if lhs.reps != rhs.reps { return lhs.reps < rhs.reps }
                return lhs.completedAt < rhs.completedAt
            }) {
            return heaviest
        }

        return candidates.max(by: { $0.completedAt < $1.completedAt })
    }

    /// Next weight/reps to offer: your last working set, or +increment when that set earned it.
    static func nextSetSuggestion(
        for exercise: Exercise,
        before session: WorkoutSession?,
        context: ModelContext
    ) -> NextSetSuggestion? {
        guard let working = fetchWorkingSet(for: exercise, before: session, context: context) else {
            return nil
        }

        if working.isBodyweight || working.weight <= 0 {
            return NextSetSuggestion(
                weight: 0,
                reps: working.reps,
                isBodyweight: true,
                isSmartIncrease: false
            )
        }

        if AppSettings.smartIncreaseEnabled,
           working.reps > AppSettings.smartIncreaseRepThreshold {
            return NextSetSuggestion(
                weight: working.weight + AppSettings.smartIncreaseIncrement,
                reps: working.reps,
                isBodyweight: false,
                isSmartIncrease: true
            )
        }

        return NextSetSuggestion(
            weight: working.weight,
            reps: working.reps,
            isBodyweight: false,
            isSmartIncrease: false
        )
    }

    private static func priorSets(
        for exercise: Exercise,
        before session: WorkoutSession?,
        context: ModelContext
    ) -> [LoggedSet] {
        let exerciseID = exercise.id
        var descriptor = FetchDescriptor<LoggedSet>(
            sortBy: [SortDescriptor(\LoggedSet.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        descriptor.predicate = #Predicate { set in
            set.exercise?.id == exerciseID
        }
        guard let sets = try? context.fetch(descriptor) else { return [] }
        if let sessionID = session?.id {
            return sets.filter { $0.session?.id != sessionID }
        }
        return sets
    }
}
