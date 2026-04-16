//
//  MonetizationModels.swift
//  Task Planner
//
//  Created by Codex on 04.04.2026.
//

import Foundation

enum SubscriptionPlan: String, CaseIterable, Identifiable, Hashable, Sendable {
    case monthly
    case annual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:
            return String(localized: "Monthly plan")
        case .annual:
            return String(localized: "Annual plan")
        }
    }
}

struct SubscriptionPricePresentation: Equatable, Sendable {
    let amount: String
    let unit: String
    let note: String
}

struct SubscriptionProduct: Identifiable, Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case storeKit
        case fallback
    }

    let id: String
    let plan: SubscriptionPlan
    let title: String
    let subtitle: String
    let price: SubscriptionPricePresentation
    let isRecommended: Bool
    let source: Source
}

enum SubscriptionEntitlement: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case storeKit
    }

    case free
    case pro(productID: String?, source: Source)

    var isPro: Bool {
        if case .pro = self {
            return true
        }
        return false
    }

    var activeProductID: String? {
        switch self {
        case .free:
            return nil
        case .pro(let productID, _):
            return productID
        }
    }

    var source: Source? {
        switch self {
        case .free:
            return nil
        case .pro(_, let source):
            return source
        }
    }
}

enum ProFeature: String, CaseIterable, Identifiable, Hashable, Sendable {
    case customCategories
    case advancedRepeats
    case statisticsDayRange
    case statisticsWeekRange
    case statisticsYearRange
    case statisticsComparison

    var id: String { rawValue }
}

enum PaywallEntryPoint: Hashable, Sendable {
    case settings
    case customCategories
    case advancedRepeats
    case statisticsRange(ProFeature)
    case statisticsComparison

    var subtitle: String {
        switch self {
        case .settings:
            return String(localized: "Unlock more flexibility with custom categories, advanced repeats, and deeper statistics.")
        case .customCategories:
            return String(localized: "Create your own categories, use flexible repeats, and unlock deeper planning insights.")
        case .advancedRepeats:
            return String(localized: "Use flexible repeats with custom categories and deeper statistics.")
        case .statisticsRange:
            return String(localized: "Unlock day, week, and year views in Statistics.")
        case .statisticsComparison:
            return String(localized: "Unlock period comparison.")
        }
    }
}

enum SubscriptionLegalLink: CaseIterable, Identifiable, Sendable {
    case privacyPolicy
    case termsOfUse

    var id: String { title }

    var title: String {
        switch self {
        case .privacyPolicy:
            return String(localized: "Privacy Policy")
        case .termsOfUse:
            return String(localized: "Terms of Use")
        }
    }

    func url(from catalog: SubscriptionCatalog) -> URL? {
        switch self {
        case .privacyPolicy:
            return catalog.privacyPolicyURL
        case .termsOfUse:
            return catalog.termsOfUseURL
        }
    }

    var unavailableMessage: String {
        switch self {
        case .privacyPolicy:
            return String(localized: "The privacy policy will be available here before release.")
        case .termsOfUse:
            return String(localized: "The terms of use will be available here before release.")
        }
    }
}

struct MonetizationNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct SubscriptionCatalog: Sendable {
    struct PlanConfiguration: Sendable {
        let plan: SubscriptionPlan
        let productID: String
        let subtitle: String
        let fallbackPrice: SubscriptionPricePresentation
        let isRecommended: Bool
    }

    let displayName: String
    let subscriptionGroupID: String?
    let privacyPolicyURL: URL?
    let termsOfUseURL: URL?

    private let planConfigurations: [SubscriptionPlan: PlanConfiguration]
    private let orderedPlansStorage: [SubscriptionPlan]

    init(
        displayName: String,
        subscriptionGroupID: String?,
        privacyPolicyURL: URL?,
        termsOfUseURL: URL?,
        orderedPlans: [PlanConfiguration]
    ) {
        self.displayName = displayName
        self.subscriptionGroupID = subscriptionGroupID
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfUseURL = termsOfUseURL
        self.orderedPlansStorage = orderedPlans.map(\.plan)
        self.planConfigurations = Dictionary(
            uniqueKeysWithValues: orderedPlans.map { ($0.plan, $0) }
        )
    }

    var orderedPlans: [PlanConfiguration] {
        orderedPlansStorage.compactMap { planConfigurations[$0] }
    }

    var productIDs: [String] {
        orderedPlans.map(\.productID)
    }

    func planConfiguration(for plan: SubscriptionPlan) -> PlanConfiguration {
        guard let configuration = planConfigurations[plan] else {
            preconditionFailure("Missing subscription plan configuration for \(plan.rawValue)")
        }
        return configuration
    }

    func productID(for plan: SubscriptionPlan) -> String {
        planConfiguration(for: plan).productID
    }

    func plan(for productID: String?) -> SubscriptionPlan? {
        guard let productID else { return nil }
        return orderedPlans.first(where: { $0.productID == productID })?.plan
    }

    func makeProduct(
        for plan: SubscriptionPlan,
        localizedPrice: String?,
        source: SubscriptionProduct.Source
    ) -> SubscriptionProduct {
        let configuration = planConfiguration(for: plan)
        let price = SubscriptionPricePresentation(
            amount: localizedPrice ?? configuration.fallbackPrice.amount,
            unit: configuration.fallbackPrice.unit,
            note: configuration.fallbackPrice.note
        )

        return SubscriptionProduct(
            id: configuration.productID,
            plan: configuration.plan,
            title: configuration.plan.title,
            subtitle: configuration.subtitle,
            price: price,
            isRecommended: configuration.isRecommended,
            source: source
        )
    }
}

extension StatisticsRange {
    var requiredProFeature: ProFeature? {
        switch self {
        case .month:
            return nil
        case .day:
            return .statisticsDayRange
        case .week:
            return .statisticsWeekRange
        case .year:
            return .statisticsYearRange
        }
    }
}
