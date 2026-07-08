//
//  OnboardingView.swift
//  Simple Set Counter
//

import SwiftUI

/// Hosts the spotlight tutorial over the real app chrome.
struct OnboardingView<Content: View>: View {
    @AppStorage(AppSettings.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var stepIndex = 0
    @State private var anchors: [String: CGRect] = [:]

    @ViewBuilder let content: () -> Content

    private var steps: [SpotlightTutorialStep] { SpotlightTutorialStep.all }
    private var isActive: Bool { !hasCompletedOnboarding }

    var body: some View {
        content()
            .onPreferenceChange(SpotlightAnchorKey.self) { anchors = $0 }
            .overlay {
                if isActive {
                    SpotlightTutorialOverlay(
                        step: steps[stepIndex],
                        stepIndex: stepIndex,
                        stepCount: steps.count,
                        anchors: anchors,
                        onNext: advance,
                        onSkip: complete
                    )
                    .zIndex(100)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: stepIndex)
            .onChange(of: hasCompletedOnboarding) { _, completed in
                if !completed { stepIndex = 0 }
            }
    }

    private func advance() {
        if stepIndex >= steps.count - 1 {
            complete()
        } else {
            stepIndex += 1
        }
    }

    private func complete() {
        hasCompletedOnboarding = true
    }
}
