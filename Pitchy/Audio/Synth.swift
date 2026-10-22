import AVFoundation
import os

/// Plays notes through an AVAudioSourceNode. Notes are scheduled in samples, so sequences
/// and chords stay in time no matter how busy the main thread is.
final class Synth {
    static let shared = Synth()

    private struct Voice {
        var frequency: Double
        var startSample: Int64
        var lengthSamples: Int64
        var harmonics: [Double]
        var attack: Double
        var decay: Double?
        var brightnessDecay: Double
        var vibrato: (rate: Double, depth: Double)
        var release: Double
        var gain: Double
        var phase: Double = 0
    }

    private struct State {
        var sample: Int64 = 0
        var voices: [Voice] = []
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let state = OSAllocatedUnfairLock(uncheckedState: State())
    private var sampleRate: Double = 44_100

    private init() {}

    func start() {
        guard sourceNode == nil else { return }
        AudioSession.configure()
        let format = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = format.sampleRate > 0 ? format.sampleRate : 44_100
        let sr = sampleRate
        let mono = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!

        let node = AVAudioSourceNode(format: mono) { [state] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let frames = Int(frameCount)
            for i in 0..<frames { out[i] = 0 }

            state.withLockUnchecked { s in
                let blockStart = s.sample
                for v in s.voices.indices {
                    var voice = s.voices[v]
                    for i in 0..<frames {
                        let n = blockStart + Int64(i) - voice.startSample
                        if n < 0 { continue }
                        let t = Double(n) / sr
                        let held = Double(voice.lengthSamples) / sr
                        // Envelope: attack, optional exponential decay, release after the note ends.
                        var env = min(1, t / max(voice.attack, 0.0001))
                        if let decay = voice.decay { env *= exp(-t / decay) }
                        if t > held { env *= max(0, 1 - (t - held) / voice.release) }
                        if env <= 0 { continue }

                        var vib = 1.0
                        if voice.vibrato.rate > 0 {
                            vib += voice.vibrato.depth * sin(2 * .pi * voice.vibrato.rate * t) * min(1, t / 0.3)
                        }
                        voice.phase += 2 * .pi * voice.frequency * vib / sr
                        if voice.phase > 2 * .pi * 1000 { voice.phase -= 2 * .pi * 1000 }

                        var sample = 0.0
                        for (h, amp) in voice.harmonics.enumerated() where amp > 0 {
                            let k = Double(h + 1)
                            if voice.frequency * k > sr / 2.2 { break }
                            var a = amp
                            if voice.brightnessDecay > 0, let decay = voice.decay {
                                a *= exp(-t * Double(h) * voice.brightnessDecay / (decay * 4))
                            }
                            sample += a * sin(voice.phase * k)
                        }
                        out[i] += Float(sample * env * voice.gain)
                    }
                    s.voices[v] = voice
                }
                s.sample += Int64(frames)
                // Drop voices that have fully released.
                let now = s.sample
                s.voices.removeAll { v in
                    now - v.startSample > v.lengthSamples + Int64((v.release + 0.05) * sr)
                }
            }
            // Soft clip so chords never distort.
            for i in 0..<frames { out[i] = tanhf(out[i]) }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: mono)
        engine.mainMixerNode.outputVolume = 0.8
        sourceNode = node
        try? engine.start()
    }

    private func ensureRunning() {
        if sourceNode == nil { start() }
        if !engine.isRunning { try? engine.start() }
    }

    /// Plays one MIDI note after `delay` seconds.
    func play(midi: Int, instrument: Instrument, duration: Double = 0.9, delay: Double = 0, transpose: Int = 0, gain: Double = 0.28) {
        ensureRunning()
        let sr = sampleRate
        let harmonics = instrument.harmonics
        let norm = 1 / harmonics.reduce(0, +).squareRoot()
        let voice = Voice(
            frequency: Pitch.frequency(midi: Double(midi), transpose: transpose),
            startSample: 0,
            lengthSamples: Int64(duration * sr),
            harmonics: harmonics.map { $0 * norm },
            attack: instrument.attack,
            decay: instrument.decay,
            brightnessDecay: instrument.brightnessDecay,
            vibrato: instrument.vibrato,
            release: instrument.release,
            gain: gain
        )
        state.withLockUnchecked { s in
            var v = voice
            // A little lead time keeps the first note from being clipped.
            v.startSample = s.sample + Int64((delay + 0.02) * sr)
            s.voices.append(v)
        }
    }

    func playChord(_ midis: [Int], instrument: Instrument, duration: Double = 0.8, delay: Double = 0, transpose: Int = 0) {
        for m in midis {
            play(midi: m, instrument: instrument, duration: duration, delay: delay, transpose: transpose, gain: 0.18)
        }
    }

    /// A I–IV–V–I cadence that sets up a key by ear. Returns its length in seconds.
    @discardableResult
    func playCadence(tonic: Int, instrument: Instrument, transpose: Int = 0) -> Double {
        let chords = [[0, 4, 7], [0, 5, 9], [-1, 2, 7], [0, 4, 7]]
        let step = 0.55
        for (i, chord) in chords.enumerated() {
            playChord(chord.map { tonic + $0 }, instrument: instrument, duration: step * 0.9, delay: Double(i) * step, transpose: transpose)
        }
        return Double(chords.count) * step + 0.3
    }

    func stopAll() {
        state.withLockUnchecked { $0.voices.removeAll() }
    }
}

enum AudioSession {
    static func configure() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
        try? session.setActive(true)
    }
}
