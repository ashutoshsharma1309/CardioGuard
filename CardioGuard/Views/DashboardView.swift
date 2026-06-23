//
//  DashboardView.swift
//  CardioGuard
//
//  The at-a-glance home screen.
//

import SwiftUI

/// Shows current heart rate, SpO2, risk status, Watch connection, and the
/// emergency-system state.
///
/// The view receives its `MonitoringPipeline` via `init` and constructs its
/// `DashboardViewModel` once into a `@StateObject`. This keeps construction
/// explicit (the parent owns the dependency) while letting SwiftUI manage the
/// VM lifecycle across redraws.
public struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    public init(pipeline: MonitoringPipeline) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(pipeline: pipeline))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    metricGrid
                    riskCard
                    statusCard
                }
                .padding()
            }
            .navigationTitle("CardioGuard")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var metricGrid: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Heart Rate",
                value: viewModel.heartRateText,
                unit: "bpm",
                systemImage: "heart.fill",
                accent: .red
            )
            MetricCard(
                title: "Blood Oxygen",
                value: viewModel.oxygenText,
                unit: "%",
                systemImage: "lungs.fill",
                accent: .blue
            )
        }
    }

    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Risk Status").font(.headline)
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(Theme.color(for: viewModel.riskLevel))
                Text(viewModel.riskLevel.displayName)
                    .font(.title3.bold())
                Spacer()
                Text("Score \(viewModel.riskScore)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System").font(.headline)
            StatusRow(
                title: "Apple Watch",
                value: viewModel.connectionState.isConnected ? "Connected" : "Disconnected",
                color: Theme.color(for: viewModel.connectionState)
            )
            StatusRow(
                title: "Emergency System",
                value: viewModel.emergencySystemStatusText,
                color: viewModel.emergencySystemArmed ? .green : .secondary
            )
            StatusRow(title: "Last Update", value: viewModel.lastUpdated, color: .blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

#Preview {
    DashboardView(pipeline: DependencyContainer.simulated().pipeline)
}
