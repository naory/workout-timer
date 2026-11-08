import Foundation
import Observation
import WorkoutCore

/// Drives a TimerEngine from a 20 Hz UI timer and plays its cues. Runs a snapshot of the workout.
@MainActor @Observable
final class RunController {
    let workout: Workout
    private(set) var status: TimerEngine.Status

    @ObservationIgnored private var engine: TimerEngine
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let sound: SoundPlayer
    @ObservationIgnored private let keepAwake = KeepAwake()

    init(workout: Workout, sound: SoundPlayer) {
        self.workout = workout
        self.sound = sound
        self.engine = TimerEngine(segments: Timeline.build(workout))
        self.status = engine.status(at: Date())
    }

    var segment: Segment { engine.segments[status.segmentIndex] }
    var totalDuration: Double { engine.totalDuration }
    var progress: Double { totalDuration > 0 ? 1 - status.totalRemaining / totalDuration : 1 }

    func start() {
        engine.start(at: Date())
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        keepAwake.begin()
        tick()
    }

    func togglePause() {
        let now = Date()
        if status.isPaused {
            engine.resume(at: now)
            keepAwake.begin()
        } else {
            engine.pause(at: now)
            keepAwake.end()
        }
        tick()
    }

    func skipForward() {
        engine.skipForward(at: Date())
        tick()
    }

    func skipBackward() {
        engine.skipBackward(at: Date())
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        keepAwake.end()
        sound.stopAll()
    }

    private func tick() {
        let now = Date()
        for cue in engine.dueCues(at: now) {
            sound.play(cue.kind)
        }
        status = engine.status(at: now)
        if status.isFinished {
            timer?.invalidate()
            timer = nil
            keepAwake.end()
        }
    }
}
