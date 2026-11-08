import Testing
@testable import WorkoutCore

@Suite struct ToneSynthTests {
    let s = ToneSynth.samples(frequency: 880, duration: 0.15, sampleRate: 44100, amplitude: 0.5)

    @Test func length() { #expect(s.count == 6615) }
    @Test func fadesInAndOut() {
        #expect(s.first == 0)
        #expect(abs(s.last!) < 0.01)
    }
    @Test func amplitude() {
        let peak = s.map(abs).max()!
        #expect(peak <= 0.5 && peak > 0.47)
    }
    @Test func concatenated() {
        let chime = ToneSynth.chime(sampleRate: 1000)
        #expect(chime.count == 150 + 250)
    }
}
