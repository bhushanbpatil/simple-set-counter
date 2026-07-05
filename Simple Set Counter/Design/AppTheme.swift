//
//  AppTheme.swift
//  Simple Set Counter
//

import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let card = Color.white.opacity(0.08)
    static let accent = Color(red: 0.95, green: 0.45, blue: 0.15)
    static let secondaryText = Color.white.opacity(0.55)

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.98, green: 0.55, blue: 0.2), accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accentGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
