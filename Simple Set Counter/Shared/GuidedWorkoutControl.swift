//
//  GuidedWorkoutControl.swift
//  Shared
//

import Foundation

enum GuidedWorkoutIntentAction: String, Codable {
    case next
    case skip
    case duplicate
}

/// Bridge used by Live Activity intents. The host app assigns `perform` at launch so
/// LiveActivityIntent can run against the app process.
enum GuidedWorkoutControl {
    static var perform: ((GuidedWorkoutIntentAction) async -> Void)?
}

enum GuidedWorkoutSharedStore {
    static let suiteName = "group.bhution.Simple-Set-Counter"
    private static let mirrorKey = "guidedWorkoutMirror"
    private static let pendingActionKey = "pendingGuidedAction"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func saveMirror(_ mirror: GuidedWorkoutMirror) {
        guard let data = try? JSONEncoder().encode(mirror) else { return }
        defaults.set(data, forKey: mirrorKey)
    }

    static func loadMirror() -> GuidedWorkoutMirror? {
        guard let data = defaults.data(forKey: mirrorKey) else { return nil }
        return try? JSONDecoder().decode(GuidedWorkoutMirror.self, from: data)
    }

    static func clearMirror() {
        defaults.removeObject(forKey: mirrorKey)
        defaults.removeObject(forKey: pendingActionKey)
    }

    static func setPendingAction(_ action: GuidedWorkoutIntentAction) {
        defaults.set(action.rawValue, forKey: pendingActionKey)
    }

    static func consumePendingAction() -> GuidedWorkoutIntentAction? {
        guard let raw = defaults.string(forKey: pendingActionKey),
              let action = GuidedWorkoutIntentAction(rawValue: raw) else { return nil }
        defaults.removeObject(forKey: pendingActionKey)
        return action
    }
}

struct GuidedWorkoutMirror: Codable, Hashable {
    var sessionID: String
    var exerciseName: String
    var exerciseID: String
    var tagName: String
    var tagID: String
    var setCount: Int
    var queueIDs: [String]
    var queueNames: [String: String]
    var nextExerciseName: String?
    var canAdvance: Bool
    var restEndsAt: Date?
    var startedAt: Date
    var hasLoggedSets: Bool
    var lastWeight: Double?
    var lastReps: Int?
    var lastIsBodyweight: Bool?

    var contentState: WorkoutLiveActivityAttributes.ContentState {
        .init(
            exerciseName: exerciseName,
            tagName: tagName,
            setCount: setCount,
            nextExerciseName: nextExerciseName,
            canAdvance: canAdvance,
            restEndsAt: restEndsAt,
            startedAt: startedAt,
            hasLoggedSets: hasLoggedSets
        )
    }

    mutating func advanceToNext() {
        guard !queueIDs.isEmpty, let index = queueIDs.firstIndex(of: exerciseID) else { return }
        let nextIndex = (index + 1) % queueIDs.count
        applyCurrent(queueIDs[nextIndex])
    }

    mutating func skipToBack() {
        guard queueIDs.count > 1, let index = queueIDs.firstIndex(of: exerciseID) else { return }
        var queue = queueIDs
        let current = queue.remove(at: index)
        queue.append(current)
        queueIDs = queue
        let nextID = index < queue.count ? queue[index] : queue.first
        if let nextID {
            applyCurrent(nextID)
        }
    }

    private mutating func applyCurrent(_ id: String) {
        exerciseID = id
        exerciseName = queueNames[id] ?? "Exercise"
        setCount = 0
        hasLoggedSets = false
        lastWeight = nil
        lastReps = nil
        lastIsBodyweight = nil
        restEndsAt = nil
        canAdvance = queueIDs.count > 1
        if let index = queueIDs.firstIndex(of: id) {
            let nextIndex = (index + 1) % queueIDs.count
            let nextID = queueIDs[nextIndex]
            nextExerciseName = nextID == id ? nil : queueNames[nextID]
        } else {
            nextExerciseName = nil
        }
    }
}
