//
//  WorkoutLiveActivityViews.swift
//  Shared
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityViews: View {
    let context: ActivityViewContext<WorkoutLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("NOW")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
                if !context.state.tagName.isEmpty {
                    Text("· \(context.state.tagName)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(context.state.setCount) set\(context.state.setCount == 1 ? "" : "s")")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
            }

            Text(context.state.exerciseName)
                .font(.headline)
                .lineLimit(1)

            if let restEndsAt = context.state.restEndsAt, restEndsAt > .now {
                Text(timerInterval: Date.now...restEndsAt, countsDown: true)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
                Text("Rest")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let next = context.state.nextExerciseName, context.state.canAdvance {
                Text("Next: \(next)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                if context.state.hasLoggedSets {
                    Button(intent: DuplicateLastSetIntent()) {
                        Label("Dup", systemImage: "plus.square.on.square")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.orange)
                }

                Link(destination: URL(string: "setcounter://logset")!) {
                    Label("Log", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(.orange)

                if context.state.canAdvance {
                    Button(intent: NextGuidedExerciseIntent()) {
                        Text("Next")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.orange)

                    Button(intent: SkipGuidedExerciseIntent()) {
                        Text("Skip")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.secondary)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .widgetURL(URL(string: "setcounter://today"))
    }
}

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
            WorkoutLiveActivityViews(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("NOW")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.setCount)")
                        .font(.caption.weight(.bold))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        if context.state.hasLoggedSets {
                            Button(intent: DuplicateLastSetIntent()) {
                                Image(systemName: "plus.square.on.square")
                            }
                        }
                        Link(destination: URL(string: "setcounter://logset")!) {
                            Image(systemName: "plus")
                        }
                        if context.state.canAdvance {
                            Button(intent: NextGuidedExerciseIntent()) {
                                Text("Next")
                                    .font(.caption.weight(.semibold))
                            }
                            Button(intent: SkipGuidedExerciseIntent()) {
                                Text("Skip")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                    .tint(.orange)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                if let restEndsAt = context.state.restEndsAt, restEndsAt > .now {
                    Text(timerInterval: Date.now...restEndsAt, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 44)
                } else {
                    Text("\(context.state.setCount)")
                        .font(.caption.weight(.bold))
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.orange)
            }
        }
    }
}
