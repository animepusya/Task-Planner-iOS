//
//  SubscriptionStore.swift
//  Task Planner
//
//  Created by Codex on 04.04.2026.
//

import Combine
import Foundation

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var products: [SubscriptionProduct]
    @Published private(set) var entitlement: SubscriptionEntitlement = .free
    @Published private(set) var isRefreshing = false
    @Published private(set) var isPurchaseInFlight = false
    @Published private(set) var isRestoreInFlight = false

    let catalog: SubscriptionCatalog

    private let service: SubscriptionService
    private var didStart = false

    init(service: SubscriptionService) {
        self.service = service
        self.catalog = service.catalog
        self.products = service.catalog.orderedPlans.map {
            service.catalog.makeProduct(
                for: $0.plan,
                localizedPrice: nil,
                source: .fallback
            )
        }
    }

    var hasProAccess: Bool {
        entitlement.isPro
    }

    var currentPlanTitle: String {
        if let plan = catalog.plan(for: entitlement.activeProductID) {
            return product(for: plan).title
        }

        if entitlement.source == .debugOverride {
            return String(localized: "Pro Preview")
        }

        return String(localized: "Free")
    }

    var planSummaryText: String {
        if hasProAccess {
            if entitlement.source == .debugOverride {
                return String(localized: "Debug Pro entitlement is active on this device.")
            }

            return String(
                localized: "Advanced repeats, custom categories, and deeper statistics are unlocked."
            )
        }

        return String(
            localized: "Unlock custom categories, advanced repeats, and day, week, and year statistics."
        )
    }

    func start() {
        guard didStart == false else { return }
        didStart = true

        Task {
            await refresh()
        }
    }

    func refresh() async {
        isRefreshing = true
        products = await service.loadProducts()
        entitlement = await service.currentEntitlement()
        isRefreshing = false
    }

    func hasAccess(to feature: ProFeature) -> Bool {
        switch feature {
        case .customCategories,
             .advancedRepeats,
             .statisticsDayRange,
             .statisticsWeekRange,
             .statisticsYearRange,
             .statisticsComparison:
            return hasProAccess
        }
    }

    func isLocked(_ feature: ProFeature) -> Bool {
        hasAccess(to: feature) == false
    }

    func product(for plan: SubscriptionPlan) -> SubscriptionProduct {
        products.first(where: { $0.plan == plan })
        ?? catalog.makeProduct(for: plan, localizedPrice: nil, source: .fallback)
    }

    func purchase(plan: SubscriptionPlan) async -> MonetizationNotice? {
        isPurchaseInFlight = true
        defer { isPurchaseInFlight = false }

        do {
            let result = try await service.purchase(plan: plan)

            switch result {
            case .purchased(let entitlement):
                self.entitlement = entitlement
                return nil

            case .pending:
                return MonetizationNotice(
                    title: String(localized: "Purchase Pending"),
                    message: String(localized: "Your purchase is pending approval. We'll unlock Pro as soon as Apple confirms it.")
                )

            case .cancelled:
                return nil

            case .unavailable:
                return MonetizationNotice(
                    title: String(localized: "Products Not Connected Yet"),
                    message: String(localized: "Attach a StoreKit Configuration file or connect the real App Store products to finish purchases.")
                )
            }
        } catch {
            return MonetizationNotice(
                title: String(localized: "Couldn't Complete Purchase"),
                message: error.localizedDescription
            )
        }
    }

    func restorePurchases() async -> MonetizationNotice {
        isRestoreInFlight = true
        defer { isRestoreInFlight = false }

        do {
            let restoredEntitlement = try await service.restorePurchases()
            entitlement = restoredEntitlement

            if restoredEntitlement.isPro {
                return MonetizationNotice(
                    title: String(localized: "Purchases Restored"),
                    message: String(localized: "Task Planner Pro is active again on this device.")
                )
            }

            return MonetizationNotice(
                title: String(localized: "Nothing to Restore"),
                message: String(localized: "No active Task Planner Pro subscription was found for this Apple ID.")
            )
        } catch {
            return MonetizationNotice(
                title: String(localized: "Couldn't Restore Purchases"),
                message: error.localizedDescription
            )
        }
    }

    func manageSubscription() async -> MonetizationNotice? {
        do {
            let didPresent = try await service.manageSubscription()
            if didPresent {
                return nil
            }

            return MonetizationNotice(
                title: String(localized: "Manage Subscription Unavailable"),
                message: String(localized: "Subscription management becomes available once StoreKit products are connected.")
            )
        } catch {
            return MonetizationNotice(
                title: String(localized: "Couldn't Open Subscription Settings"),
                message: error.localizedDescription
            )
        }
    }

    #if DEBUG
    var showsDebugControls: Bool {
        true
    }

    var debugOverrideEnabled: Bool {
        service.debugOverrideEnabled
    }

    func toggleDebugOverride() async {
        service.setDebugOverrideEnabled(service.debugOverrideEnabled == false)
        entitlement = await service.currentEntitlement()
    }
    #else
    var showsDebugControls: Bool {
        false
    }
    #endif
}
