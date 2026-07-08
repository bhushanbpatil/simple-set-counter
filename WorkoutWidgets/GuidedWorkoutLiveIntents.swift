//
//  GuidedWorkoutLiveIntents.swift
//  Shared
//

import AppIntents
import Foundation

struct NextGuidedExerciseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next exercise"
    static var description = IntentDescription("Moves to the next exercise in your guided workout queue.")

    init() {}

    func perform() async throws -> some IntentResult {
        if let perform = GuidedWorkoutControl.perform {
            await perform(.next)
        }
        return .result()
    }
}

struct SkipGuidedExerciseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip to back"
    static var description = IntentDescription("Sends the current exercise to the back of the queue.")

    init() {}

    func perform() async throws -> some IntentResult {
        if let perform = GuidedWorkoutControl.perform {
            await perform(.skip)
        }
        return .result()
    }
}

struct DuplicateLastSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Duplicate last set"
    static var description = IntentDescription("Logs another set matching the last set on the current exercise.")

    init() {}

    func perform() async throws -> some IntentResult {
        if let perform = GuidedWorkoutControl.perform {
            await perform(.duplicate)
        }
        return .result()
    }
}
