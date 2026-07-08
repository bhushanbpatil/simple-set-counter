//
//  OnboardingView.swift
//  Simple Set Counter
//

import SwiftUI

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
}

struct OnboardingView: View {
    @AppStorage(AppSettings.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "figure.strengthtraining.traditional",
            title: "Welcome to Simple Set Counter",
            message: "Log gym sets in seconds. No account, no clutter — your routine lives on your phone."
        ),
        OnboardingPage(
            icon: "list.bullet.rectangle",
            title: "Set up your routine",
            message: "Tap Routine on Today to add exercises and optional tags like Upper Body or Leg Day."
        ),
        OnboardingPage(
            icon: "plus.circle.fill",
            title: "Log a set",
            message: "Tap + on any exercise to record weight and reps. Your last workout is remembered automatically."
        ),
        OnboardingPage(
            icon: "hand.draw.fill",
            title: "Finish your workout",
            message: "When you’re done, drag the circle on the header to finish. You’ll get a quick summary and everything saves to History."
        )
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                        pageContent(item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    Button(isLastPage ? "Get Started" : "Next") {
                        if isLastPage {
                            hasCompletedOnboarding = true
                        } else {
                            withAnimation { page += 1 }
                        }
                    }
                    .buttonStyle(.primary)
                    .padding(.horizontal, 20)

                    if !isLastPage {
                        Button("Skip") {
                            hasCompletedOnboarding = true
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .foregroundStyle(.white)
    }

    private var isLastPage: Bool {
        page == pages.count - 1
    }

    private func pageContent(_ item: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: item.icon)
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accent)
                .padding(.bottom, 8)

            Text(item.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(item.message)
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
        .padding(.top, 40)
    }
}

#Preview {
    OnboardingView()
}
