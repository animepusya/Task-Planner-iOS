//
//  StoreKitManager.swift
//  Task Planner
//
//  Created by Codex on 16.04.2026.
//

import Foundation
import StoreKit

struct StoreKitProductSnapshot: Equatable, Sendable {
    let id: String
    let displayPrice: String
}

struct StoreKitEntitlementSnapshot: Equatable, Sendable {
    let activeProductID: String?

    static let free = StoreKitEntitlementSnapshot(activeProductID: nil)
}

enum StoreKitPurchaseOutcome: Equatable, Sendable {
    case purchased(StoreKitEntitlementSnapshot)
    case pending
    case cancelled
    case unavailable
}

actor StoreKitManager {
    private let productIDs: Set<String>
    private var storeKitProductsByID: [String: Product] = [:]
    private var cachedSubscriptionGroupID: String?

    init(productIDs: [String]) {
        self.productIDs = Set(productIDs)
    }

    func loadProducts() async throws -> [StoreKitProductSnapshot] {
        let products = try await Product.products(for: Array(productIDs))
        storeKitProductsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        cachedSubscriptionGroupID = products.compactMap { $0.subscription?.subscriptionGroupID }.first

        return products.map {
            StoreKitProductSnapshot(
                id: $0.id,
                displayPrice: $0.displayPrice
            )
        }
    }

    func subscriptionGroupID() async throws -> String? {
        if cachedSubscriptionGroupID == nil {
            if storeKitProductsByID.isEmpty {
                _ = try await loadProducts()
            } else {
                cachedSubscriptionGroupID = storeKitProductsByID.values.compactMap {
                    $0.subscription?.subscriptionGroupID
                }.first
            }
        }

        return cachedSubscriptionGroupID
    }

    func purchase(productID: String) async throws -> StoreKitPurchaseOutcome {
        if storeKitProductsByID[productID] == nil {
            _ = try await loadProducts()
        }

        guard let product = storeKitProductsByID[productID] else {
            return .unavailable
        }

        let purchaseResult = try await product.purchase()

        switch purchaseResult {
        case .success(let verification):
            guard
                let transaction = verifiedTransaction(from: verification),
                productIDs.contains(transaction.productID)
            else {
                return .unavailable
            }

            await transaction.finish()
            return .purchased(await refreshEntitlements())

        case .pending:
            return .pending

        case .userCancelled:
            return .cancelled

        @unknown default:
            return .unavailable
        }
    }

    func restorePurchases() async throws -> StoreKitEntitlementSnapshot {
        try await AppStore.sync()
        return await refreshEntitlements()
    }

    func refreshEntitlements() async -> StoreKitEntitlementSnapshot {
        var activeTransaction: Transaction?

        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result) else {
                continue
            }

            guard isRelevant(transaction) else {
                continue
            }

            guard let currentBest = activeTransaction else {
                activeTransaction = transaction
                continue
            }

            if sortKey(for: transaction) > sortKey(for: currentBest) {
                activeTransaction = transaction
            }
        }

        return StoreKitEntitlementSnapshot(activeProductID: activeTransaction?.productID)
    }

    func observeTransactionUpdates() -> AsyncStream<StoreKitEntitlementSnapshot> {
        AsyncStream { continuation in
            let updatesTask = Task {
                for await result in Transaction.updates {
                    guard Task.isCancelled == false else { break }

                    guard let transaction = verifiedTransaction(from: result) else {
                        continue
                    }

                    guard productIDs.contains(transaction.productID) else {
                        continue
                    }

                    await transaction.finish()
                    let updatedEntitlement = await refreshEntitlements()
                    continuation.yield(updatedEntitlement)
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                updatesTask.cancel()
            }
        }
    }

    private func isRelevant(_ transaction: Transaction) -> Bool {
        guard productIDs.contains(transaction.productID) else {
            return false
        }

        if transaction.revocationDate != nil || transaction.isUpgraded {
            return false
        }

        if let expirationDate = transaction.expirationDate, expirationDate <= .now {
            return false
        }

        return true
    }

    private func sortKey(for transaction: Transaction) -> Date {
        transaction.expirationDate ?? transaction.purchaseDate
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
