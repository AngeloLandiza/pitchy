import SwiftUI

/// Sing a target note. Any octave counts. Hold it inside the tolerance band to pass.
struct SingView: View {
    @Environment(AppSettings.self) private var settings
    let target: PitchClass
    let degreeLabel: String
    let naming: NoteNaming
    let tolerance: Double
    let onReplay: () -> Void
    let onResult: (Bool) -> Void

    @State private var listener = PitchListener()
    @State private var holdStart: Date?
    @State private var hold: Double = 0
    @State private var done = false
    /// Ignore the mic while the cadence is playing, so the app doesn't grade its own sound.
    @State private var listenAfter = Date.now.addingTimeInterval(2.6)

    static let holdSeconds = 0.7

    /// Cents from the nearest octave of the target.
    static func centsFromTarget(midi: Double, target: PitchClass) -> Double {
        var d = (midi - Double(target.value)).truncatingRemainder(dividingBy: 12)
        if d < 0 { d += 12 }
        if d >= 6 { d -= 12 }
        return d * 100
    }

    private var cents: Double? {
        guard Date.now >= listenAfter, let m = listener.midi else { return nil }
        return Self.centsFromTarget(midi: m, target: target)
    }

    var body: some View {
        VStack(spacing: 22) {
            Text("Sing \(degreeLabel)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("Listen to the key, then sing or hum. Any octave is fine.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            switch listener.status {
            case .denied:
                Text("Pitchy needs the microphone for singing questions. Turn it on in Settings, or switch singing off in Pitchy's settings.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.pitchyBad)
            case .failed(let message):
                Text(message).foregroundStyle(Color.pitchyBad)
            default:
                VStack(spacing: 10) {
                    TunerNeedle(cents: cents, tolerance: tolerance)
                    HStack {
                        Text("Flat").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(heardLabel).font(.headline.monospacedDigit())
                        Spacer()
                        Text("Sharp").font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: hold).tint(.pitchyGood)
                }
            }

            HStack(spacing: 12) {
                ReplayButton {
                    listenAfter = .now.addingTimeInterval(2.6)
                    onReplay()
                }
                Button("Skip") {
                    finish(false)
                }
                .buttonStyle(.bordered)
            }
        }
        .task { await run() }
        .onDisappear { listener.stop() }
    }

    private var heardLabel: String {
        guard let m = listener.midi, Date.now >= listenAfter else { return "Listening…" }
        let written = PitchClass(Int(m.rounded()) - settings.transpose)
        return "You: \(written.name(naming))"
    }

    @MainActor
    private func run() async {
        await listener.start()
        while !Task.isCancelled && !done {
            try? await Task.sleep(for: .milliseconds(50))
            if let c = cents, abs(c) <= tolerance {
                let start = holdStart ?? .now
                holdStart = start
                hold = min(1, Date.now.timeIntervalSince(start) / Self.holdSeconds)
                if hold >= 1 { finish(true) }
            } else {
                holdStart = nil
                hold = 0
            }
        }
    }

    @MainActor
    private func finish(_ ok: Bool) {
        guard !done else { return }
        done = true
        listener.stop()
        onResult(ok)
    }
}
