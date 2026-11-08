import Foundation

/// Allowed ranges for user-editable values. Anything outside is clamped, never rejected.
public enum Limits {
    public static let seconds = 1...3600
    public static let repeats = 1...99

    public static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

/// One round: an exercise slot inside a set. Timing comes from the set.
public struct Exercise: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// An ordered list of rounds that repeats `repeats` times, all using the same work/rest times.
public struct WorkoutSet: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var exercises: [Exercise]
    public var repeats: Int
    public var workSeconds: Int
    public var restSeconds: Int

    public init(id: UUID = UUID(), name: String, exercises: [Exercise], repeats: Int, workSeconds: Int, restSeconds: Int) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.repeats = repeats
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
    }

    /// Clamps all values into `Limits` and guarantees at least one exercise.
    public func normalized() -> WorkoutSet {
        var s = self
        s.repeats = Limits.clamp(repeats, Limits.repeats)
        s.workSeconds = Limits.clamp(workSeconds, Limits.seconds)
        s.restSeconds = Limits.clamp(restSeconds, Limits.seconds)
        if s.exercises.isEmpty { s.exercises = [Exercise(name: "")] }
        return s
    }

    /// The trimmed exercise name, or "Exercise N" (1-based) when blank.
    public func displayName(ofExerciseAt index: Int) -> String {
        let trimmed = exercises.indices.contains(index)
            ? exercises[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        return trimmed.isEmpty ? "Exercise \(index + 1)" : trimmed
    }

    public static func makeDefault(name: String = "Set 1", workSeconds: Int = 30, restSeconds: Int = 30) -> WorkoutSet {
        WorkoutSet(name: name, exercises: [Exercise(name: "")], repeats: 1, workSeconds: workSeconds, restSeconds: restSeconds)
    }
}

/// A sequence of sets, each with its own times and repeat count.
public struct Workout: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var sets: [WorkoutSet]

    public init(id: UUID = UUID(), name: String, sets: [WorkoutSet]) {
        self.id = id
        self.name = name
        self.sets = sets
    }

    /// Normalizes every set and guarantees at least one set.
    public func normalized() -> Workout {
        var w = self
        w.sets = sets.map { $0.normalized() }
        if w.sets.isEmpty { w.sets = [WorkoutSet.makeDefault()] }
        return w
    }

    public static var sample: Workout {
        let names = ["Squats", "Push-ups", "Plank"]
        return Workout(name: "Sample HIIT", sets: [
            WorkoutSet(name: "Set 1", exercises: names.map { Exercise(name: $0) }, repeats: 2, workSeconds: 30, restSeconds: 30),
            WorkoutSet(name: "Set 2", exercises: names.map { Exercise(name: $0) }, repeats: 2, workSeconds: 40, restSeconds: 20),
        ])
    }
}

extension Array where Element: Identifiable {
    /// Mutates the element with `id` in place; does nothing if no element has that id.
    public mutating func update(id: Element.ID, _ body: (inout Element) -> Void) {
        guard let i = firstIndex(where: { $0.id == id }) else { return }
        body(&self[i])
    }
}
