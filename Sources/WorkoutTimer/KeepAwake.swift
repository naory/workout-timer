import Foundation

/// Prevents the display from sleeping while active. Idempotent begin/end.
@MainActor
final class KeepAwake {
    private var activity: NSObjectProtocol?

    func begin() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .userInitiated],
            reason: "Workout timer running")
    }

    func end() {
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }
}
