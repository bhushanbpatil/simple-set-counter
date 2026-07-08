//
//  Simple_Set_CounterApp.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

@main
struct Simple_Set_CounterApp: App {
    private let modelContainer = ModelContainerSetup.shared

    init() {
        GuidedWorkoutIntentHandler.install()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    NotificationCenter.default.post(name: .setCounterDeepLink, object: url)
                }
        }
        .modelContainer(modelContainer)
    }
}

extension Notification.Name {
    static let setCounterDeepLink = Notification.Name("setCounterDeepLink")
}
