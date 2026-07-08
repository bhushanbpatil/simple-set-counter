//
//  RestTimerBanner.swift
//  Simple Set Counter
//

import SwiftUI

struct RestTimerBanner: View {
    let endsAt: Date
    let totalDuration: TimeInterval
    let onSkip: () -> Void
    let onAddTime: () -> Void
    let onComplete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let progress = restProgress(remaining: remaining)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("REST")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Text(AppSettings.formatRestCountdown(remaining))
                        .font(.title2.monospacedDigit().weight(.bold))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.accent.opacity(0.14))
                        Capsule()
                            .fill(AppTheme.accentGradient)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 6)

                HStack(spacing: 12) {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(action: onAddTime) {
                        Text("+15s")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .foregroundStyle(.white)
            }
            .padding(16)
            .background(AppTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onChange(of: Int(remaining)) { _, secondsLeft in
                if secondsLeft == 0 {
                    onComplete()
                }
            }
        }
    }

    private func restProgress(remaining: TimeInterval) -> CGFloat {
        let total = max(1, totalDuration)
        return CGFloat(min(1, remaining / total))
    }
}
