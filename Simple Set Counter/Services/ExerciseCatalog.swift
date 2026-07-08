//
//  ExerciseCatalog.swift
//  Simple Set Counter
//

import Foundation
import SwiftData

enum ExerciseCatalog {
    static let defaults: [(name: String, category: String)] = [
        // Push
        ("Bench Press", "Push"),
        ("Incline Bench Press", "Push"),
        ("Decline Bench Press", "Push"),
        ("Dumbbell Bench Press", "Push"),
        ("Incline Dumbbell Press", "Push"),
        ("Overhead Press", "Push"),
        ("Push Press", "Push"),
        ("Arnold Press", "Push"),
        ("Landmine Press", "Push"),
        ("Dips", "Push"),
        ("Push-Up", "Push"),
        ("Chest Fly", "Push"),
        ("Cable Fly", "Push"),
        ("Pec Deck", "Push"),
        ("Lateral Raise", "Push"),
        ("Front Raise", "Push"),
        ("Reverse Fly", "Push"),
        ("Close-Grip Bench Press", "Push"),
        ("Smith Machine Bench Press", "Push"),

        // Pull
        ("Deadlift", "Pull"),
        ("Sumo Deadlift", "Pull"),
        ("Rack Pull", "Pull"),
        ("Barbell Row", "Pull"),
        ("Pendlay Row", "Pull"),
        ("T-Bar Row", "Pull"),
        ("Dumbbell Row", "Pull"),
        ("Chest-Supported Row", "Pull"),
        ("Seated Cable Row", "Pull"),
        ("Meadows Row", "Pull"),
        ("Pull-Up", "Pull"),
        ("Chin-Up", "Pull"),
        ("Lat Pulldown", "Pull"),
        ("Straight-Arm Pulldown", "Pull"),
        ("Inverted Row", "Pull"),
        ("Face Pull", "Pull"),
        ("Shrug", "Pull"),
        ("Good Morning", "Pull"),
        ("Cable Pullover", "Pull"),

        // Legs
        ("Squat", "Legs"),
        ("Front Squat", "Legs"),
        ("Box Squat", "Legs"),
        ("Goblet Squat", "Legs"),
        ("Hack Squat", "Legs"),
        ("Smith Machine Squat", "Legs"),
        ("Leg Press", "Legs"),
        ("Romanian Deadlift", "Legs"),
        ("Lunge", "Legs"),
        ("Walking Lunge", "Legs"),
        ("Bulgarian Split Squat", "Legs"),
        ("Step-Up", "Legs"),
        ("Leg Extension", "Legs"),
        ("Leg Curl", "Legs"),
        ("Seated Leg Curl", "Legs"),
        ("Hip Thrust", "Legs"),
        ("Glute Bridge", "Legs"),
        ("Calf Raise", "Legs"),
        ("Seated Calf Raise", "Legs"),
        ("Hip Abduction", "Legs"),
        ("Hip Adduction", "Legs"),

        // Arms
        ("Barbell Curl", "Arms"),
        ("EZ Bar Curl", "Arms"),
        ("Dumbbell Curl", "Arms"),
        ("Hammer Curl", "Arms"),
        ("Preacher Curl", "Arms"),
        ("Concentration Curl", "Arms"),
        ("Incline Dumbbell Curl", "Arms"),
        ("Cable Curl", "Arms"),
        ("Reverse Curl", "Arms"),
        ("Tricep Pushdown", "Arms"),
        ("Rope Pushdown", "Arms"),
        ("Skull Crusher", "Arms"),
        ("Overhead Tricep Extension", "Arms"),
        ("Dumbbell Kickback", "Arms"),
        ("Wrist Curl", "Arms"),

        // Core
        ("Plank", "Core"),
        ("Side Plank", "Core"),
        ("Cable Crunch", "Core"),
        ("Crunch", "Core"),
        ("Hanging Leg Raise", "Core"),
        ("Ab Wheel Rollout", "Core"),
        ("Russian Twist", "Core"),
        ("Cable Woodchop", "Core"),
        ("Dead Bug", "Core"),
        ("Pallof Press", "Core"),
        ("Mountain Climber", "Core"),

        // Olympic / compound
        ("Power Clean", "Pull"),
        ("Clean and Jerk", "Pull"),
        ("Snatch", "Pull")
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingNames = Set(existing.map(\.name))
        var nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        var added = false

        for item in defaults where !existingNames.contains(item.name) {
            context.insert(
                Exercise(
                    name: item.name,
                    category: item.category,
                    isCustom: false,
                    sortOrder: nextOrder
                )
            )
            nextOrder += 1
            added = true
        }

        if added {
            try? context.save()
        }
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
