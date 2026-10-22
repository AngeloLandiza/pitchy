import Foundation

enum Answer: Hashable, Codable {
    case note(PitchClass)
    case interval(Interval)
    case degree(ScaleDegree)

    func label(_ naming: NoteNaming) -> String {
        switch self {
        case .note(let pc): pc.name(naming)
        case .interval(let i): i.shortName
        case .degree(let d): naming == .solfege ? d.solfege : d.label
        }
    }

    var detail: String? {
        switch self {
        case .interval(let i): i.name
        default: nil
        }
    }

    var skillKey: String {
        switch self {
        case .note(let pc): "note:\(pc.value)"
        case .interval(let i): "interval:\(i.rawValue)"
        case .degree(let d): "degree:\(d.rawValue)"
        }
    }
}

enum QuestionKind: String, Codable {
    case noteName
    case interval
    case scaleDegree
    case sing

    var title: String {
        switch self {
        case .noteName: "Name the note"
        case .interval: "Name the interval"
        case .scaleDegree: "Which scale degree?"
        case .sing: "Sing the note"
        }
    }
}

/// What the app plays for a question.
struct Playback: Equatable {
    /// Tonic for a I–IV–V–I cadence before the notes, if the question is in a key.
    var cadenceTonic: Int?
    /// Notes played one after another.
    var notes: [Int]
}

struct Question: Identifiable, Equatable {
    let id = UUID()
    let kind: QuestionKind
    let playback: Playback
    let choices: [Answer]
    let correct: Answer
    /// For singing: the pitch class to hit, in concert pitch, any octave.
    var singTarget: PitchClass?

    var skillKey: String { kind == .sing ? "sing:\(correct.skillKey)" : correct.skillKey }

    static func == (lhs: Question, rhs: Question) -> Bool { lhs.id == rhs.id }
}

/// One answered question, kept so results can show exactly what happened.
struct QuestionResult: Identifiable {
    let id = UUID()
    let question: Question
    let given: Answer?
    let isCorrect: Bool
    let seconds: Double
}
