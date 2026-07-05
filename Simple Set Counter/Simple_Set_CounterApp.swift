//
//  Simple_Set_CounterApp.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

@main
struct Simple_Set_CounterApp: App {
    private let modelContainer = ModelContainerSetup.makeContainer()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
    }
}
