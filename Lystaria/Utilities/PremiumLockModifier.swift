//
//  PremiumLockModifier.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/25/26.
//

import SwiftUI

struct PremiumLockModifier: ViewModifier {
    let isLocked: Bool
    @State private var showPaywall: Bool = false

    private var locked: Bool {
        isLocked
    }

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .blur(radius: locked ? 8 : 0)
            .clipped()
            .allowsHitTesting(!locked)
            .overlay(alignment: .topTrailing) {
                if locked {
                    HStack(spacing: 6) {
                        Image("lockfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.white)

                        Text("Premium only")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(LColors.glassBorder, lineWidth: 1)
                    )
                    .padding(10)
                }
            }
            .overlay {
                if locked {
                    Button {
                        showPaywall = true
                    } label: {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PremiumView()
            }
    }
}

// MARK: - Easy usage

extension View {
    func premiumLocked(_ isLocked: Bool) -> some View {
        self.modifier(PremiumLockModifier(isLocked: isLocked))
    }
}
