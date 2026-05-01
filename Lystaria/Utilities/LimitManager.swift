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

    // MARK: - AppStorage-backed inputs
    // @AppStorage on a non-View type doesn't trigger objectWillChange automatically,
    // but we pair each one with a Combine publisher via UserDefaults KVO so that
    // any write — from any view or any @AppStorage binding in the app — causes
    // hasPremiumAccess to recompute and objectWillChange to fire.

    @Published private(set) var hasPremiumAccess: Bool = false

    private let adminAppleUserId = "001664.f2fefbb84f024544b98e865fa6c6b49e.1524"
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Initial computation
        recomputeAccess()

        // Observe PremiumManager.isPremium (Combine publisher — reliable)
        PremiumManager.shared.$isPremium
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recomputeAccess() }
            .store(in: &cancellables)

        // Observe every UserDefaults write via KVO publishers
        // NSObject.KeyValueObservingPublisher is synchronous and fires on the
        // thread that made the write, then we hop to main.
        let defaults = UserDefaults.standard

        defaults.publisher(for: \.forceFreeMode, options: [.new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recomputeAccess() }
            .store(in: &cancellables)

        defaults.publisher(for: \.isPremiumDevBypass, options: [.new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recomputeAccess() }
            .store(in: &cancellables)

        defaults.publisher(for: \.appleUserId, options: [.new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recomputeAccess() }
            .store(in: &cancellables)
    }

    private func recomputeAccess() {
        let defaults = UserDefaults.standard
        let forceFree  = defaults.bool(forKey: "forceFreeMode")
        let devBypass  = defaults.bool(forKey: "isPremiumDevBypass")
        let userId     = defaults.string(forKey: "appleUserId") ?? ""
        let isPremium  = PremiumManager.shared.isPremium
        let isAdmin    = userId == adminAppleUserId

        let newValue = !forceFree && (isPremium || devBypass || isAdmin)
        if hasPremiumAccess != newValue {
            hasPremiumAccess = newValue
        }
    }

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
        case sleepScore
        case dailyCompletion
        case readingGoal
        case buddyReading
        case sprintRoom
    }

    func canAccess(_ gate: PremiumGate) -> Bool {
        // Free for all users
        if gate == .selfCareSystem
            || gate == .dashboardSelfCareCard
            || gate == .profileSelfCarePointsButton
            || gate == .dashboardDailyBalanceCard
            || gate == .dashboardDailyTarotCard
            || gate == .sleepScore
            || gate == .dailyCompletion
            || gate == .readingGoal {
            return true
        }
        return hasPremiumAccess
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
        case notesTabsTotal
        case notesVisibleTotal
        case symptomLogsTotal
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
            return 4
        case .exercisesPerDay:
            return 4
        case .bookCardsTotal:
            return 6
        case .bookmarkFoldersTotal:
            return 4
        case .bookmarksTotal:
            return 20
        case .journalBooksTotal:
            return 1
        case .journalEntriesTotal:
            return 50
        case .moodEntriesPerDay:
            return 1
        case .habitsTotal:
            return 5
        case .checklistTabsTotal:
            return 2
        case .checklistItemsTotalAcrossAllTabs:
            return 30
        case .calendarsTotal:
            return 3
        case .calendarEventsTotal:
            return 20
        case .remindersTotal:
            return 10
        case .kanbanBoardsTotal:
            return 2
        case .kanbanColumnsPerBoard:
            return 3
        case .medicationCardsTotal:
            return 6
        case .notesTabsTotal:
            return 1
        case .notesVisibleTotal:
            return 10
        case .symptomLogsTotal:
            return 6
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
            return 7
        case .moodHistory:
            return 7
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

// MARK: - UserDefaults KVO key paths
// Required for UserDefaults.publisher(for: \.key) to compile.
extension UserDefaults {
    @objc dynamic var forceFreeMode: Bool {
        return bool(forKey: "forceFreeMode")
    }
    @objc dynamic var isPremiumDevBypass: Bool {
        return bool(forKey: "isPremiumDevBypass")
    }
    @objc dynamic var appleUserId: String {
        return string(forKey: "appleUserId") ?? ""
    }
}
