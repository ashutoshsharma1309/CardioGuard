//
//  AlertTimerManager.swift
//  CardioGuard
//
//  Drives the 20-second countdown on the emergency alert screen.
//

import Foundation
import Combine

/// A cancelable countdown that ticks every second and fires `onExpire` at zero.
///
/// Implemented behind `CountdownTiming` so the emergency flow can be tested with
/// a synchronous fake clock rather than waiting 20 real seconds. The production
/// implementation uses a Combine `Timer` publisher on the main run loop.
public final class AlertTimerManager: CountdownTiming, @unchecked Sendable {

    private let remainingSubject = CurrentValueSubject<TimeInterval, Never>(0)
    public var remainingPublisher: AnyPublisher<TimeInterval, Never> {
        remainingSubject.eraseToAnyPublisher()
    }

    private let tickInterval: TimeInterval
    private var cancellable: AnyCancellable?
    private var expiry: Date?
    private var onExpire: (@Sendable () -> Void)?

    public init(tickInterval: TimeInterval = 1.0) {
        self.tickInterval = tickInterval
    }

    public func start(duration: TimeInterval, onExpire: @escaping @Sendable () -> Void) {
        cancel()
        self.onExpire = onExpire
        let deadline = Date().addingTimeInterval(duration)
        self.expiry = deadline
        remainingSubject.send(duration)

        cancellable = Timer.publish(every: tickInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    public func cancel() {
        cancellable?.cancel()
        cancellable = nil
        expiry = nil
        onExpire = nil
    }

    private func tick() {
        guard let expiry else { return }
        let remaining = max(0, expiry.timeIntervalSinceNow)
        remainingSubject.send(remaining)

        if remaining <= 0 {
            let callback = onExpire
            cancel()
            AppLogger.emergency.notice("Countdown expired — escalating")
            callback?()
        }
    }
}
