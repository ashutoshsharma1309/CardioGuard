//
//  RiskMonitoringView.swift
//  CardioGuard
//
//  Live risk score, level, and the factors explaining it.
//

import SwiftUI

/// Renders the current `RiskAssessment` as a gauge plus an itemized,
/// human-readable breakdown of every contributing factor — reinforcing the
/// engine's transparency goal.
public struct RiskMonitoringView: View {
    @StateObject private var viewModel: RiskMonitoringViewModel

    public init(pipeline: MonitoringPipeline, configuration: RiskConfiguration) {
        _viewModel = StateObject(wrappedValue: RiskMonitoringViewModel(pipeline: pipeline, configuration: configuration))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    gauge
                    factorList
                }
                .padding()
            }
            .navigationTitle("Risk Monitor")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var gauge: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: viewModel.normalizedScore)
                    .stroke(
                        Theme.color(for: viewModel.assessment.level),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: viewModel.normalizedScore)
                VStack {
                    Text("\(viewModel.assessment.score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text(viewModel.assessment.level.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.color(for: viewModel.assessment.level))
                }
            }
            .frame(width: 180, height: 180)

            if viewModel.isCritical {
                Label("Critical — emergency alert active", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var factorList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contributing Factors").font(.headline)
            if viewModel.factors.isEmpty {
                ContentUnavailableView(
                    "All Clear",
                    systemImage: "checkmark.seal.fill",
                    description: Text("All vitals are within normal range.")
                )
            } else {
                ForEach(viewModel.factors, id: \.code) { factor in
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text(factor.explanation)
                            .font(.subheadline)
                        Spacer()
                        Text("+\(factor.points)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

#Preview {
    RiskMonitoringView(
        pipeline: DependencyContainer.simulated(scenario: .suddenCritical).pipeline,
        configuration: .default
    )
}
