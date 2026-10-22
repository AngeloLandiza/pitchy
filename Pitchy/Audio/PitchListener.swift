import AVFoundation
import Observation

/// Listens to the microphone and publishes the sung pitch. Everything runs on the phone.
@Observable
final class PitchListener {
    enum Status: Equatable {
        case idle
        case listening
        case denied
        case failed(String)
    }

    private(set) var status: Status = .idle
    /// Smoothed fractional MIDI number of the current sung note, or nil when nothing clear is heard.
    private(set) var midi: Double?
    private(set) var frequency: Double?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var buffer: [Float] = []
    @ObservationIgnored private var recent: [Double] = []
    @ObservationIgnored private let windowSize = 2048
    @ObservationIgnored private let analysisQueue = DispatchQueue(label: "pitchy.pitch")

    @MainActor
    func start() async {
        guard status != .listening else { return }
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            status = .denied
            return
        }
        AudioSession.configure()

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            status = .failed("No microphone found")
            return
        }
        let sampleRate = format.sampleRate
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] pcm, _ in
            guard let self, let channel = pcm.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(pcm.frameLength)))
            self.analysisQueue.async { self.process(samples, sampleRate: sampleRate) }
        }
        do {
            engine.prepare()
            try engine.start()
            status = .listening
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        status = .idle
        midi = nil
        frequency = nil
        analysisQueue.async { [weak self] in
            self?.buffer.removeAll()
            self?.recent.removeAll()
        }
    }

    private func process(_ samples: [Float], sampleRate: Double) {
        buffer.append(contentsOf: samples)
        // Analyse overlapping windows, half a window apart.
        while buffer.count >= windowSize {
            let window = Array(buffer.prefix(windowSize))
            buffer.removeFirst(windowSize / 2)
            let estimate = YIN.detect(window, sampleRate: sampleRate)
            if let estimate, estimate.confidence > 0.8 {
                recent.append(Pitch.midi(frequency: estimate.frequency))
                if recent.count > 5 { recent.removeFirst() }
            } else {
                recent.removeAll()
            }
        }
        // A median of recent frames ignores single-frame octave jumps.
        let smoothed: Double? = recent.count >= 3 ? recent.sorted()[recent.count / 2] : nil
        DispatchQueue.main.async { [weak self] in
            self?.midi = smoothed
            self?.frequency = smoothed.map { Pitch.frequency(midi: $0) }
        }
    }
}
