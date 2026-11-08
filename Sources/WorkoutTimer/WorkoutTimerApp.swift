import AppKit
import SwiftUI
import WorkoutCore

@main
struct WorkoutTimerApp: App {
    @State private var store = WorkoutStore()
    @State private var run: RunController?
    @State private var sound: SoundPlayer?

    init() {
        // Launched as a bare executable (swift run) the app would otherwise stay in the background.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApplication.shared.activate() }
    }

    var body: some Scene {
        WindowGroup("Workout Timer") {
            Group {
                if let run {
                    TimerView(run: run, onClose: { self.run = nil })
                } else {
                    ContentView(store: store, onStart: start)
                }
            }
            .frame(minWidth: 760, minHeight: 560)
        }
        Settings {
            SettingsView()
        }
    }

    private func start(_ workout: Workout) {
        let player = sound ?? SoundPlayer()
        sound = player
        let controller = RunController(workout: workout, sound: player)
        run = controller
        controller.start()
    }
}
