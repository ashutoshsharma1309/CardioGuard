//
//  SettingsView.swift
//  CardioGuard
//
//  Adjustable thresholds, permissions, and app info.
//

import SwiftUI

/// Lets the user tune sensitivity (demonstrating the externalized
/// `RiskConfiguration`) and review system status. In a shipping app these edits
/// would persist and re-seed the engine; here they showcase the configurability.
public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    public init(configuration: RiskConfiguration) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(configuration: configuration))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Heart Rate Thresholds") {
                    slider(
                        title: "High alert above",
                        value: $viewModel.highHeartRateThreshold,
                        range: 100...200,
                        unit: "bpm"
                    )
                    slider(
                        title: "Low alert below",
                        value: $viewModel.lowHeartRateThreshold,
                        range: 30...60,
                        unit: "bpm"
                    )
                }

                Section("Blood Oxygen") {
                    slider(
                        title: "Critical below",
                        value: $viewModel.criticalOxygenThreshold,
                        range: 80...95,
                        unit: "%"
                    )
                }

                Section("Emergency") {
                    slider(
                        title: "Alert countdown",
                        value: $viewModel.alertCountdownSeconds,
                        range: 10...60,
                        unit: "s"
                    )
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        viewModel.resetToDefaults()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "100")
                    Text("CardioGuard is a portfolio demonstration. It does not provide medical advice and must not replace professional emergency services.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func slider(title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: 1)
                .tint(.red)
        }
    }
}

#Preview {
    SettingsView(configuration: .default)
}
