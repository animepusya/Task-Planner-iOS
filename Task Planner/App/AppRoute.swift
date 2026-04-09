//
//  AppRoute.swift
//  Task Planner
//
//  Created by Codex on 24.03.2026.
//

enum AppRoute: Hashable {
    case settings
    case statisticsComparison
    case paywall(PaywallEntryPoint)

    var hidesStatisticsTabBar: Bool {
        switch self {
        case .settings, .statisticsComparison, .paywall:
            return true
        }
    }
}
