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
}
