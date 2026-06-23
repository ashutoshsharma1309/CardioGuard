//
//  Theme.swift
//  CardioGuard
//
//  Centralized colors and styling derived from domain state.
//

import SwiftUI

/// App-wide visual constants and state→color mappings.
///
/// Keeping these in one place (rather than scattering hex values across views)
/// makes the medical color semantics consistent and easy to audit.
public enum Theme {

    public static let cardCornerRadius: CGFloat = 16
    public static let cardPadding: CGFloat = 16

    public static func color(for level: RiskLevel) -> Color {
        switch level {
        case .normal:   return .green
        case .elevated: return .yellow
        case .high:     return .orange
        case .critical: return .red
        }
    }

    public static func color(for classification: HeartRateClassification) -> Color {
        switch classification {
        case .normal:               return .green
        case .low, .elevated:       return .orange
        case .criticallyLow, .criticallyHigh: return .red
        }
    }

    public static func color(for classification: OxygenClassification) -> Color {
        switch classification {
        case .normal:   return .green
        case .low:      return .orange
        case .critical: return .red
        }
    }

    public static func color(for state: ConnectivityState) -> Color {
        state.isConnected ? .green : .secondary
    }
}
