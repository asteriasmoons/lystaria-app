//
//  LimitManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/25/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LimitManager: ObservableObject {
    static let shared = LimitManager()

    
    @AppStorage("isPremiumDevBypass") var isPremiumDevBypass: Bool = false
    @ObservedObject private var premiumManager = PremiumManager.shared

    @AppStorage("appleUserId") var currentAppleUserId: String = ""

    private let adminAppleUserId: String = "001664.f2fefbb84f024544b98e865fa6c6b49e.1524"

    private var isAdminUser: Bool {
        currentAppleUserId == adminAppleUserId
    }

    var hasPremiumAccess: Bool {
        premiumManager.isPremium || isPremiumDevBypass || isAdminUser
    }

    private init() {}

    // MARK: - Premium Gates

    enum PremiumGate: CaseIterable {
        case selfCareSystem
        case dashboardSelfCareCard
        case dashboardDailyBalanceCard
        case dashboardDailyTarotCard
        case dashboardWellnessWallCard
        case profileSelfCarePointsButton
        case readingSummary
        case readingRecommendations
        case stepsGoalCalendar
        case waterGoalCalendar
    }

    func canAccess(_ gate: PremiumGate) -> Bool {
        hasPremiumAccess
    }

    // MARK: - Count / Daily Limits

    enum LimitedFeature {
        case healthMetricsPerDay
        case exercisesPerDay
        case bookCardsTotal
        case bookmarkFoldersTotal
        case bookmarksTotal
        case journalBooksTotal
        case journalEntriesTotal
        case moodEntriesPerDay
        case habitsTotal
        case checklistTabsTotal
        case checklistItemsTotalAcrossAllTabs
        case calendarsTotal
        case calendarEventsTotal
        case remindersTotal
        case kanbanBoardsTotal
        case kanbanColumnsPerBoard
        case medicationCardsTotal
    }

    struct Decision {
        let allowed: Bool
        let limit: Int?
        let currentCount: Int
    }

    func limit(for feature: LimitedFeature) -> Int? {
        guard !hasPremiumAccess else { return nil }

        switch feature {
        case .healthMetricsPerDay:
            return 3
        case .exercisesPerDay:
            return 3
        case .bookCardsTotal:
            return 4
        case .bookmarkFoldersTotal:
            return 2
        case .bookmarksTotal:
            return 20
        case .journalBooksTotal:
            return 1
        case .journalEntriesTotal:
            return 50
        case .moodEntriesPerDay:
            return 1
        case .habitsTotal:
            return 3
        case .checklistTabsTotal:
            return 2
        case .checklistItemsTotalAcrossAllTabs:
            return 30
        case .calendarsTotal:
            return 3
        case .calendarEventsTotal:
            return 20
        case .remindersTotal:
            return 5
        case .kanbanBoardsTotal:
            return 2
        case .kanbanColumnsPerBoard:
            return 3
        case .medicationCardsTotal:
            return 4
        }
    }

    func canCreate(_ feature: LimitedFeature, currentCount: Int) -> Decision {
        guard let limit = limit(for: feature) else {
            return Decision(allowed: true, limit: nil, currentCount: currentCount)
        }

        return Decision(
            allowed: currentCount < limit,
            limit: limit,
            currentCount: currentCount
        )
    }

    // MARK: - History Limits

    enum HistoryFeature {
        case healthHistory
        case moodHistory
    }

    func historyDays(for feature: HistoryFeature) -> Int? {
        guard !hasPremiumAccess else { return nil }

        switch feature {
        case .healthHistory:
            return 3
        case .moodHistory:
            return 5
        }
    }

    func cutoffDate(for feature: HistoryFeature, now: Date = Date()) -> Date? {
        guard let days = historyDays(for: feature) else { return nil }
        return Calendar.current.date(byAdding: .day, value: -(days - 1), to: startOfDay(for: now))
    }

    // MARK: - Midnight Helpers

    func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
}
