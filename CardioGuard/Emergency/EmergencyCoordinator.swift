//
//  EmergencyCoordinator.swift
//  CardioGuard
//
//  Orchestrates the full emergency lifecycle: alert → countdown → protocol.
//

import Foundation
import Combine

/// The state machine that owns an emergency from alert to dispatch.
///
/// ## Responsibilities
/// - Presenting the full-screen alert when a critical assessment arrives.
/// - Running the 20-second countdown and honoring user dismissal.
/// - On timeout, executing the emergency protocol *sequentially*:
///   capture location → find hospital → dispatch → notify.
///
/// ## Why `@MainActor` + `ObservableObject`?
/// This type drives UI directly (the alert and dispatch screens observe it), so
/// it lives on the main actor for safe SwiftUI mutation. All slow work
/// (location, lookups) is `await`ed off the actor inside the injected services,
/// keeping the UI responsive while state mutations stay serialized.
///
/// Every dependency is injected via protocol, so the entire flow can be
/// exercised in tests with mocks and a fake countdown — no real timers, GPS, or
/// network involved.
@MainActor
public final class EmergencyCoordinator: ObservableObject {

    // MARK: Published UI state

    /// The active emergency, or `nil` when idle. Drives `.fullScreenCover`.
    @Published public private(set) var activeEvent: EmergencyEvent?

    /// Seconds left on the countdown, surfaced to the alert screen.
    @Published public private(set) var countdownRemaining: TimeInterval = 0

    /// Phase the UI should render (alert vs. dispatch vs. hidden).
    @Published public private(set) var presentation: Presentation = .none

    public enum Presentation: Equatable, Sendable {
        case none
        case alert
        case dispatch
    }

    // MARK: Dependencies (injected)

    private let countdown: CountdownTiming
    private let locationProvider: LocationProviding
    private let hospitalLocator: HospitalLocating
    private let dispatcher: EmergencyDispatching
    private let notifications: NotificationScheduling
    private let alertDuration: TimeInterval

    private var cancellables = Set<AnyCancellable>()

    public init(
        countdown: CountdownTiming,
        locationProvider: LocationProviding,
        hospitalLocator: HospitalLocating,
        dispatcher: EmergencyDispatching,
        notifications: NotificationScheduling,
        alertDuration: TimeInterval = 20
    ) {
        self.countdown = countdown
        self.locationProvider = locationProvider
        self.hospitalLocator = hospitalLocator
        self.dispatcher = dispatcher
        self.notifications = notifications
        self.alertDuration = alertDuration

        countdown.remainingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] remaining in
                self?.countdownRemaining = remaining
            }
            .store(in: &cancellables)
    }

    // MARK: - Entry point

    /// Called by the monitoring pipeline when a critical assessment is produced.
    /// Idempotent: ignores new triggers while an emergency is already active.
    public func handleCriticalAssessment(_ assessment: RiskAssessment) {
        guard presentation == .none else {
            AppLogger.emergency.debug("Ignoring trigger; emergency already in progress")
            return
        }

        let event = EmergencyEvent(triggeringAssessment: assessment, status: .initiated)
        activeEvent = event
        presentation = .alert
        countdownRemaining = alertDuration

        AppLogger.emergency.notice("Emergency alert presented (risk \(assessment.score, privacy: .public))")

        Task { await notifications.presentCriticalAlert(
            title: "Possible cardiac emergency",
            body: assessment.summary
        ) }

        countdown.start(duration: alertDuration) { [weak self] in
            Task { @MainActor in self?.escalate() }
        }
    }

    // MARK: - User actions

    /// User confirmed they are OK ("I'm Fine" / "Dismiss"). Cancels everything.
    public func userMarkedSafe() {
        countdown.cancel()
        if var event = activeEvent {
            event.status = .resolvedByUser
            activeEvent = event
        }
        AppLogger.emergency.notice("User marked safe; emergency canceled")
        reset()
    }

    // MARK: - Escalation (the emergency protocol)

    /// Runs when the countdown expires with no user response.
    private func escalate() {
        guard var event = activeEvent, presentation == .alert else { return }
        countdown.cancel()
        presentation = .dispatch
        AppLogger.emergency.notice("No response — executing emergency protocol")

        Task { [weak self] in
            guard let self else { return }
            await self.runProtocol(&event)
        }
    }

    /// The sequential emergency protocol. Each stage updates `activeEvent` so the
    /// dispatch screen can animate progress in real time.
    private func runProtocol(_ event: inout EmergencyEvent) async {
        // Stage 1 — capture location
        event.status = .locating
        activeEvent = event
        do {
            event.location = try await locationProvider.currentLocation()
            activeEvent = event
        } catch {
            AppLogger.emergency.error("Location stage failed: \(error.localizedDescription, privacy: .public)")
            // Continue with a best-effort report even without a precise fix.
        }

        // Stage 2/3 — find nearest hospital (requires a location)
        if let location = event.location {
            event.status = .locatingHospital
            activeEvent = event
            do {
                event.nearestHospital = try await hospitalLocator.nearestHospital(to: location)
                activeEvent = event
            } catch {
                AppLogger.emergency.error("Hospital lookup failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Stage 4 — dispatch
        event.status = .dispatching
        activeEvent = event
        do {
            event.dispatch = try await dispatcher.dispatch(for: event)
            event.status = .dispatched
            activeEvent = event
            await notifications.presentEmergencyDispatched(event)
            AppLogger.emergency.notice("Emergency protocol complete")
        } catch {
            event.status = .failed
            activeEvent = event
            AppLogger.emergency.error("Dispatch stage failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// User-initiated close of the dispatch screen once the protocol has finished.
    public func acknowledgeDispatch() {
        reset()
    }

    private func reset() {
        presentation = .none
        activeEvent = nil
        countdownRemaining = 0
    }
}
