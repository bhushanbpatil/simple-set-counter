//
//  ProgressTabView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Query(sort: \LoggedSet.completedAt) private var allSets: [LoggedSet]

    @State private var selectedExercise: Exercise?
    @State private var range: ProgressRange = .oneYear

    /// Only exercises the user has actually logged sets for, newest activity first.
    private var trackedExercises: [Exercise] {
        let byID = Dictionary(grouping: allSets.compactMap(\.exercise), by: \.id)
        let latestDate: [UUID: Date] = Dictionary(
            uniqueKeysWithValues: byID.compactMap { id, exercises in
                guard let exercise = exercises.first else { return nil }
                let latest = allSets
                    .filter { $0.exercise?.id == id }
                    .map(\.completedAt)
                    .max() ?? .distantPast
                return (exercise.id, latest)
            }
        )

        return byID.values
            .compactMap(\.first)
            .filter { !$0.isHidden }
            .sorted { lhs, rhs in
                let left = latestDate[lhs.id] ?? .distantPast
                let right = latestDate[rhs.id] ?? .distantPast
                if left != right { return left > right }
                return lhs.name < rhs.name
            }
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

                if trackedExercises.isEmpty {
                    ContentUnavailableView(
                        "No tracked exercises yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Log sets on Today and they'll show up here.")
                    )
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
                syncSelection()
            }
            .onChange(of: trackedExercises.map(\.id)) { _, _ in
                syncSelection()
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
                ForEach(trackedExercises) { exercise in
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
        let volumePoints = summary.points.filter { $0.totalVolume > 0 }

        if weightPoints.isEmpty && volumePoints.isEmpty {
            Text("Log weighted sets to see progress charts.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        } else {
            VStack(spacing: 12) {
                if let delta = summary.deltaWeight {
                    summaryCard(
                        title: "Weight change",
                        value: formattedDelta(delta),
                        subtitle: "max weight over \(range.title)"
                    )
                }
                if let delta = summary.deltaVolume {
                    summaryCard(
                        title: "Volume change",
                        value: formattedDelta(delta),
                        subtitle: "total volume over \(range.title)"
                    )
                }
                HStack(spacing: 12) {
                    if let latest = summary.latestMax {
                        summaryCard(
                            title: "Best weight",
                            value: AppSettings.formatWeight(latest),
                            subtitle: "\(summary.workoutDays) workout days"
                        )
                    }
                    if let volume = summary.latestVolume {
                        summaryCard(
                            title: "Latest volume",
                            value: AppSettings.formatVolume(volume),
                            subtitle: "most recent day"
                        )
                    }
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
                .minimumScaleFactor(0.7)
                .lineLimit(1)
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
        let volumePoints = summary.points.filter { $0.totalVolume > 0 }

        if weightPoints.count >= 2 {
            chartCard(title: "Max weight", points: weightPoints, value: \.maxWeight, yLabel: AppSettings.weightUnit.label)
        }

        if volumePoints.count >= 2 {
            chartCard(title: "Total volume", points: volumePoints, value: \.totalVolume, yLabel: AppSettings.weightUnit.label)
        }
    }

    private func chartCard(
        title: String,
        points: [ProgressDataPoint],
        value: KeyPath<ProgressDataPoint, Double>,
        yLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(title, point[keyPath: value])
                )
                .foregroundStyle(AppTheme.accent)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(title, point[keyPath: value])
                )
                .foregroundStyle(AppTheme.accent)
            }
            .chartYAxisLabel(yLabel)
            .frame(height: 220)
            .padding(12)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func syncSelection() {
        if let selected = selectedExercise,
           trackedExercises.contains(where: { $0.id == selected.id }) {
            return
        }
        selectedExercise = trackedExercises.first
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
