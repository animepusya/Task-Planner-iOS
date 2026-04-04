//
//  PaywallView.swift
//  Task Planner
//
//  Created by Codex on 04.04.2026.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var notice: MonetizationNotice?

    let entryPoint: PaywallEntryPoint

    var body: some View {
        ZStack {
            AppBackgroundView(
                gradient: DS.GradientToken.pinkPurpleSoft,
                gradientOpacity: 0.58,
                blurRadius: 24
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    topSection
                    planSection
                    comparisonSection
                    actionsSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            if subscriptionStore.hasProAccess, let activePlan = subscriptionStore.catalog.plan(for: subscriptionStore.entitlement.activeProductID) {
                selectedPlan = activePlan
            }
        }
    }

    private var topSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    ProBadge()

                    Text(subscriptionStore.catalog.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .dsSurface(Capsule(), fill: DS.Surface.frosted)

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .frame(width: 40, height: 40)
                        .dsSurface(Circle(), fill: DS.Surface.chrome)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("A lighter way to unlock more")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Text(entryPoint.subtitle)
                    .font(DS.Typography.subtitle)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(subscriptionStore.catalog.orderedPlans, id: \.plan) { configuration in
                let product = subscriptionStore.product(for: configuration.plan)

                Button {
                    selectedPlan = configuration.plan
                } label: {
                    PaywallPlanCard(
                        product: product,
                        isSelected: selectedPlan == configuration.plan,
                        isCurrentPlan: subscriptionStore.catalog.plan(for: subscriptionStore.entitlement.activeProductID) == configuration.plan,
                        isUnlocked: subscriptionStore.hasProAccess
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Free vs Pro")
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                if subscriptionStore.hasProAccess == false {
                    ProBadge(size: .small)
                }
            }

            VStack(spacing: 0) {
                HStack {
                    Text("What changes")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    Spacer()

                    Text("Free")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(width: 44)

                    Text("Pro")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(width: 44)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, 10)

                let rows = PaywallComparisonRowData.allCases

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    PaywallComparisonRow(row: row)

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, DS.Spacing.md)
                    }
                }
            }
            .dsCard(padding: 0) {
                DS.Surface.card
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                Task {
                    await handlePrimaryAction()
                }
            } label: {
                HStack {
                    if subscriptionStore.isPurchaseInFlight || subscriptionStore.isRestoreInFlight {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(primaryActionTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.GradientToken.brandPink)
                )
            }
            .buttonStyle(.plain)
            .disabled(subscriptionStore.isPurchaseInFlight || subscriptionStore.isRestoreInFlight)

            HStack(spacing: DS.Spacing.md) {
                Button("Restore Purchases") {
                    Task {
                        notice = await subscriptionStore.restorePurchases()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.purple)

                Spacer()

                Button("Manage Subscription") {
                    Task {
                        notice = await subscriptionStore.manageSubscription()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textSecondary)
            }

            HStack(spacing: 14) {
                ForEach(SubscriptionLegalLink.allCases) { link in
                    Button(link.title) {
                        openLegal(link)
                    }
                    .buttonStyle(.plain)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                }
            }
            .padding(.top, 2)
        }
        .dsCard(cornerRadius: DS.Radius.lg) {
            DS.Surface.chrome
        }
    }

    private var primaryActionTitle: String {
        if subscriptionStore.hasProAccess {
            return String(localized: "Manage Subscription")
        }

        switch selectedPlan {
        case .monthly:
            return String(localized: "Continue Monthly")
        case .yearly:
            return String(localized: "Continue Annual")
        }
    }

    private func handlePrimaryAction() async {
        if subscriptionStore.hasProAccess {
            notice = await subscriptionStore.manageSubscription()
            return
        }

        notice = await subscriptionStore.purchase(plan: selectedPlan)
    }

    private func openLegal(_ link: SubscriptionLegalLink) {
        guard let url = link.url(from: subscriptionStore.catalog) else {
            notice = MonetizationNotice(
                title: link.title,
                message: link.unavailableMessage
            )
            return
        }

        openURL(url)
    }
}

private struct PaywallPlanCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let isCurrentPlan: Bool
    let isUnlocked: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(product.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        if product.isRecommended {
                            Text("Recommended")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.ColorToken.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DS.ColorToken.purple.opacity(0.10), in: Capsule())
                        } else if isCurrentPlan && isUnlocked {
                            Text("Active")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.ColorToken.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DS.ColorToken.purple.opacity(0.10), in: Capsule())
                        }
                    }

                    Text(product.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }

                Spacer(minLength: 12)

                selectionCircle
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(product.price.amount)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Text(product.price.unit)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }

            Text(product.price.note)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
        .padding(DS.Spacing.md)
        .background(backgroundFill)
        .clipShape(shape)
        .overlay {
            shape.stroke(borderColor, lineWidth: isSelected ? 1.35 : 1)
        }
    }

    private var backgroundFill: some View {
        ZStack {
            if product.isRecommended && isSelected {
                DS.GradientToken.pinkPurpleCardBackground
            } else {
                DS.Surface.card
            }
        }
    }

    private var borderColor: Color {
        if isSelected {
            return DS.ColorToken.purple.opacity(0.34)
        }
        return DS.Border.subtle
    }

    private var selectionCircle: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? DS.ColorToken.purple : DS.Border.subtle, lineWidth: 1.3)
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(DS.ColorToken.purple)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

private enum PaywallComparisonRowData: CaseIterable, Identifiable {
    case basicTasks
    case basicCategories
    case customCategories
    case basicRepeats
    case advancedRepeats
    case monthlyStatistics
    case extendedStatistics
    case advancedInsights

    var id: String { title }

    var title: String {
        switch self {
        case .basicTasks:
            return String(localized: "Basic tasks")
        case .basicCategories:
            return String(localized: "Basic categories")
        case .customCategories:
            return String(localized: "Create custom categories")
        case .basicRepeats:
            return String(localized: "Basic repeats")
        case .advancedRepeats:
            return String(localized: "Advanced repeats")
        case .monthlyStatistics:
            return String(localized: "Monthly statistics")
        case .extendedStatistics:
            return String(localized: "Day / Week / Year statistics")
        case .advancedInsights:
            return String(localized: "Future advanced insights")
        }
    }

    var freeIncluded: Bool {
        switch self {
        case .basicTasks, .basicCategories, .basicRepeats, .monthlyStatistics:
            return true
        case .customCategories, .advancedRepeats, .extendedStatistics, .advancedInsights:
            return false
        }
    }

    var proIncluded: Bool {
        true
    }
}

private struct PaywallComparisonRow: View {
    let row: PaywallComparisonRowData

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(row.title)
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ComparisonAvailabilityDot(isIncluded: row.freeIncluded)
                .frame(width: 44)

            ComparisonAvailabilityDot(isIncluded: row.proIncluded)
                .frame(width: 44)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 13)
    }
}

private struct ComparisonAvailabilityDot: View {
    let isIncluded: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isIncluded ? DS.ColorToken.purple.opacity(0.12) : DS.ColorToken.controlFill)
                .frame(width: 26, height: 26)

            if isIncluded {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.purple)
            } else {
                Rectangle()
                    .fill(DS.ColorToken.textSecondary.opacity(0.45))
                    .frame(width: 8, height: 1.5)
                    .clipShape(Capsule())
            }
        }
    }
}
