import AVFoundation
import WorkoutCore

/// Plays cue sounds from pre-rendered tone buffers, plus an optional spoken "Get ready".
@MainActor
final class SoundPlayer {
    static let speakKey = "speakGetReady"

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var nodes: [String: AVAudioPlayerNode] = [:]
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private let speech = AVSpeechSynthesizer()

    init() {
        UserDefaults.standard.register(defaults: [Self.speakKey: true])
        add("beep", ToneSynth.samples(frequency: ToneSynth.beep.frequency, duration: ToneSynth.beep.duration))
        add("long", ToneSynth.samples(frequency: ToneSynth.longBeep.frequency, duration: ToneSynth.longBeep.duration))
        add("chime", ToneSynth.chime())
        try? engine.start()
    }

    func play(_ kind: CueKind) {
        switch kind {
        case .beep:
            playBuffer("beep")
        case .longBeep:
            playBuffer("long")
        case .getReady(let exercise):
            playBuffer("chime")
            if UserDefaults.standard.bool(forKey: Self.speakKey) {
                speech.stopSpeaking(at: .immediate)
                let utterance = AVSpeechUtterance(string: "Get ready. \(exercise)")
                utterance.preUtteranceDelay = 0.45  // let the chime finish first
                speech.speak(utterance)
            }
        }
    }

    func stopAll() {
        speech.stopSpeaking(at: .immediate)
        nodes.values.forEach { $0.stop() }
    }

    private func add(_ name: String, _ samples: [Float]) {
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        nodes[name] = node

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        buffers[name] = buffer
    }

    private func playBuffer(_ name: String) {
        guard let node = nodes[name], let buffer = buffers[name] else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }
}
