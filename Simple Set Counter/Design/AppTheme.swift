//
//  AppTheme.swift
//  Simple Set Counter
//

import SwiftUI

enum AccentColorOption: String, CaseIterable, Identifiable {
    case orange
    case coral
    case amber
    case lime
    case teal
    case blue
    case purple
    case pink

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var accent: Color {
        switch self {
        case .orange: return Color(red: 0.95, green: 0.45, blue: 0.15)
        case .coral: return Color(red: 0.98, green: 0.40, blue: 0.35)
        case .amber: return Color(red: 0.98, green: 0.72, blue: 0.18)
        case .lime: return Color(red: 0.72, green: 0.90, blue: 0.22)
        case .teal: return Color(red: 0.22, green: 0.82, blue: 0.78)
        case .blue: return Color(red: 0.35, green: 0.62, blue: 0.98)
        case .purple: return Color(red: 0.68, green: 0.42, blue: 0.98)
        case .pink: return Color(red: 0.98, green: 0.38, blue: 0.62)
        }
    }

    var accentHighlight: Color {
        switch self {
        case .orange: return Color(red: 0.98, green: 0.55, blue: 0.2)
        case .coral: return Color(red: 1.0, green: 0.50, blue: 0.42)
        case .amber: return Color(red: 1.0, green: 0.82, blue: 0.28)
        case .lime: return Color(red: 0.82, green: 0.96, blue: 0.32)
        case .teal: return Color(red: 0.32, green: 0.90, blue: 0.86)
        case .blue: return Color(red: 0.45, green: 0.72, blue: 1.0)
        case .purple: return Color(red: 0.78, green: 0.52, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.48, blue: 0.72)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [accentHighlight, accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

enum AppTheme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let card = Color.white.opacity(0.08)
    static let secondaryText = Color.white.opacity(0.55)

    static var accent: Color {
        AppSettings.accentColor.accent
    }

    static var accentGradient: LinearGradient {
        AppSettings.accentColor.gradient
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
