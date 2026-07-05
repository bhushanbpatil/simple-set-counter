//
//  ModelContainerSetup.swift
//  Simple Set Counter
//

import SwiftData
import Foundation

enum ModelContainerSetup {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            ExerciseTag.self,
            TaggedExercise.self,
            WorkoutSession.self,
            LoggedSet.self
        ])
        let configuration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Existing installs may fail lightweight migration once after schema changes.
            // Remove the incompatible store so the app can launch with a fresh database.
            removeStoreFiles(for: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    private static func removeStoreFiles(for storeURL: URL) {
        let fm = FileManager.default
        let base = storeURL.deletingPathExtension()
        let candidates = [
            storeURL,
            URL(fileURLWithPath: base.path + ".store"),
            URL(fileURLWithPath: base.path + ".store-wal"),
            URL(fileURLWithPath: base.path + ".store-shm")
        ]
        for url in candidates where fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
    }
}
