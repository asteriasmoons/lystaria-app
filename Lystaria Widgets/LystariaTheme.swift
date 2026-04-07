// LystariaTheme.swift
// Lystaria
//
// Design tokens matching the Telegram mini app CSS

import SwiftUI

// MARK: - Color Tokens

enum LColors {
    // Base
    static let bg = Color(hex: "#07070a")
    
    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#888888")
    
    // Accent
    static let accent = Color(hex: "#03dbfc")
    static let accentHover = Color(hex: "#7d19f7")
    static let accentGradient = LinearGradient(
        colors: [
            Color(hex: "#03dbfc"),
            Color(hex: "#7d19f7")
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Status
    static let success = Color(hex: "#e2ed8a")
    static let danger = Color(hex: "#dc3beb")
    static let warning = Color(hex: "#a92ce8")
    
    // Glass surfaces
    static let glassSurface = Color.white.opacity(0.06)
    static let glassSurface2 = Color.white.opacity(0.09)
    static let glassBorder = Color.white.opacity(0.14)
    static let glassBorderStrong = Color.white.opacity(0.22)
    
    // Gradient colors (Not sure need: pink, cyan, yellow, deepPurple)
    static let gradientPurple = Color(hex: "#7d19f7")
    static let gradientBlue = Color(hex: "#03dbfc")
    static let gradientPink = Color(hex: "#e019d4")
    static let gradientCyan = Color(hex: "#00dbff")
    static let gradientYellow = Color(hex: "#f6f684")
    static let gradientDeepPurple = Color(hex: "#8000fe")
    
    // Badge colors
    static let badgeOnce = Color(hex: "#66b8ff")
    static let badgeDaily = Color(hex: "#7d19f7")
    static let badgeWeekly = Color.white
    static let badgeMonthly = Color(hex: "#ec4899")
    static let badgeInterval = Color(hex: "#02edd6")
}

// MARK: - Gradients

enum LGradients {
    static let blue = LinearGradient(
        colors: [LColors.gradientBlue, LColors.gradientPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let header = LinearGradient(
        colors: [LColors.gradientPurple, LColors.gradientBlue],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let tag = LinearGradient(
        colors: [LColors.gradientPurple, LColors.gradientBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Background ambient glow
    static let bgPurple = RadialGradient(
        colors: [Color(hex: "#8000fe").opacity(0.34), .clear],
        center: UnitPoint(x: 0.28, y: 0.18),
        startRadius: 0,
        endRadius: 450
    )
    
    static let bgCyan = RadialGradient(
        colors: [Color(hex: "#00dbff").opacity(0.22), .clear],
        center: UnitPoint(x: 0.76, y: 0.78),
        startRadius: 0,
        endRadius: 475
    )
    
    static let bgYellow = RadialGradient(
        colors: [Color(hex: "#f6f684").opacity(0.22), .clear],
        center: UnitPoint(x: 0.58, y: 0.26),
        startRadius: 0,
        endRadius: 260
    )
    
    static let bgPink = RadialGradient(
        colors: [Color(hex: "#e019d4").opacity(0.14), .clear],
        center: UnitPoint(x: 0.42, y: 0.74),
        startRadius: 0,
        endRadius: 260
    )
}

// MARK: - Spacing & Radius

enum LSpacing {
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 12
    static let inputRadius: CGFloat = 12
    static let pillRadius: CGFloat = 999
    static let pageHorizontal: CGFloat = 16
    static let sectionGap: CGFloat = 24
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
