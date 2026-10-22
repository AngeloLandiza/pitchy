import Foundation

/// How note names are shown to the user.
enum NoteNaming: String, CaseIterable, Identifiable, Codable {
    case letters
    case solfege

    var id: String { rawValue }

    var label: String {
        switch self {
        case .letters: "C D E"
        case .solfege: "Do Re Mi"
        }
    }
}

/// One of the 12 pitch classes, C = 0 ... B = 11.
struct PitchClass: Hashable, Codable, Identifiable, Comparable {
    let value: Int

    init(_ value: Int) {
        self.value = ((value % 12) + 12) % 12
    }

    var id: Int { value }

    static let all: [PitchClass] = (0..<12).map(PitchClass.init)
    static let naturals: [PitchClass] = [0, 2, 4, 5, 7, 9, 11].map(PitchClass.init)

    var isNatural: Bool { PitchClass.naturals.contains(self) }

    func name(_ naming: NoteNaming) -> String {
        switch naming {
        case .letters:
            ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"][value]
        case .solfege:
            ["Do", "Di", "Re", "Me", "Mi", "Fa", "Fi", "Sol", "Le", "La", "Te", "Ti"][value]
        }
    }

    static func < (lhs: PitchClass, rhs: PitchClass) -> Bool { lhs.value < rhs.value }
}

/// Pitch helpers using MIDI note numbers (60 = middle C, 69 = A4 = 440 Hz).
enum Pitch {
    static let a4: Double = 440

    static func frequency(midi: Double, transpose: Int = 0) -> Double {
        a4 * pow(2, (midi + Double(transpose) - 69) / 12)
    }

    /// Fractional MIDI number for a frequency.
    static func midi(frequency: Double) -> Double {
        69 + 12 * log2(frequency / a4)
    }

    static func pitchClass(midi: Int) -> PitchClass { PitchClass(midi) }

    static func octave(midi: Int) -> Int { midi / 12 - 1 }

    /// Signed distance in cents from `midi` to the nearest note.
    static func centsOff(frequency: Double) -> (nearest: Int, cents: Double) {
        let m = midi(frequency: frequency)
        let nearest = Int(m.rounded())
        return (nearest, (m - Double(nearest)) * 100)
    }
}

enum Interval: Int, CaseIterable, Identifiable, Codable {
    case minor2 = 1, major2, minor3, major3, perfect4, tritone, perfect5, minor6, major6, minor7, major7, octave

    var id: Int { rawValue }
    var semitones: Int { rawValue }

    var shortName: String {
        ["m2", "M2", "m3", "M3", "P4", "TT", "P5", "m6", "M6", "m7", "M7", "P8"][rawValue - 1]
    }

    var name: String {
        ["Minor 2nd", "Major 2nd", "Minor 3rd", "Major 3rd", "Perfect 4th", "Tritone",
         "Perfect 5th", "Minor 6th", "Major 6th", "Minor 7th", "Major 7th", "Octave"][rawValue - 1]
    }

    /// Order intervals are introduced in, easiest first.
    static let learningOrder: [Interval] = [
        .perfect5, .octave, .major3, .perfect4, .minor3, .major2,
        .major6, .minor6, .minor7, .major7, .minor2, .tritone,
    ]
}

/// Scale degrees of a major key, used for relative-pitch questions.
enum ScaleDegree: Int, CaseIterable, Identifiable, Codable {
    case one = 0, two = 2, three = 4, four = 5, five = 7, six = 9, seven = 11

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .one: "1"
        case .two: "2"
        case .three: "3"
        case .four: "4"
        case .five: "5"
        case .six: "6"
        case .seven: "7"
        }
    }

    var solfege: String {
        ["Do", "Re", "Mi", "Fa", "Sol", "La", "Ti"][ScaleDegree.allCases.firstIndex(of: self)!]
    }

    static let learningOrder: [ScaleDegree] = [.one, .five, .three, .four, .six, .two, .seven]
}
