//
//  WorkoutLiveActivityManager.swift
//  Simple Set Counter
//

import ActivityKit
import Foundation
import SwiftData

@MainActor
enum WorkoutLiveActivityManager {
    static func sync(
        session: WorkoutSession?,
        tags: [ExerciseTag],
        restEndsAt: Date?,
        guidedEnabled: Bool
    ) {
        guard guidedEnabled,
              let session,
              let exercise = WorkoutFlow.currentExercise(in: session, tags: tags) else {
            endAll()
            GuidedWorkoutSharedStore.clearMirror()
            return
        }

        let mirror = makeMirror(session: session, exercise: exercise, tags: tags, restEndsAt: restEndsAt)
        GuidedWorkoutSharedStore.saveMirror(mirror)
        Task { await publish(mirror) }
    }

    static func endAll() {
        for activity in Activity<WorkoutLiveActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    static func updateFromMirror() {
        guard let mirror = GuidedWorkoutSharedStore.loadMirror() else {
            endAll()
            return
        }
        Task { await publish(mirror) }
    }

    private static func makeMirror(
        session: WorkoutSession,
        exercise: Exercise,
        tags: [ExerciseTag],
        restEndsAt: Date?
    ) -> GuidedWorkoutMirror {
        let tag = WorkoutFlow.currentTag(in: session, tags: tags)
        let queue = WorkoutFlow.queueIDs(in: session)
        let sets = WorkoutFlow.sets(for: exercise, in: session)
        let last = sets.last

        var names: [String: String] = [:]
        for tagItem in tags {
            for item in RoutineCatalog.orderedExercises(in: tagItem) {
                names[item.id.uuidString] = item.name
            }
        }

        return GuidedWorkoutMirror(
            sessionID: session.id.uuidString,
            exerciseName: exercise.name,
            exerciseID: exercise.id.uuidString,
            tagName: tag?.name ?? "",
            tagID: tag?.id.uuidString ?? "",
            setCount: sets.count,
            queueIDs: queue.map(\.uuidString),
            queueNames: names,
            nextExerciseName: WorkoutFlow.nextExerciseName(in: session, tags: tags),
            canAdvance: queue.count > 1,
            restEndsAt: restEndsAt,
            startedAt: session.startedAt,
            hasLoggedSets: !sets.isEmpty,
            lastWeight: last?.weight,
            lastReps: last?.reps,
            lastIsBodyweight: last?.isBodyweight
        )
    }

    private static func publish(_ mirror: GuidedWorkoutMirror) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutLiveActivityAttributes(sessionID: mirror.sessionID)
        let state = mirror.contentState
        let content = ActivityContent(state: state, staleDate: nil)

        if let existing = Activity<WorkoutLiveActivityAttributes>.activities.first(where: {
            $0.attributes.sessionID == mirror.sessionID
        }) {
            await existing.update(content)
            return
        }

        for activity in Activity<WorkoutLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            // Live Activities can be disabled by the user; ignore quietly.
        }
    }
}
