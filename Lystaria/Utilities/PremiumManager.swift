//
//  PremiumManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/26/26.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class PremiumManager: ObservableObject {
    static let shared = PremiumManager()

    @Published var isPremium: Bool = false
    @Published var products: [Product] = []

    // MARK: - Synced Premium Bypass
    // This mirrors the UserSettings premium bypass used by LimitManager.
    // If synced settings are unavailable during beta/testing, fallback keeps premium unlocked.
    @Published private(set) var premiumBypassEnabled: Bool = true

    private let fallbackPremiumBypassEnabled = true

    private let productIds: Set<String> = [
        "lystaria.premium.monthly",
        "lystaria.premium.weekly"
    ]

    init() {
        Task {
            await loadProducts()
            await updatePremiumStatus()
            listenForTransactions()
        }
    }

    // MARK: - Premium Bypass Sync

    func syncPremiumBypass(from settings: UserSettings?) {
        let shouldBypass = settings?.premiumBypassEnabled ?? fallbackPremiumBypassEnabled
        guard premiumBypassEnabled != shouldBypass else {
            if shouldBypass && !isPremium {
                isPremium = true
            }
            return
        }

        premiumBypassEnabled = shouldBypass

        if shouldBypass {
            isPremium = true
        } else {
            Task {
                await updatePremiumStatus()
            }
        }
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIds)
            print("✅ Loaded \(products.count) products:", products.map(\.id))
        } catch {
            print("❌ Failed to load products:", error)
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await updatePremiumStatus()
                }
            default:
                break
            }
        } catch {
            print("❌ Purchase failed:", error)
        }
    }

    // MARK: - Restore

    func restore() async {
        do {
            try await AppStore.sync()
            await updatePremiumStatus()
        } catch {
            print("❌ Restore failed:", error)
        }
    }

    // MARK: - Check Status

    func updatePremiumStatus() async {
        if premiumBypassEnabled {
            isPremium = true
            return
        }

        var hasPremium = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIds.contains(transaction.productID) {
                    hasPremium = true
                }
            }
        }

        isPremium = hasPremium
    }

    // MARK: - Listen for updates

    func listenForTransactions() {
        Task {
            for await result in Transaction.updates {
                if case .verified(_) = result {
                    await updatePremiumStatus()
                }
            }
        }
    }
}
