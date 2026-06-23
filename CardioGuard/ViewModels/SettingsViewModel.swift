//
//  SettingsViewModel.swift
//  CardioGuard
//
//  Exposes adjustable risk thresholds and permission actions.
//

import Foundation
import Combine

/// Backing logic for the settings screen.
///
/// Demonstrates how the externalized `RiskConfiguration` lets users (or A/B
/// experiments) tune sensitivity at runtime. In a shipping app these values
/// would persist via `UserDefaults`/`AppStorage` and re-seed the engine.
@MainActor
public final class SettingsViewModel: ObservableObject {

    @Published public var highHeartRateThreshold: Double
    @Published public var lowHeartRateThreshold: Double
    @Published public var criticalOxygenThreshold: Double
    @Published public var alertCountdownSeconds: Double

    private let baseConfiguration: RiskConfiguration

    public init(configuration: RiskConfiguration) {
        self.baseConfiguration = configuration
        self.highHeartRateThreshold = configuration.highHeartRateThreshold
        self.lowHeartRateThreshold = configuration.lowHeartRateThreshold
        self.criticalOxygenThreshold = configuration.criticalOxygenThreshold
        self.alertCountdownSeconds = 20
    }

    /// Builds a new configuration reflecting the user's edits. The container can
    /// rebuild the engine from this (engines are cheap, immutable value types).
    public func makeConfiguration() -> RiskConfiguration {
        var config = baseConfiguration
        config.highHeartRateThreshold = highHeartRateThreshold
        config.lowHeartRateThreshold = lowHeartRateThreshold
        config.criticalOxygenThreshold = criticalOxygenThreshold
        return config
    }

    public func resetToDefaults() {
        let defaults = RiskConfiguration.default
        highHeartRateThreshold = defaults.highHeartRateThreshold
        lowHeartRateThreshold = defaults.lowHeartRateThreshold
        criticalOxygenThreshold = defaults.criticalOxygenThreshold
        alertCountdownSeconds = 20
    }
}
