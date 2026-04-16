//
//  InfoTabView.swift
//  Lystaria
//
//  Created by Asteria Moon on 4/11/26.
//

import SwiftUI

struct InfoTabView: View {
    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Page Header
                VStack(alignment: .leading, spacing: 10) {
                    GradientTitle(text: "Info", size: 28)

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
                        welcomeBanner
                        docsSection
                        projectsSection
                        socialsSection
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Welcome Banner

    private var welcomeBanner: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image("halfheartfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)
                        .foregroundStyle(LColors.textSecondary)
                    Text("WELCOME TO THE INFO TAB")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(1.4)
                }

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                Text("THIS IS WHERE YOU CAN FIND RESOURCES TO LEARN MORE ABOUT ME AND MY APP. YOU'LL FIND THE LINK TO THE DOCS SITE AND MY OTHER PROJECTS TOO, AND MY SOCIAL ACCOUNTS ARE ALL INCLUDED AS WELL.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
                    .lineSpacing(5)
                    .tracking(0.6)

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                Text("TAKE CARE ✦")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                    .tracking(1.2)
            }
        }
    }

    // MARK: - Docs Section

    private var docsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Documentation", icon: "fillbook", isAsset: true)

            GlassCard {
                VStack(spacing: 12) {
                    InfoLinkRow(
                        icon: "docfill",
                        iconColor: LColors.gradientPurple,
                        title: "Lystaria Docs",
                        subtitle: "Guides, FAQs, and feature references",
                        url: "https://docs.lystaria.im"
                    )

                    Divider()
                        .background(LColors.glassBorder)

                    InfoLinkRow(
                        icon: "lovemail",
                        iconColor: LColors.accent,
                        title: "Send Feedback",
                        subtitle: "Report bugs or suggest features",
                        url: "mailto:contact@lystaria.im"
                    )
                }
            }
        }
    }

    // MARK: - Projects Section

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Other Projects", icon: "fillshapes", isAsset: true)

            GlassCard {
                VStack(spacing: 12) {
                    InfoLinkRow(
                        icon: "globestar",
                        iconColor: LColors.gradientPurple,
                        title: "Lystaria Blog",
                        subtitle: "Lunar cycles, astrology & witchcraft",
                        url: "https://lystaria.im"
                    )

                    Divider()
                        .background(LColors.glassBorder)

                    InfoLinkRow(
                        icon: "boltfill",
                        iconColor: LColors.accent,
                        title: "Elysium Dashboard",
                        subtitle: "Discord bot companion app",
                        url: "https://elysium.lystaria.im"
                    )
                }
            }
        }
    }

    // MARK: - Socials Section

    private var socialsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Socials", icon: "sparklechat", isAsset: true)

            GlassCard {
                VStack(spacing: 12) {
                    InfoLinkRow(
                        icon: "threads",
                        iconColor: LColors.gradientPurple,
                        title: "Threads",
                        subtitle: "@asteriasmoons",
                        url: "https://threads.net/@asteriasmoons"
                    )

                    Divider()
                        .background(LColors.glassBorder)

                    InfoLinkRow(
                        icon: "instafill",
                        iconColor: LColors.accent,
                        title: "Instagram",
                        subtitle: "@asteriasmoons",
                        url: "https://instagram.com/asteriasmoons"
                    )

                    Divider()
                        .background(LColors.glassBorder)

                    InfoLinkRow(
                        icon: "facebook",
                        iconColor: LColors.gradientPurple,
                        title: "Facebook",
                        subtitle: "asteriasmoons",
                        url: "https://facebook.com/asteriasmoons"
                    )

                    Divider()
                        .background(LColors.glassBorder)

                    InfoLinkRow(
                        icon: "discord",
                        iconColor: LColors.accent,
                        title: "Discord",
                        subtitle: "Join the Lystaria community",
                        url: "https://discord.gg/Q69N6d3uKY"
                    )

                    Divider()
                        .background(LColors.glassBorder)

                    InfoLinkRow(
                        icon: "github",
                        iconColor: LColors.gradientPurple,
                        title: "GitHub",
                        subtitle: "asteriasmoons",
                        url: "https://github.com/asteriasmoons"
                    )
                }
            }
        }
    }
}

// MARK: - Info Link Row

private struct InfoLinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let url: String
    var isAsset: Bool = true

    var body: some View {
        Link(destination: URL(string: url)!) {
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
        .buttonStyle(.plain)
    }
}

#Preview {
    InfoTabView()
        .preferredColorScheme(.dark)
}
