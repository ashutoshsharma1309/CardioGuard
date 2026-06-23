//
//  LiveMetricsViewModel.swift
//  CardioGuard
//
//  Maintains a rolling buffer of recent readings for the live-metrics charts.
//

import Foundation
import Combine

/// Keeps a bounded history of recent vitals so the live-metrics screen can draw
/// sparkline-style trends. The buffer is capped to avoid unbounded growth during
/// long monitoring sessions.
@MainActor
public final class LiveMetricsViewModel: ObservableObject {

    public struct Sample: Identifiable, Hashable {
        public let id = UUID()
        public let heartRate: Double
        public let oxygen: Double
        public let timestamp: Date
    }

    @Published public private(set) var samples: [Sample] = []
    @Published public private(set) var currentHeartRate: HeartRateReading?
    @Published public private(set) var currentOxygen: OxygenReading?

    private let pipeline: MonitoringPipeline
    private let maxSamples: Int
    private var cancellables = Set<AnyCancellable>()

    public init(pipeline: MonitoringPipeline, maxSamples: Int = 60) {
        self.pipeline = pipeline
        self.maxSamples = maxSamples
        bind()
    }

    public var latestHeartRateClassification: HeartRateClassification? {
        currentHeartRate?.classification
    }

    public var latestOxygenClassification: OxygenClassification? {
        currentOxygen?.classification
    }

    private func bind() {
        pipeline.$latestVitals
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vitals in
                guard let self else { return }
                self.currentHeartRate = vitals.heartRate
                self.currentOxygen = vitals.oxygen

                guard let hr = vitals.heartRate, let ox = vitals.oxygen else { return }
                let sample = Sample(heartRate: hr.beatsPerMinute, oxygen: ox.percentage, timestamp: vitals.capturedAt)
                self.samples.append(sample)
                if self.samples.count > self.maxSamples {
                    self.samples.removeFirst(self.samples.count - self.maxSamples)
                }
            }
            .store(in: &cancellables)
    }
}
