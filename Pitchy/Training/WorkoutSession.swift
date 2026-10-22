import Foundation
import Observation
import SwiftData

/// Drives one daily workout: picks questions, plays them, records answers.
@MainActor
@Observable
final class WorkoutSession {
    enum Phase: Equatable {
        case asking
        case feedback(correct: Bool)
        case finished
    }

    private(set) var phase: Phase = .asking
    private(set) var current: Question?
    private(set) var index = 0
    private(set) var results: [QuestionResult] = []
    private(set) var newlyUnlocked: [String] = []
    private(set) var xp = 0

    let total: Int
    private let settings: AppSettings
    private let context: ModelContext
    private var factory: QuestionFactory
    private var plan: [QuestionKind]
    private var tonic: Int
    private var questionsInKey = 0
    private var askedAt = Date()

    init(settings: AppSettings, context: ModelContext) {
        self.settings = settings
        self.context = context
        total = settings.questionsPerWorkout
        let records = Self.loadRecords(context)
        let factory = QuestionFactory(curriculum: settings.curriculum, records: records, settings: settings)
        self.factory = factory
        tonic = factory.randomTonic()
        plan = Self.makePlan(count: total, singing: settings.singingEnabled)
    }

    static func loadRecords(_ context: ModelContext) -> [String: SkillRecord] {
        let all = (try? context.fetch(FetchDescriptor<SkillRecord>())) ?? []
        return Dictionary(all.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// A shuffled mix: mostly notes, then intervals and scale degrees, a little singing.
    static func makePlan(count: Int, singing: Bool) -> [QuestionKind] {
        var kinds: [QuestionKind] = []
        let singCount = singing ? max(1, count / 8) : 0
        let rest = count - singCount
        let notes = Int((Double(rest) * 0.4).rounded())
        let intervals = (rest - notes) / 2
        let degrees = rest - notes - intervals
        kinds += Array(repeating: .noteName, count: notes)
        kinds += Array(repeating: .interval, count: intervals)
        kinds += Array(repeating: .scaleDegree, count: degrees)
        kinds += Array(repeating: .sing, count: singCount)
        return kinds.shuffled()
    }

    var progress: Double { Double(index) / Double(max(total, 1)) }
    var correctCount: Int { results.filter(\.isCorrect).count }

    func start() {
        Synth.shared.start()
        ask()
    }

    private func ask() {
        let kind = plan[index]
        if kind == .scaleDegree || kind == .sing {
            if questionsInKey >= settings.keyChange.questionsPerKey {
                tonic = factory.randomTonic(excluding: tonic)
                questionsInKey = 0
            }
            questionsInKey += 1
        }
        switch kind {
        case .noteName: current = factory.noteName()
        case .interval: current = factory.interval()
        case .scaleDegree: current = factory.scaleDegree(tonic: tonic)
        case .sing: current = factory.sing(tonic: tonic)
        }
        phase = .asking
        replay()
        askedAt = .now
    }

    /// Plays the current question's sound again.
    func replay() {
        guard let q = current else { return }
        Synth.shared.stopAll()
        let instrument = settings.instrument
        let transpose = settings.transpose
        var delay = 0.0
        if let t = q.playback.cadenceTonic {
            // Ask in the key's cadence so the ear resets to the new tonic.
            delay = Synth.shared.playCadence(tonic: t, instrument: instrument, transpose: transpose)
        }
        for note in q.playback.notes {
            Synth.shared.play(midi: note, instrument: instrument, duration: 0.8, delay: delay, transpose: transpose)
            delay += 0.75
        }
    }

    func answer(_ given: Answer?) {
        guard let q = current, phase == .asking else { return }
        record(q, given: given, correct: given == q.correct)
    }

    func singResult(correct: Bool) {
        guard let q = current, phase == .asking else { return }
        record(q, given: correct ? q.correct : nil, correct: correct)
    }

    private func record(_ q: Question, given: Answer?, correct: Bool) {
        let seconds = Date.now.timeIntervalSince(askedAt)
        results.append(QuestionResult(question: q, given: given, isCorrect: correct, seconds: seconds))
        let skill: SkillRecord
        if let existing = factory.records[q.skillKey] {
            skill = existing
        } else {
            skill = SkillRecord(key: q.skillKey)
            context.insert(skill)
            factory.records[q.skillKey] = skill
        }
        skill.record(correct: correct)
        if correct { xp += 10 }
        phase = .feedback(correct: correct)
        Haptics.answer(correct: correct)
        if !correct, q.kind != .sing {
            // Hear it again now that the right answer is showing.
            replay()
        }
    }

    func next() {
        index += 1
        if index >= total {
            finish()
        } else {
            ask()
        }
    }

    private func finish() {
        Synth.shared.stopAll()
        xp += 20
        context.insert(SessionRecord(kind: "workout", questions: results.count, correct: correctCount, xp: xp))
        var curriculum = settings.curriculum
        newlyUnlocked = curriculum.advance(records: factory.records, naming: settings.naming)
        settings.curriculum = curriculum
        try? context.save()
        current = nil
        phase = .finished
    }

    /// Short feedback on the weakest items in this workout.
    func weakSpots(naming: NoteNaming) -> [String] {
        var misses: [String: Int] = [:]
        for r in results where !r.isCorrect {
            let label = r.question.kind == .sing
                ? "Singing \(r.question.correct.label(naming))"
                : r.question.correct.label(naming)
            misses[label, default: 0] += 1
        }
        return misses.sorted { $0.value > $1.value }.prefix(3).map(\.key)
    }
}
