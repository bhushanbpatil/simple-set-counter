//
//  WorkoutFlow.swift
//  Simple Set Counter
//

import Foundation
import SwiftData

enum WorkoutFlow {
    // MARK: - Session flow storage (optional strings for lightweight migration)

    static func activeTagID(in session: WorkoutSession) -> UUID? {
        uuid(from: session.flowTagID)
    }

    static func currentExerciseID(in session: WorkoutSession) -> UUID? {
        uuid(from: session.currentExerciseIDString)
    }

    static func queueIDs(in session: WorkoutSession) -> [UUID] {
        guard let raw = session.queueOrder, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }

    static func setQueueIDs(_ ids: [UUID], in session: WorkoutSession) {
        session.queueOrder = ids.map(\.uuidString).joined(separator: ",")
    }

    static func clearFlow(in session: WorkoutSession) {
        session.flowTagID = nil
        session.currentExerciseIDString = nil
        session.queueOrder = nil
    }

    // MARK: - Display ordering

    static func tagsForToday(_ tags: [ExerciseTag], session: WorkoutSession?) -> [ExerciseTag] {
        let sorted = RoutineCatalog.sortedTags(tags)
        guard let session, let activeID = activeTagID(in: session) else { return sorted }
        guard let active = sorted.first(where: { $0.id == activeID }) else { return sorted }
        return [active] + sorted.filter { $0.id != activeID }
    }

    static func exercises(in tag: ExerciseTag, session: WorkoutSession?) -> [Exercise] {
        let routine = RoutineCatalog.orderedExercises(in: tag)
        guard let session, activeTagID(in: session) == tag.id else { return routine }

        let queue = queueIDs(in: session)
        guard !queue.isEmpty else { return routine }

        let byID = Dictionary(uniqueKeysWithValues: routine.map { ($0.id, $0) })
        var ordered = queue.compactMap { byID[$0] }
        for exercise in routine where !queue.contains(exercise.id) {
            ordered.append(exercise)
        }
        return ordered
    }

    static func visibleExercises(in tag: ExerciseTag, session: WorkoutSession?) -> [Exercise] {
        let all = exercises(in: tag, session: session)
        guard let session, let currentID = currentExerciseID(in: session), activeTagID(in: session) == tag.id else {
            return all
        }
        return all.filter { $0.id != currentID }
    }

    static func currentExercise(in session: WorkoutSession?, tags: [ExerciseTag]) -> Exercise? {
        guard let session, let id = currentExerciseID(in: session) else { return nil }
        for tag in tags {
            if let match = RoutineCatalog.orderedExercises(in: tag).first(where: { $0.id == id }) {
                return match
            }
        }
        return nil
    }

    static func currentTag(in session: WorkoutSession?, tags: [ExerciseTag]) -> ExerciseTag? {
        guard let session, let id = activeTagID(in: session) else { return nil }
        return tags.first { $0.id == id }
    }

    static func nextExerciseName(in session: WorkoutSession?, tags: [ExerciseTag]) -> String? {
        guard let session, let tag = currentTag(in: session, tags: tags) else { return nil }
        let ordered = queueIDs(in: session)
        guard !ordered.isEmpty else { return nil }
        guard let currentID = currentExerciseID(in: session),
              let index = ordered.firstIndex(of: currentID) else {
            return exerciseName(for: ordered.first, in: tag)
        }
        let nextIndex = (index + 1) % ordered.count
        return exerciseName(for: ordered[nextIndex], in: tag)
    }

    static func sets(for exercise: Exercise, in session: WorkoutSession) -> [LoggedSet] {
        session.sortedSets.filter { $0.exercise?.id == exercise.id }
    }

    private static func exerciseName(for id: UUID?, in tag: ExerciseTag) -> String? {
        guard let id else { return nil }
        return RoutineCatalog.orderedExercises(in: tag).first { $0.id == id }?.name
    }

    // MARK: - Actions

    /// Select an exercise without changing queue order (e.g. logging another set on the current one).
    @MainActor
    static func setCurrentExercise(_ exercise: Exercise, in tag: ExerciseTag, session: WorkoutSession, context: ModelContext) {
        ensureQueue(for: tag, in: session)
        session.flowTagID = tag.id.uuidString
        session.currentExerciseIDString = exercise.id.uuidString
        AppSettings.lastUsedTagID = tag.id
        try? context.save()
    }

    /// Tap an exercise to work on it — moves it to the front of the queue.
    @MainActor
    static func startExercise(_ exercise: Exercise, in tag: ExerciseTag, session: WorkoutSession, context: ModelContext) {
        var queue = ensureQueue(for: tag, in: session)
        queue.removeAll { $0 == exercise.id }
        queue.insert(exercise.id, at: 0)
        setQueueIDs(queue, in: session)
        session.flowTagID = tag.id.uuidString
        session.currentExerciseIDString = exercise.id.uuidString
        AppSettings.lastUsedTagID = tag.id
        try? context.save()
    }

    /// Round-robin: advance to the next exercise in queue order (wraps around).
    @MainActor
    static func advanceToNext(in session: WorkoutSession, tags: [ExerciseTag], context: ModelContext) {
        guard let tag = currentTag(in: session, tags: tags) else { return }
        let ordered = queueIDs(in: session)
        guard !ordered.isEmpty else { return }
        guard let currentID = currentExerciseID(in: session),
              let index = ordered.firstIndex(of: currentID) else {
            session.currentExerciseIDString = ordered.first?.uuidString
            try? context.save()
            return
        }
        let nextIndex = (index + 1) % ordered.count
        session.currentExerciseIDString = ordered[nextIndex].uuidString
        try? context.save()
    }

    @MainActor
    static func skipCurrentToBack(in session: WorkoutSession, context: ModelContext) {
        guard let currentID = currentExerciseID(in: session) else { return }
        var queue = queueIDs(in: session)
        guard queue.count > 1, let index = queue.firstIndex(of: currentID) else { return }

        queue.remove(at: index)
        queue.append(currentID)

        let nextID = index < queue.count ? queue[index] : queue.first
        setQueueIDs(queue, in: session)
        session.currentExerciseIDString = nextID?.uuidString
        try? context.save()
    }

    @discardableResult
    private static func ensureQueue(for tag: ExerciseTag, in session: WorkoutSession) -> [UUID] {
        let routineIDs = RoutineCatalog.orderedExercises(in: tag).map(\.id)
        var queue = queueIDs(in: session)

        if activeTagID(in: session) != tag.id || queue.isEmpty {
            queue = routineIDs
            setQueueIDs(queue, in: session)
            return queue
        }

        for id in routineIDs where !queue.contains(id) {
            queue.append(id)
        }
        queue.removeAll { !routineIDs.contains($0) }
        setQueueIDs(queue, in: session)
        return queue
    }

    @MainActor
    static func tag(containing exercise: Exercise, in tags: [ExerciseTag]) -> ExerciseTag? {
        for tag in RoutineCatalog.sortedTags(tags) {
            if tag.memberships.contains(where: { $0.exercise?.id == exercise.id }) {
                return tag
            }
        }
        return nil
    }

    private static func uuid(from string: String?) -> UUID? {
        guard let string else { return nil }
        return UUID(uuidString: string)
    }
}
