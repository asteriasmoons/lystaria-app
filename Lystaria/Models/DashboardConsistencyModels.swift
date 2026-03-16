//
//  DashboardConsistencyModels.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/15/26.
//

import Foundation

struct DashboardAreaScore: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let activeDays: Int
}

struct DashboardStreakResult: Hashable {
    let title: String
    let streakDays: Int
}

struct DashboardConsistencyResult: Hashable {
    let mostConsistent: DashboardAreaScore?
    let needsAttention: DashboardAreaScore?
    let strongestStreak: DashboardStreakResult?
    let leastActiveThisWeek: DashboardAreaScore?
}
