//
//  DashboardViewModel.swift
//  CardioGuard
//
//  Presentation logic for the main dashboard.
//

import Foundation
import Combine

/// Transforms the raw `MonitoringPipeline` state into display-ready values for
/// the dashboard. The View binds only to these derived properties, keeping
/// formatting and status logic out of the SwiftUI body (MVVM separation).
@MainActor
public final class DashboardViewModel: ObservableObject {

    @Published public private(set) var heartRateText: String = "--"
    @Published public private(set) var oxygenText: String = "--"
    @Published public private(set) var riskLevel: RiskLevel = .normal
    @Published public private(set) var riskScore: Int = 0
    @Published public private(set) var connectionState: ConnectivityState = .notActivated
    @Published public private(set) var lastUpdated: String = "—"

    private let pipeline: MonitoringPipeline
    private var cancellables = Set<AnyCancellable>()

    public init(pipeline: MonitoringPipeline) {
        self.pipeline = pipeline
        bind()
    }

    /// Whether the overall emergency-monitoring system is operating nominally.
    public var emergencySystemArmed: Bool {
        connectionState.isConnected || pipeline.latestVitals.heartRate != nil
    }

    public var emergencySystemStatusText: String {
        emergencySystemArmed ? "Armed & Monitoring" : "Standby"
    }

    private func bind() {
        pipeline.$latestVitals
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vitals in
                guard let self else { return }
                if let hr = vitals.heartRate {
                    self.heartRateText = "\(Int(hr.beatsPerMinute))"
                }
                if let ox = vitals.oxygen {
                    self.oxygenText = "\(Int(ox.percentage))"
                }
                self.lastUpdated = Formatters.clock.string(from: vitals.capturedAt)
            }
            .store(in: &cancellables)

        pipeline.$latestAssessment
            .receive(on: DispatchQueue.main)
            .sink { [weak self] assessment in
                self?.riskLevel = assessment.level
                self?.riskScore = assessment.score
            }
            .store(in: &cancellables)

        pipeline.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
    }
}
