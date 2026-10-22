import SwiftData
import SwiftUI

struct NoteBlitzView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    enum Phase { case ready, playing, over }

    static let duration = 30.0

    @State private var phase: Phase = .ready
    @State private var endsAt = Date()
    @State private var remaining = duration
    @State private var score = 0
    @State private var misses = 0
    @State private var note: PitchClass = PitchClass(0)
    @State private var midi = 60
    @State private var picked: Answer?

    private var pool: [PitchClass] {
        let notes = settings.curriculum.notes
        return notes.count >= 3 ? notes : Curriculum.noteOrder.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(spacing: 22) {
            switch phase {
            case .ready:
                Spacer()
                Text("Note Blitz").font(.largeTitle.weight(.bold))
                Text("30 seconds. Name each note as fast as you can. Uses the \(pool.count) notes you've unlocked.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
                PrimaryButton(title: "Go", systemImage: "bolt.fill") { start() }

            case .playing:
                HStack {
                    Label("\(score)", systemImage: "checkmark.circle.fill").foregroundStyle(Color.pitchyGood)
                    Spacer()
                    Text(String(format: "%.0f", max(0, remaining.rounded(.up))))
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                }
                .font(.title3.weight(.semibold))
                ProgressView(value: remaining, total: Self.duration).tint(.pitchy)
                ReplayButton { play() }
                Spacer(minLength: 0)
                AnswerGrid(
                    choices: pool.sorted().map(Answer.note),
                    naming: settings.naming,
                    picked: picked,
                    correct: picked == nil ? nil : .note(note),
                    onPick: { pick($0) }
                )
                Spacer(minLength: 0)

            case .over:
                Spacer()
                Text("\(score)").font(.system(size: 80, weight: .bold, design: .rounded))
                Text("notes in 30 seconds, \(misses) missed").foregroundStyle(.secondary)
                Spacer()
                PrimaryButton(title: "Play again", systemImage: "arrow.clockwise") { start() }
            }
        }
        .padding()
        .navigationTitle(phase == .playing ? "" : "Note Blitz")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: phase) {
            guard phase == .playing else { return }
            while !Task.isCancelled, phase == .playing {
                remaining = endsAt.timeIntervalSinceNow
                if remaining <= 0 { finish() }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        .onDisappear { Synth.shared.stopAll() }
    }

    private func start() {
        score = 0
        misses = 0
        endsAt = .now.addingTimeInterval(Self.duration)
        remaining = Self.duration
        phase = .playing
        newNote()
    }

    private func newNote() {
        picked = nil
        var next = pool.randomElement()!
        if pool.count > 1 { while next == note { next = pool.randomElement()! } }
        note = next
        midi = (settings.lowestMidi...settings.highestMidi).filter { PitchClass($0) == next }.randomElement() ?? 60 + next.value
        play()
    }

    private func play() {
        Synth.shared.stopAll()
        Synth.shared.play(midi: midi, instrument: settings.instrument, duration: 0.7, transpose: settings.transpose)
    }

    private func pick(_ answer: Answer) {
        guard phase == .playing, picked == nil else { return }
        picked = answer
        let correct = answer == .note(note)
        Haptics.answer(correct: correct)
        if correct { score += 1 } else { misses += 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(correct ? 250 : 900))
            if phase == .playing { newNote() }
        }
    }

    private func finish() {
        phase = .over
        Synth.shared.stopAll()
        context.insert(SessionRecord(kind: "blitz", questions: score + misses, correct: score, xp: score * 2, score: score))
        try? context.save()
    }
}
