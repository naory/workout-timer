import Testing
@testable import WorkoutCore

func makeWorkout(_ sets: [(names: [String], repeats: Int, work: Int, rest: Int)]) -> Workout {
    Workout(name: "T", sets: sets.enumerated().map { i, s in
        WorkoutSet(name: "Set \(i + 1)", exercises: s.names.map { Exercise(name: $0) },
                   repeats: s.repeats, workSeconds: s.work, restSeconds: s.rest)
    })
}

@Suite struct TimelineTests {
    let segs = Timeline.build(makeWorkout([(["A1", "A2"], 2, 20, 10), (["B1"], 1, 30, 5)]))

    @Test func segmentCount() { #expect(segs.count == 10) }

    @Test func phasesOrder() {
        #expect(segs.map(\.phase) == [.getReady, .work, .rest, .work, .rest, .work, .rest, .work, .rest, .work])
    }

    @Test func noTrailingRest() {
        #expect(segs.last?.phase == .work)
        #expect(segs.last?.exerciseName == "B1")
        #expect(segs.last?.nextExerciseName == nil)
    }

    @Test func perSetTimes() {
        #expect(segs.filter { $0.phase == .work }.map(\.duration) == [20, 20, 20, 20, 30])
        #expect(segs.filter { $0.phase == .rest }.map(\.duration) == [10, 10, 10, 10])
    }

    @Test func startsContiguous() {
        #expect(segs[0].start == 0 && segs[0].duration == Timeline.leadIn && Timeline.leadIn == 10)
        for i in 1..<segs.count { #expect(segs[i].start == segs[i - 1].end) }
    }

    @Test func totalDuration() { #expect(segs.totalDuration == 160) }

    @Test func counters() {
        let s3 = segs[3]
        #expect(s3.setIndex == 0 && s3.setCount == 2 && s3.repetition == 0 && s3.roundIndex == 1 && s3.roundCount == 2)
        let s5 = segs[5]
        #expect(s5.repetition == 1 && s5.roundIndex == 0 && s5.repeatCount == 2)
        #expect(segs[9].setIndex == 1 && segs[9].setName == "Set 2")
    }

    @Test func restShowsUpcoming() {
        #expect(segs[2].exerciseName == "A2")
        #expect(segs[0].exerciseName == "A1")
        #expect(segs[1].nextExerciseName == "A2")
    }

    @Test func blankNamesUseFallback() {
        let s = Timeline.build(makeWorkout([(["", "X"], 1, 5, 5)]))
        #expect(s[1].exerciseName == "Exercise 1")
    }

    @Test func invalidWorkoutIsNormalized() {
        let s = Timeline.build(Workout(name: "empty", sets: []))
        #expect(s.map(\.phase) == [.getReady, .work])
    }
}
