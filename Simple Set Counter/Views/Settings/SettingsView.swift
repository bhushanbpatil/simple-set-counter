//
//  SettingsView.swift
//  Simple Set Counter
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var unit = AppSettings.weightUnit
    @State private var step = AppSettings.weightStep

    var body: some View {
        Form {
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

            Section("Privacy") {
                Text("All workouts stay on this device. No account. No cloud sync.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
