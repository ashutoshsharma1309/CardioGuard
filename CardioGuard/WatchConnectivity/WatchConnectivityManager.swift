//
//  WatchConnectivityManager.swift
//  CardioGuard
//
//  Bidirectional Watch ↔ iPhone transport, isolated behind `DeviceConnectivity`.
//

import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Wraps `WCSession` for sending/receiving `VitalSigns`.
///
/// The same class runs on **both** targets: the Watch extension calls
/// `send(vitals:)` to push live samples; the iPhone observes
/// `receivedVitalsPublisher`. By encoding the domain model to JSON we keep the
/// wire format explicit and versionable rather than relying on ad-hoc dictionaries.
public final class WatchConnectivityManager: NSObject, DeviceConnectivity, @unchecked Sendable {

    private let vitalsSubject = PassthroughSubject<VitalSigns, Never>()
    private let stateSubject = CurrentValueSubject<ConnectivityState, Never>(.notActivated)

    public var receivedVitalsPublisher: AnyPublisher<VitalSigns, Never> {
        vitalsSubject.eraseToAnyPublisher()
    }
    public var connectionStatePublisher: AnyPublisher<ConnectivityState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Payload key used for the encoded `VitalSigns`.
    private static let vitalsKey = "vitals"

    public override init() {
        super.init()
    }

    public func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            AppLogger.connectivity.error("WCSession not supported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        AppLogger.connectivity.info("WCSession activation requested")
        #endif
    }

    public func send(vitals: VitalSigns) {
        #if canImport(WatchConnectivity)
        guard let data = try? encoder.encode(vitals) else {
            AppLogger.connectivity.error("Failed to encode vitals")
            return
        }
        let session = WCSession.default
        let payload: [String: Any] = [Self.vitalsKey: data]

        // Prefer a live message when reachable (lowest latency); otherwise fall
        // back to `transferUserInfo`, which queues and delivers in the background.
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                AppLogger.connectivity.error("sendMessage failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            session.transferUserInfo(payload)
        }
        #endif
    }

    private func handleReceived(_ payload: [String: Any]) {
        guard let data = payload[Self.vitalsKey] as? Data,
              let vitals = try? decoder.decode(VitalSigns.self, from: data) else { return }
        vitalsSubject.send(vitals)
    }
}

#if canImport(WatchConnectivity)
extension WatchConnectivityManager: WCSessionDelegate {

    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            AppLogger.connectivity.error("Activation error: \(error.localizedDescription, privacy: .public)")
        }
        stateSubject.send(state == .activated ? .activated : .inactive)
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        stateSubject.send(session.isReachable ? .reachable : .unreachable)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceived(message)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleReceived(userInfo)
    }

    // iOS-only delegate requirements. Re-activate so a newly paired Watch keeps working.
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        stateSubject.send(.inactive)
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        stateSubject.send(.notActivated)
        session.activate()
    }
    #endif
}
#endif
