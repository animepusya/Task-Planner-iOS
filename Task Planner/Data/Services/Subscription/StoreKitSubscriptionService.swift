//
//  StoreKitSubscriptionService.swift
//  Task Planner
//
//  Created by Codex on 04.04.2026.
//

import Foundation
import StoreKit
import UIKit

@MainActor
final class StoreKitSubscriptionService: SubscriptionService {
    let catalog: SubscriptionCatalog

    private var storeKitProductsByID: [String: Product] = [:]
    private let debugOverrideStore: SubscriptionDebugOverrideStore

    convenience init() {
        self.init(
            catalog: .taskPlanner,
            debugOverrideStore: SubscriptionDebugOverrideStore()
        )
    }

    init(
        catalog: SubscriptionCatalog,
        debugOverrideStore: SubscriptionDebugOverrideStore
    ) {
        self.catalog = catalog
        self.debugOverrideStore = debugOverrideStore
    }

    func loadProducts() async -> [SubscriptionProduct] {
        do {
            let products = try await Product.products(for: catalog.productIDs)
            storeKitProductsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            storeKitProductsByID = [:]
        }

        return catalog.orderedPlans.map { configuration in
            let source: SubscriptionProduct.Source = storeKitProductsByID[configuration.productID] == nil
                ? .fallback
                : .storeKit

            return catalog.makeProduct(
                for: configuration.plan,
                localizedPrice: storeKitProductsByID[configuration.productID]?.displayPrice,
                source: source
            )
        }
    }

    func currentEntitlement() async -> SubscriptionEntitlement {
        #if DEBUG
        if debugOverrideStore.isEnabled {
            return .pro(productID: nil, source: .debugOverride)
        }
        #endif

        for await result in Transaction.currentEntitlements {
            guard
                let transaction = verifiedTransaction(from: result),
                catalog.productIDs.contains(transaction.productID)
            else {
                continue
            }

            return .pro(productID: transaction.productID, source: .storeKit)
        }

        return .free
    }

    func purchase(plan: SubscriptionPlan) async throws -> SubscriptionPurchaseResult {
        let productID = catalog.productID(for: plan)

        if storeKitProductsByID[productID] == nil {
            _ = await loadProducts()
        }

        guard let product = storeKitProductsByID[productID] else {
            #if DEBUG
            debugOverrideStore.setEnabled(true)
            return .purchased(.pro(productID: productID, source: .debugOverride))
            #else
            return .unavailable
            #endif
        }

        let purchaseResult = try await product.purchase()

        switch purchaseResult {
        case .success(let verification):
            guard let transaction = verifiedTransaction(from: verification) else {
                return .unavailable
            }

            await transaction.finish()
            return .purchased(
                .pro(productID: transaction.productID, source: .storeKit)
            )

        case .pending:
            return .pending

        case .userCancelled:
            return .cancelled

        @unknown default:
            return .unavailable
        }
    }

    func restorePurchases() async throws -> SubscriptionEntitlement {
        try await AppStore.sync()
        return await currentEntitlement()
    }

    func manageSubscription() async throws -> Bool {
        guard let scene = activeWindowScene else {
            return false
        }

        do {
            if let subscriptionGroupID = catalog.subscriptionGroupID, !subscriptionGroupID.isEmpty {
                try await AppStore.showManageSubscriptions(
                    in: scene,
                    subscriptionGroupID: subscriptionGroupID
                )
            } else {
                try await AppStore.showManageSubscriptions(in: scene)
            }
            return true
        } catch {
            guard let fallbackURL = URL(string: "https://apps.apple.com/account/subscriptions") else {
                return false
            }

            await UIApplication.shared.open(fallbackURL)
            return true
        }
    }

    #if DEBUG
    var debugOverrideEnabled: Bool {
        debugOverrideStore.isEnabled
    }

    func setDebugOverrideEnabled(_ value: Bool) {
        debugOverrideStore.setEnabled(value)
    }
    #endif

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private func verifiedTransaction<T>(from result: VerificationResult<T>) -> T? {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            return nil
        }
    }
}

struct SubscriptionDebugOverrideStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "subscription.debug.proOverrideEnabled"
    ) {
        self.defaults = defaults
        self.key = key
    }

    var isEnabled: Bool {
        #if DEBUG
        defaults.bool(forKey: key)
        #else
        false
        #endif
    }

    func setEnabled(_ value: Bool) {
        #if DEBUG
        defaults.set(value, forKey: key)
        #endif
    }
}
