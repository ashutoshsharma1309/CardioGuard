//
//  RootTabView.swift
//  CardioGuard
//
//  The tab-based shell that hosts the main screens and the emergency cover.
//

import SwiftUI

/// Root navigation shell.
///
/// Reads the shared dependencies from the environment and injects the right
/// collaborators into each screen. The emergency alert is presented as a
/// `fullScreenCover` driven by the shared `EmergencyCoordinator`, so it takes
/// over the UI **from any tab** the instant a critical assessment fires.
public struct RootTabView: View {
    @EnvironmentObject private var container: DependencyContainer

    public init() {}

    public var body: some View {
        TabView {
            DashboardView(pipeline: container.pipeline)
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }

            LiveHealthMetricsView(pipeline: container.pipeline)
                .tabItem { Label("Live", systemImage: "waveform.path.ecg") }

            RiskMonitoringView(pipeline: container.pipeline, configuration: container.engine.configuration)
                .tabItem { Label("Risk", systemImage: "exclamationmark.shield.fill") }

            SettingsView(configuration: container.engine.configuration)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.red)
        .modifier(EmergencyCoverModifier(coordinator: container.coordinator))
    }
}

/// Presents the emergency alert / dispatch full-screen cover, observing the
/// coordinator so SwiftUI reacts to `presentation` transitions.
private struct EmergencyCoverModifier: ViewModifier {
    @ObservedObject var coordinator: EmergencyCoordinator

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: isPresented) {
            switch coordinator.presentation {
            case .alert:    EmergencyAlertView()
            case .dispatch: EmergencyDispatchView()
            case .none:     EmptyView()
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { coordinator.presentation != .none },
            set: { _ in } // Dismissal driven only by explicit user actions.
        )
    }
}

#Preview {
    RootTabView()
        .environmentObject(DependencyContainer.simulated())
}
