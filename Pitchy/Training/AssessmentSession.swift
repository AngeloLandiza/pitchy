import Foundation
import Observation
import SwiftData

/// A transparent starting test: every note once, plus a few intervals, all choices always shown.
/// Results list every question so nothing about the score is hidden.
@MainActor
@Observable
final class AssessmentSession {
    private(set) var questions: [Question]
    private(set) var index = 0
    private(set) var results: [QuestionResult] = []
    private(set) var isFinished = false
    private(set) var answered: Answer?

    private let settings: AppSettings
    private let context: ModelContext
    private var askedAt = Date()

    static let testedIntervals: [Interval] = [.perfect5, .major3, .perfect4, .minor3, .major6, .minor2]

    init(settings: AppSettings, context: ModelContext) {
        self.settings = settings
        self.context = context
        let noteQuestions = PitchClass.all.shuffled().map { pc -> Question in
            let options = (48...72).filter { PitchClass($0) == pc }
            return Question(
                kind: .noteName,
                playback: Playback(cadenceTonic: nil, notes: [options.randomElement()!]),
                choices: PitchClass.all.map(Answer.note),
                correct: .note(pc)
            )
        }
        let intervalQuestions = Self.testedIntervals.shuffled().map { interval -> Question in
            let root = Int.random(in: 52...62)
            return Question(
                kind: .interval,
                playback: Playback(cadenceTonic: nil, notes: [root, root + interval.semitones]),
                choices: Interval.allCases.map(Answer.interval),
                correct: .interval(interval)
            )
        }
        questions = noteQuestions + intervalQuestions
    }

    var current: Question? { isFinished ? nil : questions[index] }
    var progress: Double { Double(index) / Double(questions.count) }

    func start() {
        Synth.shared.start()
        play()
    }

    func play() {
        guard let q = current else { return }
        Synth.shared.stopAll()
        var delay = 0.0
        for note in q.playback.notes {
            Synth.shared.play(midi: note, instrument: settings.instrument, duration: 0.8, delay: delay, transpose: settings.transpose)
            delay += 0.75
        }
        askedAt = .now
    }

    func answer(_ given: Answer) {
        guard let q = current, answered == nil else { return }
        answered = given
        results.append(QuestionResult(question: q, given: given, isCorrect: given == q.correct, seconds: Date.now.timeIntervalSince(askedAt)))
        Haptics.answer(correct: given == q.correct)
    }

    func next() {
        answered = nil
        index += 1
        if index >= questions.count {
            finish()
        } else {
            play()
        }
    }

    var noteScore: Int { results.filter { $0.question.kind == .noteName && $0.isCorrect }.count }
    var intervalScore: Int { results.filter { $0.question.kind == .interval && $0.isCorrect }.count }

    /// Plain description of the note score. No labels like "near absolute pitch", just what happened.
    var noteSummary: String {
        switch noteScore {
        case 12: "You named all 12 notes with no reference. That's what absolute pitch looks like."
        case 9...11: "You named \(noteScore) of 12 notes with no reference. That's a strong sense of pitch."
        case 5...8: "You named \(noteScore) of 12 notes. Workouts will start with the naturals and build up."
        default: "You named \(noteScore) of 12 notes. That's normal: most people start here. Workouts begin with 3 notes."
        }
    }

    private func finish() {
        isFinished = true
        Synth.shared.stopAll()
        var curriculum = settings.curriculum
        curriculum.unlockedNotes = noteScore >= 10 ? 12 : noteScore >= 6 ? 7 : Curriculum.startingCount
        curriculum.unlockedIntervals = min(12, max(Curriculum.startingCount, intervalScore * 2))
        settings.curriculum = curriculum
        context.insert(SessionRecord(kind: "assessment", questions: results.count, correct: results.filter(\.isCorrect).count, xp: 0))
        try? context.save()
    }
}
