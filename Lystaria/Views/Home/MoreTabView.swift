//
// MoreTabView.swift
// Lystaria
//
// Created by Asteria Moon
//

import SwiftUI
import SwiftData

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Page Header
                    VStack(alignment: .leading, spacing: 10) {
                        GradientTitle(text: "More", size: 28)

                        Rectangle()
                            .fill(LColors.glassBorder)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // MARK: - Content
                    ScrollView {
                        VStack(spacing: LSpacing.sectionGap) {
                            accountSection
                            appSection
                        }
                        .padding(.horizontal, LSpacing.pageHorizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Account", icon: "userwavy", isAsset: true)

            GlassCard {
                VStack(spacing: 12) {
                    NavigationLink(destination: ProfileTabView()) {
                        MoreRow(
                            icon: "userwavy",
                            iconColor: LColors.gradientPurple,
                            title: "Profile & Settings",
                            subtitle: "Manage your account, timezone, and app preferences"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "App", icon: "infofill", isAsset: true)

            GlassCard {
                VStack(spacing: 12) {
                    NavigationLink(destination: SubscriptionsView()) {
                        MoreRow(
                            icon: "walletfill",
                            iconColor: LColors.gradientPurple,
                            title: "Subscriptions",
                            subtitle: "Track subscriptions with linked reminders"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().background(LColors.glassBorder)

                    NavigationLink(destination: InfoTabView()) {
                        MoreRow(
                            icon: "infofill",
                            iconColor: LColors.accent,
                            title: "Info",
                            subtitle: "Docs, release notes, projects & socials"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - More Row

private struct MoreRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isAsset: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(iconColor.opacity(0.22), lineWidth: 1)
                    )

                if isAsset {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(LColors.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()

            Image("chevronupfill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    MoreTabView()
        .preferredColorScheme(.dark)
}
