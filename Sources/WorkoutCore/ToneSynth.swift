import Foundation

/// Generates the app's cue sounds as mono Float PCM, so no audio files are needed.
public enum ToneSynth {
    public static let beep = (frequency: 880.0, duration: 0.15)
    public static let longBeep = (frequency: 660.0, duration: 0.8)

    /// A sine tone with linear fade-in/out (default 10 ms) to avoid clicks.
    public static func samples(frequency: Double, duration: Double, sampleRate: Double = 44100,
                               amplitude: Float = 0.5, fade: Double = 0.01) -> [Float] {
        let count = Int((duration * sampleRate).rounded())
        let fadeCount = max(Int(fade * sampleRate), 1)
        return (0..<count).map { i in
            let edge = min(i, count - 1 - i)
            let envelope = Float(min(Double(edge) / Double(fadeCount), 1))
            return amplitude * envelope * Float(sin(2 * Double.pi * frequency * Double(i) / sampleRate))
        }
    }

    /// Rising two-note "get ready" chime: C5 for 0.15 s, then G5 for 0.25 s.
    public static func chime(sampleRate: Double = 44100) -> [Float] {
        samples(frequency: 523.25, duration: 0.15, sampleRate: sampleRate)
            + samples(frequency: 783.99, duration: 0.25, sampleRate: sampleRate)
    }
}
