//
//  NotificationManager.swift
//  CardioGuard
//
//  UserNotifications wrapper for critical alerts and dispatch confirmations.
//

import Foundation
import UserNotifications

/// Schedules local notifications for emergency events.
///
/// Uses the **critical alert** interruption level so notifications break through
/// Focus / silent mode — appropriate for a life-safety product (requires the
/// `com.apple.developer.usernotifications.critical-alerts` entitlement in prod).
public final class NotificationManager: NotificationScheduling, @unchecked Sendable {

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async throws {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
            guard granted else { throw CardioGuardError.notificationAuthorizationDenied }
            AppLogger.emergency.info("Notification authorization granted")
        } catch let error as CardioGuardError {
            throw error
        } catch {
            throw CardioGuardError.notificationAuthorizationDenied
        }
    }

    public func presentCriticalAlert(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.interruptionLevel = .critical
        content.sound = .defaultCritical
        await deliver(content, identifier: "cardioguard.alert.\(UUID().uuidString)")
    }

    public func presentEmergencyDispatched(_ event: EmergencyEvent) async {
        let content = UNMutableNotificationContent()
        content.title = "Emergency services notified"
        if let hospital = event.nearestHospital, let dispatch = event.dispatch {
            content.body = "\(hospital.name) • Ref \(dispatch.referenceCode) • ETA \(hospital.estimatedTravelMinutes) min"
        } else {
            content.body = "An emergency report has been dispatched."
        }
        content.interruptionLevel = .critical
        content.sound = .defaultCritical
        await deliver(content, identifier: "cardioguard.dispatch.\(event.id.uuidString)")
    }

    private func deliver(_ content: UNNotificationContent, identifier: String) async {
        // nil trigger => deliver immediately.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        do {
            try await center.add(request)
        } catch {
            AppLogger.emergency.error("Failed to deliver notification: \(error.localizedDescription, privacy: .public)")
        }
    }
}
