import SwiftUI

struct WorkoutView: View {
    @Environment(AppSettings.self) private var settings
    let session: WorkoutSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    Synth.shared.stopAll()
                    onClose()
                } label: {
                    Image(systemName: "xmark").font(.headline)
                }
                .accessibilityLabel("End workout")
                ProgressView(value: session.progress)
                    .tint(.pitchy)
                Text("\(session.xp) XP")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding()

            if session.phase == .finished {
                WorkoutSummaryView(session: session, onDone: onClose)
            } else if let q = session.current {
                QuestionView(session: session, question: q)
                    .id(q.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.current?.id)
        .onAppear { session.start() }
    }
}

private struct QuestionView: View {
    @Environment(AppSettings.self) private var settings
    let session: WorkoutSession
    let question: Question
    @State private var picked: Answer?

    private var isFeedback: Bool {
        if case .feedback = session.phase { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(question.kind.title)
                .font(.title2.weight(.bold))
            if question.kind == .scaleDegree {
                Text("Listen to the key, then name the last note.")
                    .foregroundStyle(.secondary)
            }

            if question.kind == .sing, let target = question.singTarget {
                SingView(target: target, degreeLabel: question.correct.label(settings.naming), naming: settings.naming, tolerance: settings.singTolerance, onReplay: { session.replay() }) { ok in
                    session.singResult(correct: ok)
                }
                .disabled(isFeedback)
            } else {
                ReplayButton { session.replay() }
                Spacer(minLength: 0)
                AnswerGrid(
                    choices: question.choices,
                    naming: settings.naming,
                    picked: picked,
                    correct: isFeedback ? question.correct : nil
                ) { answer in
                    picked = answer
                    session.answer(answer)
                }
            }

            Spacer(minLength: 0)

            if case .feedback(let correct) = session.phase {
                VStack(spacing: 12) {
                    Label(correct ? "Correct" : "The answer was \(question.correct.label(settings.naming))",
                          systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(correct ? Color.pitchyGood : Color.pitchyBad)
                    PrimaryButton(title: "Continue") { session.next() }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
        .animation(.easeOut(duration: 0.2), value: isFeedback)
    }
}

private struct WorkoutSummaryView: View {
    @Environment(AppSettings.self) private var settings
    let session: WorkoutSession
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Workout done").font(.largeTitle.weight(.bold))
                HStack(spacing: 12) {
                    StatTile(value: "\(session.correctCount)/\(session.results.count)", label: "correct", systemImage: "checkmark.circle")
                    StatTile(value: "+\(session.xp)", label: "XP", systemImage: "star.fill")
                }

                if !session.newlyUnlocked.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Unlocked", systemImage: "lock.open.fill").font(.headline)
                        ForEach(session.newlyUnlocked, id: \.self) { Text($0) }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.pitchy.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }

                let weak = session.weakSpots(naming: settings.naming)
                if !weak.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Practice next").font(.headline)
                        Text(weak.joined(separator: ", "))
                        Text("Your next workout will ask about these more often.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Every question").font(.headline)
                    ForEach(session.results) { r in
                        HStack {
                            Image(systemName: r.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(r.isCorrect ? Color.pitchyGood : Color.pitchyBad)
                            Text(r.question.kind.title).foregroundStyle(.secondary)
                            Spacer()
                            Text(r.question.correct.label(settings.naming)).fontWeight(.semibold)
                            if !r.isCorrect, let given = r.given {
                                Text("you: \(given.label(settings.naming))").foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)
                    }
                }

                PrimaryButton(title: "Done", action: onDone)
            }
            .padding()
        }
    }
}
