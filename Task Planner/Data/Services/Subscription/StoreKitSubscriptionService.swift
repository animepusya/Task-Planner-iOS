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

    private let storeKitManager: StoreKitManager

    convenience init() {
        let catalog = SubscriptionCatalog.taskPlanner()
        self.init(
            catalog: catalog,
            storeKitManager: StoreKitManager(productIDs: catalog.productIDs)
        )
    }

    init(
        catalog: SubscriptionCatalog,
        storeKitManager: StoreKitManager
    ) {
        self.catalog = catalog
        self.storeKitManager = storeKitManager
    }

    func loadProducts() async -> [SubscriptionProduct] {
        let productsByID: [String: StoreKitProductSnapshot]

        do {
            let storeKitProducts = try await storeKitManager.loadProducts()
            productsByID = Dictionary(uniqueKeysWithValues: storeKitProducts.map { ($0.id, $0) })
        } catch {
            productsByID = [:]
        }

        return catalog.orderedPlans.map { configuration in
            let source: SubscriptionProduct.Source = productsByID[configuration.productID] == nil
                ? .fallback
                : .storeKit

            return catalog.makeProduct(
                for: configuration.plan,
                localizedPrice: productsByID[configuration.productID]?.displayPrice,
                source: source
            )
        }
    }

    func refreshEntitlements() async -> SubscriptionEntitlement {
        entitlement(from: await storeKitManager.refreshEntitlements())
    }

    func purchase(plan: SubscriptionPlan) async throws -> SubscriptionPurchaseResult {
        let productID = catalog.productID(for: plan)
        let purchaseOutcome = try await storeKitManager.purchase(productID: productID)
        return purchaseResult(from: purchaseOutcome)
    }

    func restorePurchases() async throws -> SubscriptionEntitlement {
        entitlement(from: try await storeKitManager.restorePurchases())
    }

    func observeTransactionUpdates() -> AsyncStream<SubscriptionEntitlement> {
        return AsyncStream { continuation in
            let updatesTask = Task {
                let transactionUpdates = await storeKitManager.observeTransactionUpdates()

                for await entitlementSnapshot in transactionUpdates {
                    guard Task.isCancelled == false else { break }
                    continuation.yield(entitlement(from: entitlementSnapshot))
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                updatesTask.cancel()
            }
        }
    }

    func manageSubscription() async throws -> Bool {
        guard let scene = activeWindowScene else {
            return false
        }

        do {
            let subscriptionGroupID = try await resolvedSubscriptionGroupID()

            if let subscriptionGroupID, !subscriptionGroupID.isEmpty {
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

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    private func resolvedSubscriptionGroupID() async throws -> String? {
        if let configuredGroupID = catalog.subscriptionGroupID, configuredGroupID.isEmpty == false {
            return configuredGroupID
        }

        return try await storeKitManager.subscriptionGroupID()
    }

    private func purchaseResult(from outcome: StoreKitPurchaseOutcome) -> SubscriptionPurchaseResult {
        switch outcome {
        case .purchased(let entitlementSnapshot):
            return .purchased(entitlement(from: entitlementSnapshot))
        case .pending:
            return .pending
        case .cancelled:
            return .cancelled
        case .unavailable:
            return .unavailable
        }
    }

    private func entitlement(from snapshot: StoreKitEntitlementSnapshot) -> SubscriptionEntitlement {
        guard let activeProductID = snapshot.activeProductID else {
            return .free
        }

        return .pro(productID: activeProductID, source: .storeKit)
    }
}
