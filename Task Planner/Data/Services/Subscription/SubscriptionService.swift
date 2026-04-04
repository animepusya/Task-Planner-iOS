//
//  SubscriptionService.swift
//  Task Planner
//
//  Created by Codex on 04.04.2026.
//

import Foundation

enum SubscriptionPurchaseResult: Equatable, Sendable {
    case purchased(SubscriptionEntitlement)
    case pending
    case cancelled
    case unavailable
}

@MainActor
protocol SubscriptionService {
    var catalog: SubscriptionCatalog { get }

    func loadProducts() async -> [SubscriptionProduct]
    func currentEntitlement() async -> SubscriptionEntitlement
    func purchase(plan: SubscriptionPlan) async throws -> SubscriptionPurchaseResult
    func restorePurchases() async throws -> SubscriptionEntitlement
    func manageSubscription() async throws -> Bool

    #if DEBUG
    var debugOverrideEnabled: Bool { get }
    func setDebugOverrideEnabled(_ value: Bool)
    #endif
}

