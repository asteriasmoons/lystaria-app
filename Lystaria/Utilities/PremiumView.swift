//
// PremiumView.swift
// Lystaria
//
//

import SwiftUI
import StoreKit
import Combine
import Foundation

struct PremiumView: View {
    @ObservedObject private var premium = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 20) {

                    // HEADER
                    ZStack(alignment: .trailing) {
                        VStack(spacing: 8) {
                            GradientTitle(text: "Lystaria Premium", size: 28)

                            Text("Unlock your full system")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)

                    // FEATURES CARD
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What you unlock")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(LColors.textPrimary)

                            feature("Unlimited tracking across all systems")
                            feature("Full dashboard insights & tools")
                            feature("Complete journaling + reading access")
                            feature("Advanced health + self-care systems")
                        }
                    }

                    // PRODUCTS
                    ForEach(premium.products, id: \.id) { product in
                        GlassCard {
                            Button {
                                Task {
                                    await premium.purchase(product)
                                    if premium.isPremium {
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.displayName)
                                            .font(.system(size: 15, weight: .semibold))

                                        Text(product.description)
                                            .font(.system(size: 12))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    Spacer()

                                    Text(product.displayPrice)
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // RESTORE
                    Button {
                        Task {
                            await premium.restore()
                            if premium.isPremium {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.vertical, 20)
            }

        }
    }

    // MARK: - Feature Row
    private func feature(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(LGradients.blue)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LColors.textPrimary)
        }
    }
}
