//
//  SpotlightTutorial.swift
//  Simple Set Counter
//

import SwiftUI

// MARK: - Anchor tracking

struct SpotlightAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func spotlightAnchor(_ id: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SpotlightAnchorKey.self,
                    value: [id: proxy.frame(in: .global)]
                )
            }
        }
    }

    @ViewBuilder
    func optionalSpotlightAnchor(_ id: String?) -> some View {
        if let id {
            spotlightAnchor(id)
        } else {
            self
        }
    }
}

// MARK: - Steps

struct SpotlightTutorialStep: Identifiable {
    let id: String
    let anchorID: String?
    let title: String
    let message: String
    let highlightPadding: CGFloat
    let highlightCornerRadius: CGFloat
    let tooltipPlacement: TooltipPlacement

    enum TooltipPlacement {
        case automatic
        case above
        case below
    }

    static let all: [SpotlightTutorialStep] = [
        SpotlightTutorialStep(
            id: "welcome",
            anchorID: nil,
            title: "Welcome",
            message: "A quick tour of the app — we’ll point at the buttons you’ll use every gym day.",
            highlightPadding: 0,
            highlightCornerRadius: 0,
            tooltipPlacement: .automatic
        ),
        SpotlightTutorialStep(
            id: "routine",
            anchorID: "routineButton",
            title: "Build your routine",
            message: "Tap Routine to add exercises, create tags like Leg Day, and drag to reorder.",
            highlightPadding: 8,
            highlightCornerRadius: 10,
            tooltipPlacement: .below
        ),
        SpotlightTutorialStep(
            id: "logSet",
            anchorID: "logSetButton",
            title: "Log a set",
            message: "Tap + on any exercise to record weight and reps. Your last workout is remembered.",
            highlightPadding: 6,
            highlightCornerRadius: 14,
            tooltipPlacement: .below
        ),
        SpotlightTutorialStep(
            id: "header",
            anchorID: "headerCard",
            title: "Finish your workout",
            message: "After you log sets, drag the circle right on this card to finish and see your summary.",
            highlightPadding: 4,
            highlightCornerRadius: 14,
            tooltipPlacement: .below
        ),
        SpotlightTutorialStep(
            id: "tabs",
            anchorID: "tabBar",
            title: "History & progress",
            message: "Review past workouts on the calendar and track strength trends over time.",
            highlightPadding: 4,
            highlightCornerRadius: 16,
            tooltipPlacement: .above
        ),
        SpotlightTutorialStep(
            id: "settings",
            anchorID: "settingsButton",
            title: "Settings",
            message: "Change units, accent color, guided workout, rest timer, and smart increase here.",
            highlightPadding: 8,
            highlightCornerRadius: 10,
            tooltipPlacement: .below
        )
    ]
}

// MARK: - Overlay

struct SpotlightTutorialOverlay: View {
    let step: SpotlightTutorialStep
    let stepIndex: Int
    let stepCount: Int
    let anchors: [String: CGRect]
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let highlight = resolvedHighlight(in: geometry)

            ZStack {
                spotlightMask(highlight: highlight, in: geometry.size)
                    .ignoresSafeArea()
                    .onTapGesture { onNext() }

                if step.anchorID != nil, let highlight {
                    RoundedRectangle(cornerRadius: step.highlightCornerRadius + step.highlightPadding, style: .continuous)
                        .stroke(AppTheme.accent, lineWidth: 2.5)
                        .frame(width: highlight.width, height: highlight.height)
                        .position(x: highlight.midX, y: highlight.midY)
                        .allowsHitTesting(false)
                }

                tooltipCard(highlight: highlight, in: geometry)
                    .padding(.horizontal, 20)
            }
        }
        .transition(.opacity)
    }

    private func resolvedHighlight(in geometry: GeometryProxy) -> CGRect? {
        guard let anchorID = step.anchorID else { return nil }

        if anchorID == "tabBar" {
            let height: CGFloat = 84
            return CGRect(
                x: 16,
                y: geometry.size.height - height - geometry.safeAreaInsets.bottom,
                width: geometry.size.width - 32,
                height: height
            )
        }

        guard var rect = anchors[anchorID], rect.width > 1, rect.height > 1 else { return nil }
        let pad = step.highlightPadding
        rect = rect.insetBy(dx: -pad, dy: -pad)
        return rect
    }

    private func spotlightMask(highlight: CGRect?, in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var path = Path(CGRect(origin: .zero, size: canvasSize))
            if let highlight {
                path.addPath(Path(roundedRect: highlight, cornerRadius: step.highlightCornerRadius + step.highlightPadding))
            }
            context.fill(path, with: .color(.black.opacity(0.78)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private func tooltipCard(highlight: CGRect?, in geometry: GeometryProxy) -> some View {
        let card = VStack(alignment: .leading, spacing: 12) {
            Text(step.title)
                .font(.headline)

            Text(step.message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(stepIndex + 1) of \(stepCount)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                Spacer()

                Button("Skip", action: onSkip)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                Button(stepIndex == stepCount - 1 ? "Done" : "Next", action: onNext)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(18)
        .background(AppTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        if let highlight, step.anchorID != nil {
            let placeAbove = shouldPlaceAbove(highlight: highlight, in: geometry)
            VStack {
                if placeAbove {
                    card
                    Spacer()
                } else {
                    Spacer()
                    card
                }
            }
            .padding(.top, placeAbove ? max(geometry.safeAreaInsets.top + 12, highlight.minY - 160) : highlight.maxY + 16)
            .padding(.bottom, placeAbove ? geometry.size.height - highlight.minY + 12 : max(geometry.safeAreaInsets.bottom + 100, 24))
        } else {
            VStack {
                Spacer()
                card
            }
            .padding(.bottom, 40)
        }
    }

    private func shouldPlaceAbove(highlight: CGRect, in geometry: GeometryProxy) -> Bool {
        switch step.tooltipPlacement {
        case .above: return true
        case .below: return false
        case .automatic:
            return highlight.midY > geometry.size.height * 0.55
        }
    }
}
