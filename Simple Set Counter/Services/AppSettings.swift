//
//  AppSettings.swift
//  Simple Set Counter
//

import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case pounds
    case kilograms

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pounds: return "lb"
        case .kilograms: return "kg"
        }
    }

    var title: String {
        switch self {
        case .pounds: return "Pounds (lb)"
        case .kilograms: return "Kilograms (kg)"
        }
    }
}

enum AppSettings {
    private static let unitKey = "weightUnit"
    private static let stepKey = "weightStep"
    private static let collapsedTagsKey = "collapsedTagIDs"
    private static let smartIncreaseKey = "smartIncreaseEnabled"
    private static let smartIncreaseWeightsKey = "smartIncreaseWeights"
    private static let smartIncreaseRepsKey = "smartIncreaseReps"
    private static let lastUsedTagKey = "lastUsedTagID"

    /// A set must exceed this many reps to qualify for smart increase.
    static let smartIncreaseRepThreshold = 12

    static var weightUnit: WeightUnit {
        get {
            guard let raw = UserDefaults.standard.string(forKey: unitKey),
                  let unit = WeightUnit(rawValue: raw) else { return .pounds }
            return unit
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: unitKey) }
    }

    static var weightStep: Double {
        get {
            let value = UserDefaults.standard.double(forKey: stepKey)
            return value > 0 ? value : 5
        }
        set { UserDefaults.standard.set(newValue, forKey: stepKey) }
    }

    static func isTagCollapsed(_ id: UUID) -> Bool {
        collapsedTagIDs.contains(id.uuidString)
    }

    static func setTagCollapsed(_ id: UUID, collapsed: Bool) {
        var ids = collapsedTagIDs
        if collapsed {
            ids.insert(id.uuidString)
        } else {
            ids.remove(id.uuidString)
        }
        collapsedTagIDs = ids
    }

    private static var collapsedTagIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: collapsedTagsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: collapsedTagsKey)
        }
    }

    static func formatWeight(_ value: Double, bodyweight: Bool = false) -> String {
        if bodyweight { return "BW" }
        let formatted = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        return "\(formatted) \(weightUnit.label)"
    }

    static var lastUsedTagID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: lastUsedTagKey) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: lastUsedTagKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastUsedTagKey)
            }
        }
    }

    static var smartIncreaseEnabled: Bool {
        get { UserDefaults.standard.object(forKey: smartIncreaseKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: smartIncreaseKey) }
    }

    /// Five pounds, or 2.5 kg when using metric.
    static var smartIncreaseIncrement: Double {
        weightUnit == .kilograms ? 2.5 : 5
    }

    struct SmartIncreaseSuggestion {
        let weight: Double
        let reps: Int
    }

    static func smartIncreaseSuggestion(for exerciseID: UUID) -> SmartIncreaseSuggestion? {
        let weights = UserDefaults.standard.dictionary(forKey: smartIncreaseWeightsKey) as? [String: Double]
        let reps = UserDefaults.standard.dictionary(forKey: smartIncreaseRepsKey) as? [String: Int]
        let key = exerciseID.uuidString
        guard let weight = weights?[key], let rep = reps?[key] else { return nil }
        return SmartIncreaseSuggestion(weight: weight, reps: rep)
    }

    static func setSmartIncreaseSuggestion(for exerciseID: UUID, weight: Double, reps: Int) {
        let key = exerciseID.uuidString
        var weights = UserDefaults.standard.dictionary(forKey: smartIncreaseWeightsKey) as? [String: Double] ?? [:]
        var repsMap = UserDefaults.standard.dictionary(forKey: smartIncreaseRepsKey) as? [String: Int] ?? [:]
        weights[key] = weight
        repsMap[key] = reps
        UserDefaults.standard.set(weights, forKey: smartIncreaseWeightsKey)
        UserDefaults.standard.set(repsMap, forKey: smartIncreaseRepsKey)
    }

    static func applySmartIncrease(after session: WorkoutSession) {
        guard smartIncreaseEnabled else { return }

        let grouped = Dictionary(grouping: session.sortedSets) { $0.exercise?.id }
        for (exerciseID, sets) in grouped {
            guard let exerciseID else { continue }

            let qualifying = sets.filter { !$0.isBodyweight && $0.reps > smartIncreaseRepThreshold }
            guard let best = qualifying.max(by: { lhs, rhs in
                if lhs.weight != rhs.weight { return lhs.weight < rhs.weight }
                return lhs.reps < rhs.reps
            }) else { continue }

            setSmartIncreaseSuggestion(
                for: exerciseID,
                weight: best.weight + smartIncreaseIncrement,
                reps: best.reps
            )
        }
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
