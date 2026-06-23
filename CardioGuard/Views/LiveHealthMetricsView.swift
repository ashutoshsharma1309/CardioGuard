//
//  LiveHealthMetricsView.swift
//  CardioGuard
//
//  Real-time vitals with a rolling trend chart.
//

import SwiftUI
import Charts

/// Displays the live heart-rate and SpO2 values plus a rolling Swift Charts
/// trend of the recent buffer maintained by `LiveMetricsViewModel`.
public struct LiveHealthMetricsView: View {
    @StateObject private var viewModel: LiveMetricsViewModel

    public init(pipeline: MonitoringPipeline) {
        _viewModel = StateObject(wrappedValue: LiveMetricsViewModel(pipeline: pipeline))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    currentValues
                    heartRateChart
                    oxygenChart
                }
                .padding()
            }
            .navigationTitle("Live Metrics")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var currentValues: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Heart Rate",
                value: viewModel.currentHeartRate.map { "\(Int($0.beatsPerMinute))" } ?? "--",
                unit: "bpm",
                systemImage: "heart.fill",
                accent: viewModel.latestHeartRateClassification.map(Theme.color(for:)) ?? .red
            )
            MetricCard(
                title: "SpO₂",
                value: viewModel.currentOxygen.map { "\(Int($0.percentage))" } ?? "--",
                unit: "%",
                systemImage: "lungs.fill",
                accent: viewModel.latestOxygenClassification.map(Theme.color(for:)) ?? .blue
            )
        }
    }

    private var heartRateChart: some View {
        chartCard(title: "Heart Rate Trend") {
            Chart(viewModel.samples) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.heartRate)
                )
                .foregroundStyle(.red)
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 40...180)
            .frame(height: 160)
        }
    }

    private var oxygenChart: some View {
        chartCard(title: "Blood Oxygen Trend") {
            Chart(viewModel.samples) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("SpO₂", sample.oxygen)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 80...100)
            .frame(height: 160)
        }
    }

    @ViewBuilder
    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            if viewModel.samples.isEmpty {
                ContentUnavailableView("Waiting for data", systemImage: "waveform.path.ecg")
                    .frame(height: 160)
            } else {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

#Preview {
    LiveHealthMetricsView(pipeline: DependencyContainer.simulated().pipeline)
}
