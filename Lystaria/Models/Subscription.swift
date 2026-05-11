//
// Subscription.swift
// Lystaria
//
// Created by Asteria Moon
//

import Foundation
import SwiftData

enum BillingCycle: String, CaseIterable, Codable {
    case weekly  = "weekly"
    case monthly = "monthly"
    case yearly  = "yearly"

    var label: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }

    var scheduleKind: ReminderScheduleKind {
        switch self {
        case .weekly:  return .weekly
        case .monthly: return .monthly
        case .yearly:  return .yearly
        }
    }
}

enum SubscriptionKind: String, CaseIterable, Codable {
    case app        = "app"
    case online     = "online"
    case membership = "membership"

    var label: String {
        switch self {
        case .app:        return "App"
        case .online:     return "Online"
        case .membership: return "Membership"
        }
    }
}

@Model
final class Subscription {
    var id: UUID = UUID()
    var name: String = ""
    var cost: Double = 0.0
    var billingCycleRaw: String = BillingCycle.monthly.rawValue
    var subscriptionKindRaw: String = SubscriptionKind.app.rawValue
    var nextDueDate: Date = Date()
    var reminderTime: Date = Date()
    var category: String = ""
    var notes: String = ""
    var descriptionText: String = ""
    var linkedReminderNotificationID: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var billingCycle: BillingCycle {
        get { BillingCycle(rawValue: billingCycleRaw) ?? .monthly }
        set { billingCycleRaw = newValue.rawValue }
    }

    var subscriptionKind: SubscriptionKind {
        get { SubscriptionKind(rawValue: subscriptionKindRaw) ?? .app }
        set { subscriptionKindRaw = newValue.rawValue }
    }

    init(
        name: String = "",
        cost: Double = 0.0,
        billingCycle: BillingCycle = .monthly,
        subscriptionKind: SubscriptionKind = .app,
        nextDueDate: Date = Date(),
        reminderTime: Date = Date(),
        category: String = "",
        notes: String = "",
        descriptionText: String = ""
    ) {
        self.name = name
        self.cost = cost
        self.billingCycleRaw = billingCycle.rawValue
        self.subscriptionKindRaw = subscriptionKind.rawValue
        self.nextDueDate = nextDueDate
        self.reminderTime = reminderTime
        self.category = category
        self.notes = notes
        self.descriptionText = descriptionText
        self.linkedReminderNotificationID = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
