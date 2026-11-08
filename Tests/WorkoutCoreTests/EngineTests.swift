import Foundation
import Testing
@testable import WorkoutCore

private func cues(rest: Int, work: Int = 20) -> [Cue] {
    Cues.schedule(Timeline.build(makeWorkout([(["X"], 2, work, rest)])))
}
private func times(_ cs: [Cue], _ match: (CueKind) -> Bool) -> [Double] {
    cs.filter { match($0.kind) }.map(\.time)
}
private let isBeep: @Sendable (CueKind) -> Bool = { $0 == .beep }
private let isLong: @Sendable (CueKind) -> Bool = { $0 == .longBeep }
private let isReady: @Sendable (CueKind) -> Bool = { if case .getReady = $0 { true } else { false } }

private let t0 = Date(timeIntervalSince1970: 0)
private func basicEngine() -> TimerEngine {
    TimerEngine(segments: Timeline.build(makeWorkout([(["X"], 2, 20, 15)])))
}

@Suite struct CueTests {
    @Test func cuesBasic() {
        let c = cues(rest: 15)
        #expect(times(c, isReady) == [0, 35])
        #expect(times(c, isBeep) == [7, 8, 9, 42, 43, 44])
        #expect(times(c, isLong) == [30, 65])
        #expect(c.first?.kind == .getReady(exercise: "X"))
        #expect(c.map(\.time) == c.map(\.time).sorted())
    }

    @Test func cuesShortRest() {
        let c = cues(rest: 6)
        #expect(times(c, isReady) == [0, 31])
        #expect(times(c, isBeep) == [7, 8, 9, 33, 34, 35])
    }

    @Test func cuesTinyRest() {
        let c = cues(rest: 4)
        #expect(times(c, isReady) == [0])
        #expect(times(c, isBeep) == [7, 8, 9, 31, 32, 33])
    }

    @Test func cuesTwoSecondRest() {
        let c = cues(rest: 2)
        #expect(times(c, isReady) == [0])
        #expect(times(c, isBeep) == [7, 8, 9, 30, 31])
    }
}

@Suite struct EngineTests {
    @Test func notStartedIsAtZero() {
        let e = basicEngine()
        #expect(e.elapsed(at: t0 + 100) == 0)
        #expect(e.status(at: t0).segmentIndex == 0)
    }

    @Test func statusAtTime() {
        var e = basicEngine()
        e.start(at: t0)
        let s = e.status(at: t0 + 12)
        #expect(s.segmentIndex == 1)
        #expect(s.remainingInSegment == 18)
        #expect(s.totalRemaining == 53)
        #expect(!s.isFinished && !s.isPaused)
    }

    @Test func pauseFreezesTimeAndCues() {
        var e = basicEngine()
        e.start(at: t0)
        #expect(e.dueCues(at: t0) == [Cue(time: 0, kind: .getReady(exercise: "X"))])
        e.pause(at: t0 + 5)
        #expect(e.status(at: t0 + 50).isPaused)
        #expect(e.dueCues(at: t0 + 50) == [])
        e.resume(at: t0 + 100)
        let s = e.status(at: t0 + 102)
        #expect(s.segmentIndex == 0 && s.remainingInSegment == 3)
        #expect(e.dueCues(at: t0 + 103.5) == [Cue(time: 7, kind: .beep), Cue(time: 8, kind: .beep)])
        #expect(e.dueCues(at: t0 + 103.5) == [])
    }

    @Test func skipClamps() {
        var e = basicEngine()
        e.start(at: t0)
        _ = e.dueCues(at: t0)
        e.skipBackward(at: t0 + 1)
        #expect(e.elapsed(at: t0 + 1) == 0)
        e.skipForward(at: t0 + 1)
        #expect(e.elapsed(at: t0 + 1) == 10)
        #expect(e.dueCues(at: t0 + 1) == [])  // skipped beeps 7,8,9 are not replayed
        for _ in 0..<10 { e.skipForward(at: t0 + 1) }
        #expect(e.status(at: t0 + 1).isFinished)
        #expect(e.status(at: t0 + 1).segmentIndex == 3)
    }

    @Test func skipBackwardRestartsOrGoesPrevious() {
        var e = basicEngine()
        e.start(at: t0)
        e.skipBackward(at: t0 + 15)          // 5 s into work → restart work
        #expect(e.elapsed(at: t0 + 15) == 10)
        e.skipBackward(at: t0 + 16)          // 1 s into work → previous segment
        #expect(e.elapsed(at: t0 + 16) == 0)
    }

    @Test func skipWhilePausedStaysPaused() {
        var e = basicEngine()
        e.start(at: t0)
        e.pause(at: t0 + 2)
        e.skipForward(at: t0 + 3)
        #expect(e.elapsed(at: t0 + 60) == 10)
        #expect(e.status(at: t0 + 60).isPaused)
    }

    @Test func finishedAtEnd() {
        var e = basicEngine()
        e.start(at: t0)
        let s = e.status(at: t0 + 65 + 50)
        #expect(s.isFinished)
        #expect(s.totalRemaining == 0)
        #expect(s.remainingInSegment == 0)
    }

    @Test func finalLongBeepFires() {
        var e = basicEngine()
        e.start(at: t0)
        _ = e.dueCues(at: t0 + 64)
        #expect(e.dueCues(at: t0 + 200) == [Cue(time: 65, kind: .longBeep)])
    }
}
