//
//  HistoryCalendarView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct HistoryCalendarView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var sessions: [WorkoutSession]

    @State private var displayedMonth = Date()
    @State private var selectedDay: Date?
    @State private var selectedSessions: [WorkoutSession] = []

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    private var sessionsByDay: [Date: [WorkoutSession]] {
        Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }
    }

    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }
        return days
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "calendar",
                        description: Text("Days you train will show up highlighted here.")
                    )
                    .foregroundStyle(.white)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            monthHeader
                            weekdayHeader
                            dayGrid
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("History")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: Binding(
                get: { selectedDay.map { DaySelection(date: $0) } },
                set: { selectedDay = $0?.date }
            )) { selection in
                DayWorkoutsSheet(date: selection.date, sessions: selectedSessions)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.title3.bold())

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
        }
        .foregroundStyle(.white)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let start = calendar.startOfDay(for: day)
        let daySessions = sessionsByDay[start] ?? []
        let hasWorkout = !daySessions.isEmpty
        let isToday = calendar.isDateInToday(day)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false

        return Button {
            guard hasWorkout else { return }
            selectedDay = start
            selectedSessions = daySessions.sorted { $0.startedAt > $1.startedAt }
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(hasWorkout ? .bold : .regular))
                    .foregroundStyle(hasWorkout ? .white : AppTheme.secondaryText)

                Circle()
                    .fill(hasWorkout ? AppTheme.accent : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor(hasWorkout: hasWorkout, isToday: isToday, isSelected: isSelected))
            }
        }
        .buttonStyle(.plain)
        .disabled(!hasWorkout)
    }

    private func backgroundColor(hasWorkout: Bool, isToday: Bool, isSelected: Bool) -> Color {
        if isSelected { return AppTheme.accent.opacity(0.35) }
        if hasWorkout { return AppTheme.accent.opacity(0.18) }
        if isToday { return AppTheme.card }
        return .clear
    }

    private func shiftMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

private struct DaySelection: Identifiable {
    let date: Date
    var id: Date { date }
}

private struct DayWorkoutsSheet: View {
    let date: Date
    let sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    ForEach(sessions) { session in
                        NavigationLink {
                            WorkoutDetailView(session: session)
                        } label: {
                            DayWorkoutRow(session: session)
                        }
                        .listRowBackground(AppTheme.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(Text(date, format: .dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct DayWorkoutRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if session.isQuickLogSession && session.sets.isEmpty {
                Text("Quick log")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
            } else {
                Text("\(session.sets.count) sets")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
            }

            Text(session.loggedExercises.map(\.name).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(session.startedAt, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryCalendarView()
        .modelContainer(for: [Exercise.self, ExerciseTag.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
