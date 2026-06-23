//
//  CardioGuardApp.swift
//  CardioGuard
//
//  iOS application entry point.
//

import SwiftUI

/// The app's composition + launch surface.
///
/// We build the live `DependencyContainer` once and inject it into the
/// environment, so every screen resolves the same shared services. Swapping
/// `.live()` for `.simulated()` here turns the whole app into a self-driving
/// demo — handy for screenshots and walkthroughs without a paired Watch.
@main
struct CardioGuardApp: App {

    /// The single, app-lifetime object graph.
    @StateObject private var container = DependencyContainer.live()

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environmentObject(container)
                .preferredColorScheme(.dark)
        }
    }
}
