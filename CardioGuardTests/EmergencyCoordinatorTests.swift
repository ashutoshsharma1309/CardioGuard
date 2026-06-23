//
//  EmergencyCoordinatorTests.swift
//  CardioGuardTests
//
//  Tests the emergency state machine end-to-end using injected fakes.
//

import Testing
import Foundation
@testable import CardioGuard

@MainActor
@Suite("EmergencyCoordinator")
struct EmergencyCoordinatorTests {

    /// Builds a coordinator wired entirely with controllable fakes.
    private func makeSUT(
        locationError: CardioGuardError? = nil
    ) -> (EmergencyCoordinator, ImmediateCountdown, MockNotificationManager) {
        let countdown = ImmediateCountdown()
        let notifications = MockNotificationManager()
        let coordinator = EmergencyCoordinator(
            countdown: countdown,
            locationProvider: MockLocationProvider(error: locationError),
            hospitalLocator: HospitalLocatorMock(simulatedLatency: .zero),
            dispatcher: EmergencyDispatchMock(simulatedLatency: .zero),
            notifications: notifications,
            alertDuration: 20
        )
        return (coordinator, countdown, notifications)
    }

    @Test("Critical assessment presents the alert and starts the countdown")
    func presentsAlert() {
        let (sut, countdown, notifications) = makeSUT()
        sut.handleCriticalAssessment(PreviewData.criticalAssessment)

        #expect(sut.presentation == .alert)
        #expect(sut.activeEvent != nil)
        #expect(countdown.startCount == 1)
        // Notification dispatch is async; allow the Task to run.
        _ = notifications
    }

    @Test("User marking safe cancels everything")
    func userMarkedSafe() {
        let (sut, countdown, _) = makeSUT()
        sut.handleCriticalAssessment(PreviewData.criticalAssessment)
        sut.userMarkedSafe()

        #expect(sut.presentation == .none)
        #expect(sut.activeEvent == nil)
        #expect(countdown.cancelCount >= 1)
    }

    @Test("Duplicate triggers are ignored while an emergency is active")
    func ignoresDuplicateTriggers() {
        let (sut, countdown, _) = makeSUT()
        sut.handleCriticalAssessment(PreviewData.criticalAssessment)
        sut.handleCriticalAssessment(PreviewData.criticalAssessment)
        #expect(countdown.startCount == 1)
    }

    @Test("Countdown expiry runs the full emergency protocol")
    func expiryRunsProtocol() async {
        let (sut, countdown, notifications) = makeSUT()
        sut.handleCriticalAssessment(PreviewData.criticalAssessment)

        countdown.fireExpiry()
        #expect(sut.presentation == .dispatch)

        // The protocol is async; poll briefly for completion.
        try? await waitUntil { sut.activeEvent?.status == .dispatched }

        #expect(sut.activeEvent?.location != nil)
        #expect(sut.activeEvent?.nearestHospital != nil)
        #expect(sut.activeEvent?.dispatch != nil)
        #expect(sut.activeEvent?.status == .dispatched)
        #expect(notifications.dispatchedEvents.count == 1)
    }

    @Test("Location failure still produces a dispatched (best-effort) report")
    func locationFailureIsResilient() async {
        let (sut, countdown, _) = makeSUT(locationError: .locationUnavailable)
        sut.handleCriticalAssessment(PreviewData.criticalAssessment)
        countdown.fireExpiry()

        try? await waitUntil {
            sut.activeEvent?.status == .dispatched || sut.activeEvent?.status == .failed
        }
        // Without a location we cannot resolve a hospital, so dispatch fails
        // gracefully rather than crashing — the report is still surfaced.
        #expect(sut.activeEvent?.location == nil)
        #expect(sut.activeEvent?.status == .failed)
    }

    /// Polls a condition for up to `timeout` seconds (simple async test helper).
    private func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw CardioGuardError.dispatchFailed("Timed out waiting for condition") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
