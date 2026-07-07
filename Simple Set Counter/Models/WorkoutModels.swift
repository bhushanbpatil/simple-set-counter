//
//  WorkoutModels.swift
//  Simple Set Counter
//

import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var isCustom: Bool
    var isHidden: Bool
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        isCustom: Bool = false,
        isHidden: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isCustom = isCustom
        self.isHidden = isHidden
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

@Model
final class ExerciseTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TaggedExercise.tag)
    var memberships: [TaggedExercise]

    init(id: UUID = UUID(), name: String, sortOrder: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.memberships = []
    }

    var visibleExercises: [Exercise] {
        memberships
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return (lhs.exercise?.name ?? "") < (rhs.exercise?.name ?? "")
            }
            .compactMap(\.exercise)
            .filter { !$0.isHidden }
    }
}

@Model
final class TaggedExercise {
    var sortOrder: Int

    var exercise: Exercise?
    var tag: ExerciseTag?

    init(sortOrder: Int = 0, exercise: Exercise? = nil, tag: ExerciseTag? = nil) {
        self.sortOrder = sortOrder
        self.exercise = exercise
        self.tag = tag
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var note: String?
    /// Optional so existing saved workouts migrate without a default-value error.
    var isQuickLog: Bool?
    /// Active tag for today's exercise queue (UUID string).
    var flowTagID: String?
    /// Currently highlighted exercise (UUID string).
    var currentExerciseIDString: String?
    /// Comma-separated exercise UUIDs for today's queue order.
    var queueOrder: String?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var sets: [LoggedSet]

    @Relationship(deleteRule: .nullify)
    var checkedExercises: [Exercise]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        note: String? = nil,
        isQuickLog: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
        self.isQuickLog = isQuickLog
        self.sets = []
        self.checkedExercises = []
    }

    var isQuickLogSession: Bool { isQuickLog ?? false }

    var isActive: Bool { endedAt == nil }

    var sortedSets: [LoggedSet] {
        sets.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.completedAt < rhs.completedAt
        }
    }

    var loggedExercises: [Exercise] {
        if isQuickLogSession && sets.isEmpty {
            return checkedExercises.sorted { $0.name < $1.name }
        }
        let ids = Set(sets.compactMap { $0.exercise?.id })
        return Array(
            Dictionary(grouping: sets.compactMap(\.exercise), by: \.id)
                .compactMap(\.value.first)
                .filter { ids.contains($0.id) }
        ).sorted { $0.name < $1.name }
    }

    var exerciseCount: Int {
        if isQuickLogSession && sets.isEmpty { return checkedExercises.count }
        return Set(sets.compactMap { $0.exercise?.id }).count
    }

    /// Resets the workout clock when the first set of the session is logged.
    func markStartedIfFirstSet() {
        guard sets.isEmpty else { return }
        startedAt = .now
    }
}

@Model
final class LoggedSet {
    @Attribute(.unique) var id: UUID
    var weight: Double
    var reps: Int
    var isBodyweight: Bool
    var completedAt: Date
    var sortIndex: Int

    var exercise: Exercise?
    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        isBodyweight: Bool = false,
        completedAt: Date = .now,
        sortIndex: Int = 0,
        exercise: Exercise? = nil,
        session: WorkoutSession? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isBodyweight = isBodyweight
        self.completedAt = completedAt
        self.sortIndex = sortIndex
        self.exercise = exercise
        self.session = session
    }
}
