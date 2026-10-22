import Foundation
import Observation

enum KeyChangeFrequency: String, CaseIterable, Identifiable, Codable {
    case everyQuestion
    case everyFewQuestions
    case everySession

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyQuestion: "Every question"
        case .everyFewQuestions: "Every 4 questions"
        case .everySession: "Every session"
        }
    }

    var questionsPerKey: Int {
        switch self {
        case .everyQuestion: 1
        case .everyFewQuestions: 4
        case .everySession: .max
        }
    }
}

enum VoiceRange: String, CaseIterable, Identifiable, Codable {
    case low
    case high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: "Lower voice"
        case .high: "Higher voice"
        }
    }

    /// MIDI notes that are comfortable to sing.
    var range: ClosedRange<Int> {
        switch self {
        case .low: 48...64   // C3 to E4
        case .high: 57...72  // A3 to C5
        }
    }
}

/// User preferences, persisted in UserDefaults.
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: "hasOnboarded") } }
    var naming: NoteNaming { didSet { defaults.set(naming.rawValue, forKey: "naming") } }
    var instrument: Instrument { didSet { defaults.set(instrument.rawValue, forKey: "instrument") } }
    var transpose: Int { didSet { defaults.set(transpose, forKey: "transpose") } }
    var keyChange: KeyChangeFrequency { didSet { defaults.set(keyChange.rawValue, forKey: "keyChange") } }
    var singingEnabled: Bool { didSet { defaults.set(singingEnabled, forKey: "singingEnabled") } }
    /// How far off a sung note may be and still count, in cents.
    var singTolerance: Double { didSet { defaults.set(singTolerance, forKey: "singTolerance") } }
    var questionsPerWorkout: Int { didSet { defaults.set(questionsPerWorkout, forKey: "questionsPerWorkout") } }
    var lowestMidi: Int { didSet { defaults.set(lowestMidi, forKey: "lowestMidi") } }
    var highestMidi: Int { didSet { defaults.set(highestMidi, forKey: "highestMidi") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        naming = NoteNaming(rawValue: defaults.string(forKey: "naming") ?? "") ?? .letters
        instrument = Instrument(rawValue: defaults.string(forKey: "instrument") ?? "") ?? .piano
        transpose = defaults.integer(forKey: "transpose")
        keyChange = KeyChangeFrequency(rawValue: defaults.string(forKey: "keyChange") ?? "") ?? .everyFewQuestions
        singingEnabled = defaults.object(forKey: "singingEnabled") as? Bool ?? true
        singTolerance = defaults.object(forKey: "singTolerance") as? Double ?? 35
        questionsPerWorkout = defaults.object(forKey: "questionsPerWorkout") as? Int ?? 15
        lowestMidi = defaults.object(forKey: "lowestMidi") as? Int ?? 48
        highestMidi = defaults.object(forKey: "highestMidi") as? Int ?? 72
        voice = VoiceRange(rawValue: defaults.string(forKey: "voice") ?? "") ?? .low
    }

    var voice: VoiceRange { didSet { defaults.set(voice.rawValue, forKey: "voice") } }

    var curriculum: Curriculum {
        get {
            _ = curriculumVersion
            return Curriculum(
                unlockedNotes: defaults.object(forKey: "unlockedNotes") as? Int ?? Curriculum.startingCount,
                unlockedIntervals: defaults.object(forKey: "unlockedIntervals") as? Int ?? Curriculum.startingCount,
                unlockedDegrees: defaults.object(forKey: "unlockedDegrees") as? Int ?? Curriculum.startingCount
            )
        }
        set {
            defaults.set(newValue.unlockedNotes, forKey: "unlockedNotes")
            defaults.set(newValue.unlockedIntervals, forKey: "unlockedIntervals")
            defaults.set(newValue.unlockedDegrees, forKey: "unlockedDegrees")
            curriculumVersion += 1
        }
    }

    /// Bumped on every curriculum change so views that read it refresh.
    private(set) var curriculumVersion = 0

    /// Wipes progress settings back to a fresh start (keeps sound and naming choices).
    func resetProgress() {
        curriculum = Curriculum(unlockedNotes: Curriculum.startingCount, unlockedIntervals: Curriculum.startingCount, unlockedDegrees: Curriculum.startingCount)
        hasOnboarded = false
    }
}
