//
//  ExerciseCatalog.swift
//  Simple Set Counter
//

import Foundation
import SwiftData

enum ExerciseCatalog {
    static let defaults: [(name: String, category: String)] = [
        ("Bench Press", "Push"),
        ("Overhead Press", "Push"),
        ("Incline Dumbbell Press", "Push"),
        ("Dips", "Push"),
        ("Deadlift", "Pull"),
        ("Barbell Row", "Pull"),
        ("Pull-Up", "Pull"),
        ("Lat Pulldown", "Pull"),
        ("Squat", "Legs"),
        ("Front Squat", "Legs"),
        ("Romanian Deadlift", "Legs"),
        ("Leg Press", "Legs"),
        ("Lunge", "Legs"),
        ("Barbell Curl", "Arms"),
        ("Dumbbell Curl", "Arms"),
        ("Tricep Pushdown", "Arms"),
        ("Skull Crusher", "Arms"),
        ("Cable Crunch", "Core"),
        ("Plank", "Core"),
        ("Hip Thrust", "Legs"),
        ("Calf Raise", "Legs"),
        ("Face Pull", "Pull"),
        ("Lateral Raise", "Push"),
        ("Hammer Curl", "Arms")
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        var descriptor = FetchDescriptor<Exercise>()
        descriptor.fetchLimit = 1
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for (index, item) in defaults.enumerated() {
            context.insert(
                Exercise(
                    name: item.name,
                    category: item.category,
                    isCustom: false,
                    sortOrder: index
                )
            )
        }
        try? context.save()
    }

    @MainActor
    static func addCustom(name: String, category: String, context: ModelContext) -> Exercise? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var descriptor = FetchDescriptor<Exercise>()
        descriptor.predicate = #Predicate { $0.name == trimmed && !$0.isHidden }
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let exercise = Exercise(
            name: trimmed,
            category: category.isEmpty ? "Custom" : category,
            isCustom: true,
            sortOrder: 10_000
        )
        context.insert(exercise)
        try? context.save()
        return exercise
    }
}
