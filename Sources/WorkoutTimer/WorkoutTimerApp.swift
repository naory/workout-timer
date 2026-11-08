import AppKit
import SwiftUI
import WorkoutCore

@main
struct WorkoutTimerApp: App {
    @State private var store = WorkoutStore()
    @State private var running: Workout?

    init() {
        // Launched as a bare executable (swift run) the app would otherwise stay in the background.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApplication.shared.activate() }
    }

    var body: some Scene {
        WindowGroup("Workout Timer") {
            ContentView(store: store, onStart: { running = $0 })
                .frame(minWidth: 760, minHeight: 520)
        }
    }
}
