//
//  WatchApp.swift
//  CardioGuardWatch
//
//  watchOS application entry point.
//
//  The Watch is the *sensor tier*: it reads live heart-rate and SpO2 from
//  HealthKit and streams consolidated `VitalSigns` to the iPhone over
//  WatchConnectivity, where the risk engine runs. Keeping analysis on the phone
//  conserves Watch battery and centralizes the emergency logic.
//

import SwiftUI

@main
struct CardioGuardWatchApp: App {
    @StateObject private var monitor = WatchVitalsMonitor()

    var body: some Scene {
        WindowGroup {
            WatchDashboardView(monitor: monitor)
                .task { await monitor.start() }
        }
    }
}
