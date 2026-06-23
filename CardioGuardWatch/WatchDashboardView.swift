//
//  WatchDashboardView.swift
//  CardioGuardWatch
//
//  Minimal Watch UI showing live vitals and streaming status.
//

import SwiftUI

/// A compact, glanceable Watch face for CardioGuard.
///
/// The Watch UI is intentionally minimal — its job is sensing and relaying, not
/// analysis. Detailed risk insight and the emergency flow live on the iPhone.
struct WatchDashboardView: View {
    @ObservedObject var monitor: WatchVitalsMonitor

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text("\(monitor.latestHeartRate)")
                    .font(.system(.title, design: .rounded).bold())
                Text("bpm").font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "lungs.fill").foregroundStyle(.blue)
                Text("\(monitor.latestOxygen)")
                    .font(.system(.title2, design: .rounded).bold())
                Text("%").font(.caption).foregroundStyle(.secondary)
            }

            Label(
                monitor.isStreaming ? "Streaming" : "Idle",
                systemImage: monitor.isStreaming ? "dot.radiowaves.left.and.right" : "pause.circle"
            )
            .font(.caption2)
            .foregroundStyle(monitor.isStreaming ? .green : .secondary)
        }
        .padding()
    }
}

#Preview {
    WatchDashboardView(monitor: WatchVitalsMonitor(
        health: SimulatedVitalsProvider(scenario: .stableHealthy),
        connectivity: MockConnectivityManager()
    ))
}
