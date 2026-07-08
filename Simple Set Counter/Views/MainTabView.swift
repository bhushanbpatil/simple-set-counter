//
//  MainTabView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.accentColorKey) private var accentColorRaw = AccentColorOption.lime.rawValue

    var body: some View {
        OnboardingView {
            TabView {
                TodayView()
                    .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }

                HistoryCalendarView()
                    .tabItem { Label("History", systemImage: "calendar") }

                ProgressTabView()
                    .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

                ExerciseLibraryView()
                    .tabItem { Label("Exercises", systemImage: "list.bullet") }
            }
            .tint((AccentColorOption(rawValue: accentColorRaw) ?? .lime).accent)
        }
        .onAppear {
            ExerciseCatalog.seedIfNeeded(context: modelContext)
            RoutineCatalog.ensureGeneralTag(context: modelContext)
            RoutineCatalog.seedStarterRoutineIfNeeded(context: modelContext)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Exercise.self, ExerciseTag.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
