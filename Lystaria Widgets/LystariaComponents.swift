// LystariaComponents.swift
// Lystaria Widgets
//
// Widget-safe copy of LystariaComponents.
// No UIApplication, no NavigationStack, no keyboard helpers — none of that
// is needed in a widget and would cause extension API errors.

import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(LColors.glassSurface)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .opacity(0.55)
                        .blendMode(.screen)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 20, y: 14)
    }
}

// MARK: - Gradient Capsule Button

struct GradientCapsuleButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button { action() } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AnyShapeStyle(LGradients.blue), in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: LColors.accent.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 3/255, green: 219/255, blue: 252/255),
                            Color(red: 125/255, green: 25/255, blue: 247/255)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: LColors.accent.opacity(0.38), radius: 15, y: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Load More Button

struct LoadMoreButton: View {
    var title: String = "Load More"
    var action: () -> Void

    var body: some View {
        Button { action() } label: {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(AnyShapeStyle(LGradients.blue))
                .clipShape(Capsule())
                .shadow(color: LColors.accent.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Progress Bar

struct GlassProgressBar: View {
    let progress: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                Capsule()
                    .fill(LGradients.blue)
                    .frame(width: max(0, geo.size.width * min(progress, 1.0)))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Animated Background

struct LystariaBackground: View {
    var body: some View {
        ZStack {
            LColors.bg.ignoresSafeArea()

            // Ambient glow layers using the updated teal / purple palette
            RadialGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.30),
                    .clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 3/255, green: 219/255, blue: 252/255).opacity(0.24),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 3/255, green: 219/255, blue: 252/255).opacity(0.14),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.16),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Gradient Header Text

struct GradientTitle: View {
    let text: String
    private let size: CGFloat

    /// Preferred initializer: pass the desired point size and Rochester will be applied automatically.
    init(text: String, size: CGFloat = 28) {
        self.text = text
        self.size = size
    }

    /// Backwards-compatible initializer for existing call sites that still pass `font:`.
    /// Uses a sensible default size while enforcing Rochester for consistent headers.
    init(text: String, font: Font = .title.bold()) {
        self.text = text
        self.size = 28
    }

    var body: some View {
        Text(text)
            .font(.custom("LilyScriptOne-Regular", size: size))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 3/255, green: 219/255, blue: 252/255),
                        Color(red: 125/255, green: 25/255, blue: 247/255)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}
