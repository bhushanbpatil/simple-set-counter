//
//  GuidedWorkoutIntentHandler.swift
//  Simple Set Counter
//

import Foundation
import SwiftData

@MainActor
enum GuidedWorkoutIntentHandler {
    static func install() {
        GuidedWorkoutControl.perform = { action in
            await handle(action)
        }
    }

    static func handle(_ action: GuidedWorkoutIntentAction) async {
        GuidedWorkoutSharedStore.setPendingAction(action)

        let container = ModelContainerSetup.shared
        let context = ModelContext(container)

        var sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        sessionDescriptor.fetchLimit = 1

        let tagDescriptor = FetchDescriptor<ExerciseTag>(sortBy: [SortDescriptor(\.sortOrder)])

        guard let session = try? context.fetch(sessionDescriptor).first,
              let tags = try? context.fetch(tagDescriptor) else {
            NotificationCenter.default.post(name: .guidedWorkoutIntentDidRun, object: action.rawValue)
            return
        }

        switch action {
        case .next:
            WorkoutFlow.advanceToNext(in: session, tags: tags, context: context)
        case .skip:
            WorkoutFlow.skipCurrentToBack(in: session, context: context)
        case .duplicate:
            duplicateLastSet(session: session, tags: tags, context: context)
        }

        if let exercise = WorkoutFlow.currentExercise(in: session, tags: tags) {
            let restEndsAt: Date?
            if action == .duplicate, AppSettings.restTimerEnabled {
                restEndsAt = Date().addingTimeInterval(TimeInterval(AppSettings.restTimerDuration))
            } else {
                restEndsAt = nil
            }
            WorkoutLiveActivityManager.sync(
                session: session,
                tags: tags,
                restEndsAt: restEndsAt,
                guidedEnabled: AppSettings.guidedWorkoutFlowEnabled
            )
        }

        NotificationCenter.default.post(name: .guidedWorkoutIntentDidRun, object: action.rawValue)
    }

    private static func duplicateLastSet(session: WorkoutSession, tags: [ExerciseTag], context: ModelContext) {
        guard let exercise = WorkoutFlow.currentExercise(in: session, tags: tags) else { return }
        let sets = WorkoutFlow.sets(for: exercise, in: session)
        guard let last = sets.last else { return }

        session.markStartedIfFirstSet()
        let sortIndex = sets.count
        let copy = LoggedSet(
            weight: last.weight,
            reps: last.reps,
            isBodyweight: last.isBodyweight,
            sortIndex: sortIndex,
            exercise: exercise,
            session: session
        )
        context.insert(copy)
        session.sets.append(copy)
        try? context.save()
    }
}

extension Notification.Name {
    static let guidedWorkoutIntentDidRun = Notification.Name("guidedWorkoutIntentDidRun")
}
