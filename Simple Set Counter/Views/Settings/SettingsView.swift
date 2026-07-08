//
//  SettingsView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil })
    private var activeSessions: [WorkoutSession]

    @AppStorage(AppSettings.accentColorKey) private var accentColorRaw = AccentColorOption.lime.rawValue
    @AppStorage(AppSettings.guidedWorkoutFlowKey) private var guidedWorkoutFlow = false
    @AppStorage(AppSettings.restTimerEnabledKey) private var restTimerEnabled = true
    @AppStorage(AppSettings.restTimerDurationKey) private var restTimerDuration = RestTimerDuration.s90.rawValue
    @AppStorage(AppSettings.hasCompletedOnboardingKey) private var hasCompletedOnboarding = true
    @State private var unit = AppSettings.weightUnit
    @State private var step = AppSettings.weightStep
    @State private var smartIncrease = AppSettings.smartIncreaseEnabled

    private var accentColor: Binding<AccentColorOption> {
        Binding(
            get: { AccentColorOption(rawValue: accentColorRaw) ?? .lime },
            set: { accentColorRaw = $0.rawValue }
        )
    }

    private var restDuration: Binding<RestTimerDuration> {
        Binding(
            get: { RestTimerDuration(rawValue: restTimerDuration) ?? .s90 },
            set: { restTimerDuration = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Accent color", selection: accentColor) {
                    ForEach(AccentColorOption.allCases) { option in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(option.gradient)
                                .frame(width: 18, height: 18)
                            Text(option.title)
                        }
                        .tag(option)
                    }
                }

                Text("Changes buttons, highlights, and the slide-to-finish control.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Units") {
                Picker("Weight unit", selection: $unit) {
                    ForEach(WeightUnit.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .onChange(of: unit) { _, newValue in
                    AppSettings.weightUnit = newValue
                }

                Picker("Weight step", selection: $step) {
                    Text("2.5").tag(2.5)
                    Text("5").tag(5.0)
                    Text("10").tag(10.0)
                }
                .onChange(of: step) { _, newValue in
                    AppSettings.weightStep = newValue
                }
            }

            Section("Training") {
                Toggle("Guided workout", isOn: $guidedWorkoutFlow)
                    .onChange(of: guidedWorkoutFlow) { _, enabled in
                        guard !enabled, let session = activeSessions.first else { return }
                        WorkoutFlow.clearFlow(in: session)
                        try? modelContext.save()
                    }

                Text("Shows the active exercise card with Next and Skip. Turn off to log sets directly from your routine list.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if guidedWorkoutFlow {
                    Toggle("Rest timer", isOn: $restTimerEnabled)

                    if restTimerEnabled {
                        Picker("Rest duration", selection: restDuration) {
                            ForEach(RestTimerDuration.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    }

                    Text("Starts automatically after each logged set in guided mode.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Toggle("Smart increase", isOn: $smartIncrease)
                    .onChange(of: smartIncrease) { _, newValue in
                        AppSettings.smartIncreaseEnabled = newValue
                    }

                Text("When any set has more than \(AppSettings.smartIncreaseRepThreshold) reps, the heaviest qualifying set plus \(AppSettings.formatWeight(AppSettings.smartIncreaseIncrement)) becomes next workout’s suggestion.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("All workouts stay on this device. No account. No cloud sync.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let url = URL(string: AppSettings.privacyPolicyURL) {
                    Link("Privacy Policy", destination: url)
                }

                Button("Show tutorial again") {
                    hasCompletedOnboarding = false
                    dismiss()
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
