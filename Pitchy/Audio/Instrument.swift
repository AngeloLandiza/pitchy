import Foundation

/// Playback sounds, built with additive synthesis so the app needs no sample files.
enum Instrument: String, CaseIterable, Identifiable, Codable {
    case piano
    case guitar
    case flute
    case organ
    case violin

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .piano: "pianokeys"
        case .guitar: "guitars"
        case .flute: "wind"
        case .organ: "building.columns"
        case .violin: "music.quarternote.3"
        }
    }

    /// Relative amplitude of harmonics 1, 2, 3...
    var harmonics: [Double] {
        switch self {
        case .piano: [1, 0.55, 0.3, 0.2, 0.12, 0.08, 0.05]
        case .guitar: [1, 0.7, 0.45, 0.3, 0.2, 0.12, 0.08, 0.05]
        case .flute: [1, 0.12, 0.06, 0.02]
        case .organ: [1, 0.6, 0.0, 0.35, 0.0, 0.2, 0.0, 0.12]
        case .violin: [1, 0.75, 0.55, 0.45, 0.35, 0.28, 0.2, 0.15, 0.1]
        }
    }

    /// Seconds to reach full volume.
    var attack: Double {
        switch self {
        case .piano: 0.005
        case .guitar: 0.003
        case .flute: 0.06
        case .organ: 0.02
        case .violin: 0.1
        }
    }

    /// Time constant of the natural decay, in seconds. `nil` sustains until release.
    var decay: Double? {
        switch self {
        case .piano: 0.9
        case .guitar: 0.6
        case .flute, .organ, .violin: nil
        }
    }

    /// Upper harmonics fade this many times faster than the fundamental.
    var brightnessDecay: Double {
        switch self {
        case .piano: 1.6
        case .guitar: 2.2
        case .flute, .organ, .violin: 0
        }
    }

    var vibrato: (rate: Double, depth: Double) {
        switch self {
        case .violin: (5.5, 0.003)
        case .flute: (5, 0.0015)
        default: (0, 0)
        }
    }

    var release: Double { 0.12 }
}
