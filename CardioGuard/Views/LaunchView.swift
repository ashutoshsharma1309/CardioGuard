//
//  LaunchView.swift
//  CardioGuard
//
//  Branded launch / warm-up screen shown while monitoring spins up.
//

import SwiftUI

/// The first screen the user sees. Besides branding, it provides a natural place
/// to kick off authorization requests before revealing the dashboard.
public struct LaunchView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var isReady = false

    public init() {}

    public var body: some View {
        ZStack {
            if isReady {
                RootTabView()
                    .transition(.opacity)
            } else {
                splash
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isReady)
        .task { await warmUp() }
    }

    private var splash: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 88))
                .foregroundStyle(.red)
                .symbolEffect(.pulse)
            Text("CardioGuard")
                .font(.largeTitle.bold())
            Text("Continuous cardiac safety monitoring")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView().padding(.top, 8)
        }
    }

    /// Requests permissions and starts the pipeline, then reveals the UI.
    private func warmUp() async {
        try? await container.notifications.requestAuthorization()
        container.locationProvider.requestAuthorization()
        container.startMonitoring()
        // Brief, deliberate splash so branding registers.
        try? await Task.sleep(for: .seconds(1))
        isReady = true
    }
}

#Preview {
    LaunchView()
        .environmentObject(DependencyContainer.simulated())
}
