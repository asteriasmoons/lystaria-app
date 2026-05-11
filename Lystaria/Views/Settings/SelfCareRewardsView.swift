//
//  SelfCareRewardsView.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/8/26.
//

import SwiftUI
import SwiftData

struct SelfCareRewardsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [SelfCarePointsProfile]
    @State private var activeUserId: String? = nil
    @State private var selectedReward: PremiumReward? = nil
    @State private var showRedeemConfirmation = false
    @State private var showSuccessPopup = false
    @State private var successMessage = ""

    @State private var premiumUntilRaw: Double = UserDefaults.standard.double(forKey: "premiumUntil")

    private var currentProfile: SelfCarePointsProfile? {
        if let userId = activeUserId {
            return profiles.first { $0.userId == userId } ?? profiles.first
        }
        return profiles.first
    }

    private var currentPoints: Int {
        currentProfile?.currentPoints ?? 0
    }

    private var premiumUntil: Date? {
        premiumUntilRaw > 0 ? Date(timeIntervalSince1970: premiumUntilRaw) : nil
    }

    private var isPremiumActive: Bool {
        guard let premiumUntil else { return false }
        return premiumUntil > Date()
    }

    private var premiumStatusText: String {
        guard let premiumUntil else { return "Inactive" }

        if premiumUntil <= Date() {
            return "Expired"
        }

        let days = Calendar.current.dateComponents([.day], from: Date(), to: premiumUntil).day ?? 0

        if days <= 0 {
            return "Active today"
        }

        return "\(days) day\(days == 1 ? "" : "s") left"
    }

    private let rewards: [PremiumReward] = [
        PremiumReward(
            title: "1 Day Premium",
            subtitle: "A little boost for your next stretch of focus.",
            cost: 500,
            days: 1,
            icon: "starpopgift"
        ),
        PremiumReward(
            title: "3 Days Premium",
            subtitle: "A cozy weekend-sized premium unlock.",
            cost: 1300,
            days: 3,
            icon: "starpopgift"
        ),
        PremiumReward(
            title: "7 Days Premium",
            subtitle: "A full week of unlocked Lystaria features.",
            cost: 2100,
            days: 7,
            icon: "starpopgift"
        )
    ]

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 14) {
                    headerSection
                    statusSection
                    rewardsSection
                    infoSection

                    Spacer(minLength: 80)
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.vertical, 20)
            }

            if showSuccessPopup {
                successPopup
                    .zIndex(10)
            }
        }
        .task {
            activeUserId = try? SelfCarePointsManager.resolveActiveUserId(in: modelContext)

            if let userId = activeUserId {
                _ = try? SelfCarePointsManager.fetchOrCreateProfile(in: modelContext, userId: userId)
            }
            premiumUntilRaw = UserDefaults.standard.double(forKey: "premiumUntil")
        }
        .confirmationDialog(
            "Redeem Premium?",
            isPresented: $showRedeemConfirmation,
            titleVisibility: .visible
        ) {
            if let selectedReward {
                Button("Redeem for \(selectedReward.cost) points") {
                    redeem(selectedReward)
                }
            }

            Button("Cancel", role: .cancel) {
                selectedReward = nil
            }
        } message: {
            if let selectedReward {
                Text("This will spend \(selectedReward.cost) points and add \(selectedReward.days) premium day\(selectedReward.days == 1 ? "" : "s") to your account.")
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GradientTitle(text: "Rewards", size: 28)

                Spacer()
            }

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.top, 6)
        }
    }

    private var statusSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Points")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)

                        Text("\(currentPoints)")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Premium")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)

                        Text(premiumStatusText)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(isPremiumActive ? LColors.success : LColors.textPrimary)
                    }
                }

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                Text("Spend your earned Self Care Points to unlock temporary premium access. Premium days stack, so redeeming more while premium is active adds extra time.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var rewardsSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Premium Rewards", icon: "gift.fill")

            VStack(spacing: 12) {
                ForEach(rewards) { reward in
                    rewardCard(reward)
                }
            }
        }
    }

    private func rewardCard(_ reward: PremiumReward) -> some View {
        let canAfford = currentPoints >= reward.cost

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LColors.glassSurface2)
                            .overlay(
                                Circle().stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(width: 42, height: 42)

                        Image(reward.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 21, height: 21)
                            .foregroundStyle(LColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(reward.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)

                        Text(reward.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(reward.cost) points")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)

                        Text("\(reward.days) premium day\(reward.days == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                    }

                    Spacer()

                    Button {
                        selectedReward = reward
                        showRedeemConfirmation = true
                    } label: {
                        Text(canAfford ? "Redeem" : "Need \(reward.cost - currentPoints) more")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: canAfford
                                    ? [LColors.gradientBlue, LColors.gradientPurple]
                                    : [Color.gray.opacity(0.55), Color.gray.opacity(0.35)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAfford)
                    .opacity(canAfford ? 1 : 0.65)
                }
            }
        }
    }

    private var infoSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("How redemption works")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)

                Text("Premium days are added to your current premium time. If premium is inactive, the reward starts today. If premium is already active, the new days are added to the existing expiration date.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var successPopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showSuccessPopup = false
                }
            },
            width: 520,
            heightRatio: 0.42,
            header: {
                HStack {
                    GradientTitle(text: "Premium Activated", size: 26)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showSuccessPopup = false
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LColors.glassSurface2)
                                .overlay(
                                    Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                )
                                .frame(width: 34, height: 34)

                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LColors.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                Text(successMessage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
                    .multilineTextAlignment(.leading)
            },
            footer: {
                HStack {
                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showSuccessPopup = false
                        }
                    } label: {
                        Text("Close")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        )
    }

    private func redeem(_ reward: PremiumReward) {
        guard currentProfile != nil else { return }
        guard currentPoints >= reward.cost else { return }

        do {
            try SelfCarePointsManager.spendPoints(in: modelContext, amount: reward.cost)
        } catch {
            return
        }

        let now = Date()
        let baseDate: Date

        if let premiumUntil, premiumUntil > now {
            baseDate = premiumUntil
        } else {
            baseDate = now
        }

        let newPremiumUntil = Calendar.current.date(
            byAdding: .day,
            value: reward.days,
            to: baseDate
        ) ?? baseDate.addingTimeInterval(Double(reward.days) * 86_400)

        let newPremiumUntilRaw = newPremiumUntil.timeIntervalSince1970
        UserDefaults.standard.set(newPremiumUntilRaw, forKey: "premiumUntil")
        premiumUntilRaw = newPremiumUntilRaw

        successMessage = "\(reward.title) has been added. Your premium access now lasts until \(newPremiumUntil.formatted(date: .abbreviated, time: .shortened))."

        selectedReward = nil

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showSuccessPopup = true
        }
    }
}

private struct PremiumReward: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let cost: Int
    let days: Int
    let icon: String
}
