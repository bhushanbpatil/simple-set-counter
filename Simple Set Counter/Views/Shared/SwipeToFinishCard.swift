//
//  SwipeToFinishCard.swift
//  Simple Set Counter
//

import SwiftUI

struct SwipeToFinishCard<Content: View>: View {
    let hint: String
    let revealTitle: String
    let onComplete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var thumbOffset: CGFloat = 0

    private let thumbSize: CGFloat = 46
    private let trackInset: CGFloat = 4
    private let trackHeight: CGFloat = 54

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content()

            slideTrack
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityHint("Drag the circle to the right to finish your workout.")
    }

    private var slideTrack: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let maxOffset = max(0, width - thumbSize - trackInset * 2)
            let progress = maxOffset > 0 ? min(1, thumbOffset / maxOffset) : 0

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(AppTheme.accent.opacity(0.14))

                Capsule(style: .continuous)
                    .fill(AppTheme.accent.opacity(0.22 + progress * 0.18))
                    .frame(width: trackInset * 2 + thumbSize + thumbOffset)

                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "flag.checkered")
                    Text(revealTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(AppTheme.accent)
                .opacity(progress > 0.35 ? progress : 0)

                HStack(spacing: 6) {
                    Spacer(minLength: thumbSize + trackInset * 2 + 4)
                    Text(hint)
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right.2")
                        .font(.caption2.weight(.bold))
                    Spacer(minLength: 8)
                }
                .foregroundStyle(AppTheme.accent.opacity(0.82))
                .opacity(1 - progress * 0.45)

                Circle()
                    .fill(AppTheme.accentGradient)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay {
                        Image(systemName: progress > 0.88 ? "checkmark" : "chevron.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 5, y: 2)
                    .offset(x: trackInset + thumbOffset)
                    .gesture(thumbGesture(maxOffset: maxOffset))
            }
        }
        .frame(height: trackHeight)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: thumbOffset)
    }

    private func thumbGesture(maxOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                guard value.translation.width > 0,
                      abs(value.translation.width) > abs(value.translation.height) * 0.5 else { return }
                thumbOffset = min(value.translation.width, maxOffset)
            }
            .onEnded { value in
                let commitThreshold = maxOffset * 0.88
                let shouldFinish = thumbOffset >= commitThreshold
                    || value.predictedEndTranslation.width >= commitThreshold

                if shouldFinish {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeOut(duration: 0.22)) {
                        thumbOffset = maxOffset
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onComplete()
                        thumbOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        thumbOffset = 0
                    }
                }
            }
    }
}
