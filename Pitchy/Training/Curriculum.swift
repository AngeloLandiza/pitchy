import Foundation

/// Which items are unlocked, and how new ones open up as you master the current set.
struct Curriculum {
    static let noteOrder: [PitchClass] = [0, 7, 4, 9, 5, 2, 11, 6, 10, 3, 8, 1].map(PitchClass.init)
    static let startingCount = 3
    static let masteryAttempts = 6
    static let masteryAccuracy = 0.7

    var unlockedNotes: Int
    var unlockedIntervals: Int
    var unlockedDegrees: Int

    var notes: [PitchClass] { Array(Self.noteOrder.prefix(unlockedNotes)) }
    var intervals: [Interval] { Array(Interval.learningOrder.prefix(unlockedIntervals)) }
    var degrees: [ScaleDegree] { Array(ScaleDegree.learningOrder.prefix(unlockedDegrees)) }

    /// Unlocks the next item in any track where every current item is mastered.
    /// Returns the names of anything newly unlocked.
    mutating func advance(records: [String: SkillRecord], naming: NoteNaming) -> [String] {
        func mastered(_ keys: [String]) -> Bool {
            keys.allSatisfy { key in
                guard let r = records[key] else { return false }
                return r.attempts >= Self.masteryAttempts && r.recentAccuracy >= Self.masteryAccuracy
            }
        }
        var unlocked: [String] = []
        if unlockedNotes < 12, mastered(notes.map { Answer.note($0).skillKey }) {
            unlocked.append("note \(Self.noteOrder[unlockedNotes].name(naming))")
            unlockedNotes += 1
        }
        if unlockedIntervals < 12, mastered(intervals.map { Answer.interval($0).skillKey }) {
            unlocked.append(Interval.learningOrder[unlockedIntervals].name)
            unlockedIntervals += 1
        }
        if unlockedDegrees < 7, mastered(degrees.map { Answer.degree($0).skillKey }) {
            let d = ScaleDegree.learningOrder[unlockedDegrees]
            unlocked.append("degree \(naming == .solfege ? d.solfege : d.label)")
            unlockedDegrees += 1
        }
        return unlocked
    }
}

/// Builds questions, weighting the items you get wrong most often.
struct QuestionFactory {
    var curriculum: Curriculum
    var records: [String: SkillRecord]
    var settings: AppSettings
    var rng = SystemRandomNumberGenerator()

    /// Picks an item, favouring weak and rarely seen ones.
    mutating func weightedPick<T>(_ items: [T], key: (T) -> String) -> T {
        let weights = items.map { item -> Double in
            guard let r = records[key(item)] else { return 1.5 }
            let unfamiliar = r.attempts < 3 ? 0.6 : 0
            return (1 - r.recentAccuracy) + 0.15 + unfamiliar
        }
        let total = weights.reduce(0, +)
        var x = Double.random(in: 0..<total, using: &rng)
        for (item, w) in zip(items, weights) {
            x -= w
            if x < 0 { return item }
        }
        return items[items.count - 1]
    }

    private func midi(for pc: PitchClass, in range: ClosedRange<Int>) -> Int {
        let options = range.filter { PitchClass($0) == pc }
        return options.randomElement() ?? 60 + pc.value
    }

    private var playRange: ClosedRange<Int> {
        let low = min(settings.lowestMidi, settings.highestMidi - 12)
        return low...settings.highestMidi
    }

    mutating func noteName() -> Question {
        let pc = weightedPick(curriculum.notes) { Answer.note($0).skillKey }
        return Question(
            kind: .noteName,
            playback: Playback(cadenceTonic: nil, notes: [midi(for: pc, in: playRange)]),
            choices: curriculum.notes.sorted().map(Answer.note),
            correct: .note(pc)
        )
    }

    mutating func interval() -> Question {
        let interval = weightedPick(curriculum.intervals) { Answer.interval($0).skillKey }
        let low = playRange.lowerBound
        let root = Int.random(in: low...(max(low, playRange.upperBound - interval.semitones)), using: &rng)
        let ascending = Bool.random(using: &rng) || interval == .octave
        let notes = ascending ? [root, root + interval.semitones] : [root + interval.semitones, root]
        return Question(
            kind: .interval,
            playback: Playback(cadenceTonic: nil, notes: notes),
            choices: curriculum.intervals.sorted { $0.rawValue < $1.rawValue }.map(Answer.interval),
            correct: .interval(interval)
        )
    }

    mutating func scaleDegree(tonic: Int) -> Question {
        let degree = weightedPick(curriculum.degrees) { Answer.degree($0).skillKey }
        let pc = PitchClass(tonic + degree.rawValue)
        let range = (tonic - 5)...(tonic + 12)
        return Question(
            kind: .scaleDegree,
            playback: Playback(cadenceTonic: tonic, notes: [midi(for: pc, in: range)]),
            choices: curriculum.degrees.sorted { $0.rawValue < $1.rawValue }.map(Answer.degree),
            correct: .degree(degree)
        )
    }

    /// Sing a scale degree after hearing the key. Any octave counts.
    mutating func sing(tonic: Int) -> Question {
        let degree = weightedPick(curriculum.degrees) { "sing:" + Answer.degree($0).skillKey }
        let concertTonic = tonic + settings.transpose
        return Question(
            kind: .sing,
            playback: Playback(cadenceTonic: tonic, notes: []),
            choices: [],
            correct: .degree(degree),
            singTarget: PitchClass(concertTonic + degree.rawValue)
        )
    }

    /// A tonic in a comfortable middle register, avoiding the current one.
    func randomTonic(excluding current: Int? = nil) -> Int {
        var options = Array(53...64)
        if let current { options.removeAll { PitchClass($0) == PitchClass(current) } }
        return options.randomElement()!
    }
}
