import SwiftData
import SwiftUI

/// Game state for Pitch Pilot. Positions: x runs 0...1 across the screen, y is a MIDI note.
@MainActor
@Observable
final class PilotGame {
    struct Gate: Identifiable {
        let id = UUID()
        var x: Double
        let midi: Int
        var scored = false
    }

    static let playerX = 0.25
    static let gapHalfHeight = 0.9 // semitones
    static let speed = 0.22 // screen widths per second
    static let spawnEvery = 2.6

    let range: ClosedRange<Double>
    private let notes: [Int]
    private(set) var playerMidi: Double
    private(set) var gates: [Gate] = []
    private(set) var score = 0
    private(set) var lives = 3
    private(set) var isOver = false
    private var lastUpdate: Date?
    private var sinceSpawn = PilotGame.spawnEvery

    init(voice: ClosedRange<Int>) {
        range = Double(voice.lowerBound - 2)...Double(voice.upperBound + 2)
        // Natural notes in the singer's range.
        notes = voice.filter { PitchClass($0).isNatural }
        playerMidi = Double(voice.lowerBound + voice.upperBound) / 2
    }

    /// Advances the game. `voice` is the sung MIDI note, or nil when silent.
    /// Returns a note to play when a new gate appears.
    func update(now: Date, voice: Double?) -> Int? {
        guard !isOver else { return nil }
        let dt = min(0.05, lastUpdate.map { now.timeIntervalSince($0) } ?? 0)
        lastUpdate = now

        if let voice {
            // Glide toward the sung pitch so small wobbles don't jerk the plane.
            playerMidi += (voice.clamped(to: range) - playerMidi) * min(1, dt * 10)
        } else {
            playerMidi = max(range.lowerBound, playerMidi - dt * 3)
        }

        for i in gates.indices {
            gates[i].x -= Self.speed * dt
            if !gates[i].scored && gates[i].x <= Self.playerX {
                gates[i].scored = true
                if abs(playerMidi - Double(gates[i].midi)) <= Self.gapHalfHeight {
                    score += 1
                    Haptics.tap()
                } else {
                    lives -= 1
                    Haptics.answer(correct: false)
                    if lives <= 0 { isOver = true }
                }
            }
        }
        gates.removeAll { $0.x < -0.1 }

        sinceSpawn += dt
        if sinceSpawn >= Self.spawnEvery, let midi = notes.randomElement() {
            sinceSpawn = 0
            gates.append(Gate(x: 1.05, midi: midi))
            return midi
        }
        return nil
    }
}

extension Double {
    func clamped(to r: ClosedRange<Double>) -> Double { Swift.min(Swift.max(self, r.lowerBound), r.upperBound) }
}

struct PitchPilotView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @State private var listener = PitchListener()
    @State private var game: PilotGame?

    var body: some View {
        VStack(spacing: 16) {
            if let game {
                HStack {
                    Label("\(game.score)", systemImage: "checkmark.circle.fill").foregroundStyle(Color.pitchyGood)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < game.lives ? "heart.fill" : "heart")
                                .foregroundStyle(Color.pitchyBad)
                        }
                    }
                }
                .font(.title3.weight(.semibold))

                PilotCanvas(game: game, naming: settings.naming, transpose: settings.transpose)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                if listener.status == .denied {
                    Text("Pitch Pilot needs the microphone. Turn it on in the Settings app.")
                        .foregroundStyle(Color.pitchyBad)
                } else if game.isOver {
                    Text("Score: \(game.score)").font(.title.weight(.bold))
                    PrimaryButton(title: "Fly again", systemImage: "arrow.clockwise") { start() }
                } else {
                    Text("Sing or hum the note on each gate. Silence makes you sink.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Spacer()
                Text("Pitch Pilot").font(.largeTitle.weight(.bold))
                Text("Your voice steers. Sing higher to climb, lower to dive, and fly through each gap. Three misses and it's over.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
                PrimaryButton(title: "Take off", systemImage: "airplane") { start() }
            }
        }
        .padding()
        .navigationTitle("Pitch Pilot")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: game.map { ObjectIdentifier($0) }) { await loop() }
        .onDisappear {
            listener.stop()
            Synth.shared.stopAll()
        }
    }

    private func start() {
        game = PilotGame(voice: settings.voice.range)
    }

    private func loop() async {
        guard let game else { return }
        await listener.start()
        while !Task.isCancelled, !game.isOver {
            // Mic reads concert pitch; gates are written in concert pitch too.
            if let note = game.update(now: .now, voice: listener.midi) {
                Synth.shared.play(midi: note, instrument: settings.instrument, duration: 0.5, gain: 0.18)
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
        if game.isOver {
            context.insert(SessionRecord(kind: "pilot", questions: game.score + 3, correct: game.score, xp: game.score * 2, score: game.score))
            try? context.save()
        }
    }
}

private struct PilotCanvas: View {
    let game: PilotGame
    let naming: NoteNaming
    let transpose: Int

    var body: some View {
        // Read the moving parts here so the view redraws whenever they change.
        let gates = game.gates
        let playerMidi = game.playerMidi
        Canvas { ctx, size in
            let span = game.range.upperBound - game.range.lowerBound
            func y(_ midi: Double) -> CGFloat {
                size.height * (1 - (midi - game.range.lowerBound) / span)
            }
            let gapHeight = size.height * PilotGame.gapHalfHeight * 2 / span

            for gate in gates {
                let x = gate.x * size.width
                let center = y(Double(gate.midi))
                let wall = Color.pitchy.opacity(gate.scored ? 0.25 : 0.7)
                ctx.fill(Path(CGRect(x: x - 9, y: 0, width: 18, height: center - gapHeight / 2)), with: .color(wall))
                ctx.fill(Path(CGRect(x: x - 9, y: center + gapHeight / 2, width: 18, height: size.height)), with: .color(wall))
                let label = Text(PitchClass(gate.midi - transpose).name(naming))
                    .font(.headline)
                    .foregroundStyle(Color.pitchy)
                ctx.draw(label, at: CGPoint(x: x + 24, y: center))
            }

            let player = CGPoint(x: PilotGame.playerX * size.width, y: y(playerMidi))
            ctx.fill(Path(ellipseIn: CGRect(x: player.x - 13, y: player.y - 13, width: 26, height: 26)), with: .color(.pitchyGood))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
