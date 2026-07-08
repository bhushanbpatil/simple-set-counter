//
//  WorkoutSummarySheet.swift
//  Simple Set Counter
//

import SwiftUI

struct WorkoutSummarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let summary: WorkoutSummaryData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.accent)
                        Text("Workout complete")
                            .font(.title2.weight(.bold))
                        Text("Nice work — your sets are saved to History.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        summaryStat(title: "Duration", value: AppSettings.formatDuration(summary.duration))
                        summaryStat(title: "Sets", value: "\(summary.totalSets)")
                        summaryStat(title: "Reps", value: "\(summary.totalReps)")
                        summaryStat(title: "Exercises", value: "\(summary.exerciseCount)")
                    }

                    if summary.totalVolume > 0 {
                        summaryStat(
                            title: "Volume",
                            value: AppSettings.formatVolume(summary.totalVolume)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !summary.exerciseRows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Breakdown")
                                .font(.headline)

                            ForEach(summary.exerciseRows) { row in
                                HStack {
                                    Text(row.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(row.setCount) set\(row.setCount == 1 ? "" : "s") · \(row.repCount) reps")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .foregroundStyle(.white)
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func summaryStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
