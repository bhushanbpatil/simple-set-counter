//
//  WorkoutLiveActivityAttributes.swift
//  Shared
//

import ActivityKit
import Foundation

struct WorkoutLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var tagName: String
        var setCount: Int
        var nextExerciseName: String?
        var canAdvance: Bool
        var restEndsAt: Date?
        var startedAt: Date
        var hasLoggedSets: Bool
    }

    var sessionID: String
}
