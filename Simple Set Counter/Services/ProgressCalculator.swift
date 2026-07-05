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
}

struct ProgressSummary {
    let points: [ProgressDataPoint]
    let deltaWeight: Double?
    let workoutDays: Int
    let latestMax: Double?
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
            let maxWeight = daySets.filter { !$0.isBodyweight }.map(\.weight).max() ?? 0
            let reps = daySets.map(\.reps).reduce(0, +)
            return ProgressDataPoint(date: day, maxWeight: maxWeight, totalReps: reps)
        }

        let weightPoints = points.filter { $0.maxWeight > 0 }
        let delta: Double?
        if weightPoints.count >= 2, let first = weightPoints.first?.maxWeight, let last = weightPoints.last?.maxWeight {
            delta = last - first
        } else {
            delta = nil
        }

        let workoutDays = Set(filtered.compactMap { $0.session?.id }).count
        let latestMax = weightPoints.last?.maxWeight

        return ProgressSummary(
            points: points,
            deltaWeight: delta,
            workoutDays: workoutDays,
            latestMax: latestMax
        )
    }

    static func lastSet(for exercise: Exercise, before session: WorkoutSession?, in sets: [LoggedSet]) -> LoggedSet? {
        sets
            .filter { $0.exercise?.id == exercise.id && $0.session?.id != session?.id }
            .sorted { $0.completedAt > $1.completedAt }
            .first
    }

    static func fetchLastSet(for exercise: Exercise, before session: WorkoutSession?, context: ModelContext) -> LoggedSet? {
        let exerciseID = exercise.id
        var descriptor = FetchDescriptor<LoggedSet>(
            sortBy: [SortDescriptor(\LoggedSet.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 25
        descriptor.predicate = #Predicate { set in
            set.exercise?.id == exerciseID
        }
        guard let sets = try? context.fetch(descriptor) else { return nil }
        if let sessionID = session?.id {
            return sets.first { $0.session?.id != sessionID }
        }
        return sets.first
    }
}
