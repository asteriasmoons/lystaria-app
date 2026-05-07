//
//  DeveloperSettings.swift
//  Lystaria
//

import Foundation
import SwiftData

@Model
final class DeveloperSettings {
    var id: UUID = UUID()
    var appleUserId: String = ""

    var isAdminMode: Bool = false
    var isPremiumDevBypass: Bool = false
    var forceFreeMode: Bool = false

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        appleUserId: String = "",
        isAdminMode: Bool = false,
        isPremiumDevBypass: Bool = false,
        forceFreeMode: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.appleUserId = appleUserId
        self.isAdminMode = isAdminMode
        self.isPremiumDevBypass = isPremiumDevBypass
        self.forceFreeMode = forceFreeMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
