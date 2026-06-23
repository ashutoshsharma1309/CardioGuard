//
//  RiskMonitoringViewModel.swift
//  CardioGuard
//
//  Surfaces the current assessment and its contributing factors.
//

import Foundation
import Combine

/// Drives the risk-monitoring screen: the live score, the level, and the
/// itemized factors that explain it. Mirrors the engine's transparency goal —
/// the user always sees *why* their risk is what it is.
@MainActor
public final class RiskMonitoringViewModel: ObservableObject {

    @Published public private(set) var assessment: RiskAssessment = .baseline()

    private let pipeline: MonitoringPipeline
    private let configuration: RiskConfiguration
    private var cancellables = Set<AnyCancellable>()

    public init(pipeline: MonitoringPipeline, configuration: RiskConfiguration) {
        self.pipeline = pipeline
        self.configuration = configuration
        pipeline.$latestAssessment
            .receive(on: DispatchQueue.main)
            .assign(to: &$assessment)
    }

    /// Normalized progress (0...1) of the score toward the critical threshold,
    /// for a gauge/progress UI.
    public var normalizedScore: Double {
        min(1.0, Double(assessment.score) / Double(max(1, configuration.criticalScoreCutoff)))
    }

    public var factors: [RiskFactor] {
        // Hide zero-point quality factors from the primary list; they still log.
        assessment.triggeredFactors.filter { $0.points > 0 }
    }

    public var isCritical: Bool { assessment.level.requiresEmergencyAlert }
}
