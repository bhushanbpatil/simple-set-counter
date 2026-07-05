//
//  ProgressTabView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \LoggedSet.completedAt) private var allSets: [LoggedSet]

    @State private var selectedExercise: Exercise?
    @State private var range: ProgressRange = .oneYear

    private var visibleExercises: [Exercise] {
        exercises.filter { !$0.isHidden }
    }

    private var exerciseSets: [LoggedSet] {
        guard let selectedExercise else { return [] }
        return allSets.filter { $0.exercise?.id == selectedExercise.id }
    }

    private var summary: ProgressSummary {
        ProgressCalculator.summary(for: exerciseSets, range: range)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if visibleExercises.isEmpty {
                    ContentUnavailableView("No exercises", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.white)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            exercisePicker
                            rangePicker
                            summaryCards
                            chartSection
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                if selectedExercise == nil {
                    selectedExercise = visibleExercises.first
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)
            Picker("Exercise", selection: $selectedExercise) {
                ForEach(visibleExercises) { exercise in
                    Text(exercise.name).tag(Optional(exercise))
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(ProgressRange.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var summaryCards: some View {
        let weightPoints = summary.points.filter { $0.maxWeight > 0 }

        if weightPoints.isEmpty {
            Text("Log weighted sets to see progress charts.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        } else {
            VStack(spacing: 12) {
                if let delta = summary.deltaWeight {
                    summaryCard(
                        title: "Change",
                        value: formattedDelta(delta),
                        subtitle: "over \(range.title)"
                    )
                }
                if let latest = summary.latestMax {
                    summaryCard(
                        title: "Best in range",
                        value: AppSettings.formatWeight(latest),
                        subtitle: "\(summary.workoutDays) workout days"
                    )
                }
            }
        }
    }

    private func summaryCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.title2.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var chartSection: some View {
        let weightPoints = summary.points.filter { $0.maxWeight > 0 }

        if weightPoints.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Max weight")
                    .font(.headline)

                Chart(weightPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.maxWeight)
                    )
                    .foregroundStyle(AppTheme.accent)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.maxWeight)
                    )
                    .foregroundStyle(AppTheme.accent)
                }
                .chartYAxisLabel(AppSettings.weightUnit.label)
                .frame(height: 220)
                .padding(12)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func formattedDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        let value = delta.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", delta)
            : String(format: "%.1f", delta)
        return "\(sign)\(value) \(AppSettings.weightUnit.label)"
    }
}

#Preview {
    ProgressTabView()
        .modelContainer(for: [Exercise.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
