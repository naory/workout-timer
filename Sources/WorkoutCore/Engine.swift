import Foundation

/// Clock-based workout runner. A value type with no hidden clock: every call takes `now`,
/// and elapsed time is derived from it, so ticks can be late or irregular without drift.
public struct TimerEngine: Sendable {
    public struct Status: Equatable, Sendable {
        public var segmentIndex: Int
        public var remainingInSegment: Double
        public var totalRemaining: Double
        public var isFinished: Bool
        public var isPaused: Bool
    }

    public let segments: [Segment]
    public let cues: [Cue]
    public let totalDuration: Double

    private var started = false
    /// Elapsed seconds banked before `runningSince`.
    private var accumulated: Double = 0
    /// Non-nil while running.
    private var runningSince: Date?
    /// Cues at or before this time have been delivered (or deliberately skipped).
    private var lastCueTime: Double = -1

    public init(segments: [Segment]) {
        self.segments = segments
        self.cues = Cues.schedule(segments)
        self.totalDuration = Double(segments.totalDuration)
    }

    public mutating func start(at now: Date) {
        started = true
        accumulated = 0
        runningSince = now
        lastCueTime = -1
    }

    public mutating func pause(at now: Date) {
        guard started, runningSince != nil else { return }
        accumulated = elapsed(at: now)
        runningSince = nil
    }

    public mutating func resume(at now: Date) {
        guard started, runningSince == nil, !status(at: now).isFinished else { return }
        runningSince = now
    }

    public mutating func skipForward(at now: Date) {
        guard started else { return }
        let i = status(at: now).segmentIndex
        let target = i + 1 < segments.count ? Double(segments[i + 1].start) : totalDuration
        jump(to: target, at: now)
    }

    /// Restarts the current segment if more than 2 s in, otherwise goes to the previous one.
    public mutating func skipBackward(at now: Date) {
        guard started else { return }
        let e = elapsed(at: now)
        let i = status(at: now).segmentIndex
        let segStart = Double(segments[i].start)
        let target = (e - segStart > 2 || i == 0) ? segStart : Double(segments[i - 1].start)
        jump(to: target, at: now)
    }

    public func elapsed(at now: Date) -> Double {
        guard started else { return 0 }
        let running = runningSince.map { now.timeIntervalSince($0) } ?? 0
        return min(max(accumulated + running, 0), totalDuration)
    }

    public func status(at now: Date) -> Status {
        let e = elapsed(at: now)
        let finished = started && e >= totalDuration
        let index = finished
            ? segments.count - 1
            : (segments.lastIndex { Double($0.start) <= e } ?? 0)
        let remaining = finished ? 0 : Double(segments[index].end) - e
        return Status(
            segmentIndex: index,
            remainingInSegment: remaining,
            totalRemaining: totalDuration - e,
            isFinished: finished,
            isPaused: started && runningSince == nil && !finished)
    }

    /// Cues that became due since the last call; each cue is returned at most once.
    public mutating func dueCues(at now: Date) -> [Cue] {
        guard started else { return [] }
        let e = elapsed(at: now)
        let due = cues.filter { $0.time > lastCueTime && $0.time <= e }
        lastCueTime = max(lastCueTime, e)
        return due
    }

    private mutating func jump(to target: Double, at now: Date) {
        accumulated = min(max(target, 0), totalDuration)
        if runningSince != nil { runningSince = now }
        lastCueTime = accumulated
        if accumulated >= totalDuration { runningSince = nil }
    }
}
