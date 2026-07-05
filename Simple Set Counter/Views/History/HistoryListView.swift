//
//  HistoryListView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "calendar",
                        description: Text("Finished workouts show up here.")
                    )
                    .foregroundStyle(.white)
                } else {
                    List(sessions) { session in
                        NavigationLink {
                            WorkoutDetailView(session: session)
                        } label: {
                            HistoryRow(session: session)
                        }
                        .listRowBackground(AppTheme.card)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct HistoryRow: View {
    let session: WorkoutSession

    private var exerciseCount: Int {
        Set(session.sets.compactMap { $0.exercise?.id }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.startedAt, format: .dateTime.weekday(.wide).month().day().year())
                .font(.headline)
                .foregroundStyle(.white)
            Text("\(exerciseCount) exercises · \(session.sets.count) sets")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryListView()
        .modelContainer(for: [Exercise.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
