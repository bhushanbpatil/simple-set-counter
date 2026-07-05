//
//  RoutineCatalog.swift
//  Simple Set Counter
//

import Foundation
import SwiftData

enum RoutineCatalog {
    static let generalTagName = "General"

    @MainActor
    @discardableResult
    static func ensureGeneralTag(context: ModelContext) -> ExerciseTag {
        var descriptor = FetchDescriptor<ExerciseTag>()
        descriptor.predicate = #Predicate { $0.name == generalTagName }
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let tag = ExerciseTag(name: generalTagName, sortOrder: 0)
        context.insert(tag)
        try? context.save()
        return tag
    }

    @MainActor
    static func sortedTags(_ tags: [ExerciseTag]) -> [ExerciseTag] {
        tags.sorted { lhs, rhs in
            if lhs.name == generalTagName { return true }
            if rhs.name == generalTagName { return false }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name < rhs.name
        }
    }

    @MainActor
    static func addExercise(_ exercise: Exercise, to tag: ExerciseTag, context: ModelContext) {
        if tag.memberships.contains(where: { $0.exercise?.id == exercise.id }) { return }

        let exerciseID = exercise.id
        var descriptor = FetchDescriptor<TaggedExercise>()
        descriptor.predicate = #Predicate { $0.exercise?.id == exerciseID }
        if let existing = try? context.fetch(descriptor) {
            for membership in existing {
                context.delete(membership)
            }
        }

        let membership = TaggedExercise(sortOrder: tag.memberships.count, exercise: exercise, tag: tag)
        context.insert(membership)
        tag.memberships.append(membership)
        try? context.save()
    }

    @MainActor
    static func addCustomExercise(name: String, to tag: ExerciseTag, context: ModelContext) -> Exercise? {
        guard let exercise = ExerciseCatalog.addCustom(name: name, category: "Custom", context: context) else {
            return nil
        }
        addExercise(exercise, to: tag, context: context)
        return exercise
    }

    @MainActor
    static func removeExercise(_ exercise: Exercise, from tag: ExerciseTag, context: ModelContext) {
        if let membership = tag.memberships.first(where: { $0.exercise?.id == exercise.id }) {
            context.delete(membership)
            try? context.save()
        }
    }

    @MainActor
    static func removeFromRoutine(_ exercise: Exercise, context: ModelContext) {
        let exerciseID = exercise.id
        var descriptor = FetchDescriptor<TaggedExercise>()
        descriptor.predicate = #Predicate { $0.exercise?.id == exerciseID }
        if let memberships = try? context.fetch(descriptor) {
            for membership in memberships {
                context.delete(membership)
            }
        }
        try? context.save()
    }

    @MainActor
    static func hideExercise(_ exercise: Exercise, context: ModelContext) {
        removeFromRoutine(exercise, context: context)
        exercise.isHidden = true
        try? context.save()
    }

    @MainActor
    static func deleteTag(_ tag: ExerciseTag, context: ModelContext) {
        guard tag.name != generalTagName else { return }
        let general = ensureGeneralTag(context: context)
        for membership in tag.memberships {
            if let exercise = membership.exercise {
                addExercise(exercise, to: general, context: context)
            }
            context.delete(membership)
        }
        context.delete(tag)
        try? context.save()
    }

    @MainActor
    static func moveExercise(_ exercise: Exercise, from source: ExerciseTag, to destination: ExerciseTag, context: ModelContext) {
        guard source.id != destination.id else { return }
        removeExercise(exercise, from: source, context: context)
        addExercise(exercise, to: destination, context: context)
    }

    @MainActor
    static func finishStaleSessions(_ sessions: [WorkoutSession], context: ModelContext) {
        let calendar = Calendar.current
        for session in sessions where session.isActive {
            if !calendar.isDateInToday(session.startedAt) {
                session.endedAt = session.startedAt
            }
        }
        try? context.save()
    }
}
