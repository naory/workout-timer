public enum CueKind: Equatable, Sendable {
    case getReady(exercise: String)
    case beep
    case longBeep
}

public struct Cue: Equatable, Sendable {
    /// Seconds from workout start.
    public var time: Double
    public var kind: CueKind

    public init(time: Double, kind: CueKind) {
        self.time = time
        self.kind = kind
    }
}

public enum Cues {
    public static let getReadyLead = 10
    public static let countdownBeeps = 3

    /// Audio cues for a timeline, sorted by time (ties keep generation order).
    ///
    /// For each work segment `w` preceded by `p`:
    /// - get-ready at `max(w.start - 10, p.start (+1 if p is rest, to clear the long beep))`,
    ///   dropped if it would land at or after the first countdown beep;
    /// - beeps at `w.start - 3, -2, -1`, each only if not before `p.start`;
    /// - long beep at `w.end`.
    public static func schedule(_ segments: [Segment]) -> [Cue] {
        var cues: [Cue] = []
        for i in segments.indices where segments[i].phase == .work {
            let w = segments[i]
            let prevStart = i > 0 ? segments[i - 1].start : w.start
            let prevIsRest = i > 0 && segments[i - 1].phase == .rest

            let ready = max(w.start - getReadyLead, prevStart + (prevIsRest ? 1 : 0))
            if ready < w.start - countdownBeeps {
                cues.append(Cue(time: Double(ready), kind: .getReady(exercise: w.exerciseName)))
            }
            for k in stride(from: countdownBeeps, through: 1, by: -1) where w.start - k >= prevStart {
                cues.append(Cue(time: Double(w.start - k), kind: .beep))
            }
            cues.append(Cue(time: Double(w.end), kind: .longBeep))
        }
        return cues.enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map(\.element)
    }
}
