import SwiftUI

struct AssessmentView: View {
    @Environment(AppSettings.self) private var settings
    let session: AssessmentSession
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if session.isFinished {
                AssessmentResultView(session: session, onDone: onDone)
            } else if let q = session.current {
                ProgressView(value: session.progress).tint(.pitchy)
                Text(q.kind == .noteName ? "Which note is this?" : "Which interval is this?")
                    .font(.title2.weight(.bold))
                Text("No reference note. Guessing is fine.")
                    .foregroundStyle(.secondary)
                ReplayButton { session.play() }
                Spacer(minLength: 0)
                AnswerGrid(
                    choices: q.choices,
                    naming: settings.naming,
                    picked: session.answered,
                    correct: session.answered == nil ? nil : q.correct,
                    onPick: { session.answer($0) }
                )
                Spacer(minLength: 0)
                if session.answered != nil {
                    PrimaryButton(title: "Next") { session.next() }
                }
            }
        }
        .padding()
        .onAppear { session.start() }
    }
}

/// Shows the score and every single question, so the result is easy to check.
struct AssessmentResultView: View {
    @Environment(AppSettings.self) private var settings
    let session: AssessmentSession
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your starting point").font(.largeTitle.weight(.bold))
                HStack(spacing: 12) {
                    StatTile(value: "\(session.noteScore)/12", label: "notes named", systemImage: "music.note")
                    StatTile(value: "\(session.intervalScore)/\(AssessmentSession.testedIntervals.count)", label: "intervals", systemImage: "arrow.up.and.down")
                }
                Text(session.noteSummary)
                Text("This is a quick snapshot, not a diagnosis. Each question is listed below so you can see exactly how it was scored.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(Array(session.results.enumerated()), id: \.element.id) { i, r in
                        HStack {
                            Text("\(i + 1)").foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
                            Image(systemName: r.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(r.isCorrect ? Color.pitchyGood : Color.pitchyBad)
                            Text("Played \(r.question.correct.label(settings.naming))")
                            Spacer()
                            Text("You: \(r.given?.label(settings.naming) ?? "–")")
                                .foregroundStyle(r.isCorrect ? Color.primary : Color.pitchyBad)
                            Text(String(format: "%.1fs", r.seconds))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .font(.subheadline.monospacedDigit())
                        .padding(.vertical, 6)
                        Divider()
                    }
                }

                PrimaryButton(title: "Start training", action: onDone)
            }
            .padding(.vertical)
        }
    }
}
