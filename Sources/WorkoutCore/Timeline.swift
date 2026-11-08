public enum Phase: Equatable, Sendable {
    case getReady, work, rest
}

/// One contiguous period of the workout. Indices are 0-based; times are whole seconds from workout start.
public struct Segment: Equatable, Sendable {
    public var phase: Phase
    public var start: Int
    public var duration: Int
    /// For work: the current exercise. For rest / get-ready: the upcoming exercise.
    public var exerciseName: String
    /// For work: the exercise after this one, or nil at the end of the workout.
    public var nextExerciseName: String?
    public var setIndex: Int
    public var setCount: Int
    public var setName: String
    public var repetition: Int
    public var repeatCount: Int
    public var roundIndex: Int
    public var roundCount: Int

    public var end: Int { start + duration }
}

public enum Timeline {
    public static let leadIn = 10

    /// Flattens a workout into get-ready, then work/rest pairs (set → repetition → round), without a final rest.
    public static func build(_ workout: Workout) -> [Segment] {
        let w = workout.normalized()

        // First collect every work segment, then interleave rests and the lead-in.
        var works: [Segment] = []
        for (si, set) in w.sets.enumerated() {
            for rep in 0..<set.repeats {
                for ri in set.exercises.indices {
                    works.append(Segment(
                        phase: .work, start: 0, duration: set.workSeconds,
                        exerciseName: set.displayName(ofExerciseAt: ri), nextExerciseName: nil,
                        setIndex: si, setCount: w.sets.count, setName: set.name,
                        repetition: rep, repeatCount: set.repeats,
                        roundIndex: ri, roundCount: set.exercises.count))
                }
            }
        }
        let restAfter: [Int] = w.sets.flatMap { set in
            Array(repeating: set.restSeconds, count: set.repeats * set.exercises.count)
        }

        var result: [Segment] = []
        var t = 0
        func append(_ s: Segment) {
            var s = s
            s.start = t
            t += s.duration
            result.append(s)
        }

        var lead = works[0]
        lead.phase = .getReady
        lead.duration = leadIn
        lead.nextExerciseName = nil
        append(lead)

        for i in works.indices {
            var work = works[i]
            let next = i + 1 < works.count ? works[i + 1] : nil
            work.nextExerciseName = next?.exerciseName
            append(work)
            if let next {
                // Rest belongs to the set just finished but shows the upcoming exercise.
                var rest = next
                rest.phase = .rest
                rest.duration = restAfter[i]
                rest.nextExerciseName = nil
                append(rest)
            }
        }
        return result
    }
}

extension Array where Element == Segment {
    public var totalDuration: Int { last?.end ?? 0 }
}
