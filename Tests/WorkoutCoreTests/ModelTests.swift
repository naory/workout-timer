import Foundation
import Testing
@testable import WorkoutCore

@Suite struct ModelTests {
    @Test func clampWork() {
        let s = WorkoutSet(name: "S", exercises: [Exercise(name: "A")], repeats: 0, workSeconds: 0, restSeconds: 99999).normalized()
        #expect(s.workSeconds == 1)
        #expect(s.restSeconds == 3600)
        #expect(s.repeats == 1)
    }

    @Test func emptySetGetsExercise() {
        let s = WorkoutSet(name: "S", exercises: [], repeats: 1, workSeconds: 10, restSeconds: 10).normalized()
        #expect(s.exercises.count == 1)
    }

    @Test func emptyWorkoutGetsSet() {
        #expect(Workout(name: "x", sets: []).normalized().sets.count == 1)
    }

    @Test func displayNameFallback() {
        let s = WorkoutSet(name: "S", exercises: [Exercise(name: " Squats "), Exercise(name: "  ")], repeats: 1, workSeconds: 10, restSeconds: 10)
        #expect(s.displayName(ofExerciseAt: 0) == "Squats")
        #expect(s.displayName(ofExerciseAt: 1) == "Exercise 2")
    }

    @Test func codableRoundTrip() throws {
        let w = Workout.sample
        let data = try JSONEncoder().encode(w)
        #expect(try JSONDecoder().decode(Workout.self, from: data) == w)
    }

    @Test func sampleShape() {
        let w = Workout.sample
        #expect(w.sets.count == 2)
        #expect(w.sets[0].exercises.map(\.name) == ["Squats", "Push-ups", "Plank"])
        #expect(w.sets[1].workSeconds == 40 && w.sets[1].restSeconds == 20)
    }

    @Test func updateMissingIdIsNoOp() {
        var sets = Workout.sample.sets
        let before = sets
        sets.update(id: UUID()) { $0.name = "changed" }
        #expect(sets == before)
    }

    @Test func updateExistingId() {
        var sets = Workout.sample.sets
        sets.update(id: sets[1].id) { $0.name = "changed" }
        #expect(sets[1].name == "changed")
    }
}
