//
//  MainTabView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.accentColorKey) private var accentColorRaw = AccentColorOption.orange.rawValue

    var body: some View {
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
        .tint((AccentColorOption(rawValue: accentColorRaw) ?? .orange).accent)
        .onAppear {
            ExerciseCatalog.seedIfNeeded(context: modelContext)
            RoutineCatalog.ensureGeneralTag(context: modelContext)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Exercise.self, ExerciseTag.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
