//
//  TaskPlannerSubscriptionConfiguration.swift
//  Task Planner
//
//  Created by Codex on 16.04.2026.
//

import Foundation

struct TaskPlannerSubscriptionConfiguration: Sendable {
    let displayName: String
    let subscriptionGroupID: String?
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?
    let orderedPlans: [SubscriptionCatalog.PlanConfiguration]

    static let current = TaskPlannerSubscriptionConfiguration(
        displayName: String(localized: "Task Planner Pro"),
        // Keep these identifiers aligned with App Store Connect so the app can
        // use the same StoreKit 2 flow in development, TestFlight, and production.
        // Leave nil to let StoreKit derive the real subscription group from App Store products.
        subscriptionGroupID: nil,
        privacyPolicyURL: URL(string: "https://animepusya.github.io/Task-Planner-site/privacy.html"),
        termsOfUseURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
        orderedPlans: [
            SubscriptionCatalog.PlanConfiguration(
                plan: .annual,
                productID: "taskplanner.pro.annual",
                subtitle: String(localized: "Best for regular planning"),
                fallbackPrice: SubscriptionPricePresentation(
                    amount: "$19.99",
                    unit: String(localized: "/ year"),
                    note: String(localized: "About $1.67 / month")
                ),
                isRecommended: true
            ),
            SubscriptionCatalog.PlanConfiguration(
                plan: .monthly,
                productID: "taskplanner.pro.monthly",
                subtitle: String(localized: "Flexible month to month"),
                fallbackPrice: SubscriptionPricePresentation(
                    amount: "$2.99",
                    unit: String(localized: "/ month"),
                    note: String(localized: "Billed monthly")
                ),
                isRecommended: false
            )
        ]
    )
}

extension SubscriptionCatalog {
    static func taskPlanner(
        configuration: TaskPlannerSubscriptionConfiguration = .current
    ) -> SubscriptionCatalog {
        SubscriptionCatalog(
            displayName: configuration.displayName,
            subscriptionGroupID: configuration.subscriptionGroupID,
            privacyPolicyURL: configuration.privacyPolicyURL,
            termsOfUseURL: configuration.termsOfUseURL,
            orderedPlans: configuration.orderedPlans
        )
    }
}
