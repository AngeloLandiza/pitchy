import Foundation
import SwiftData

/// Running accuracy for one trainable item, like "note:7" or "interval:4".
@Model
final class SkillRecord {
    @Attribute(.unique) var key: String
    var attempts: Int
    var correct: Int
    /// Exponentially weighted accuracy, 0...1, that favours recent answers.
    var recentAccuracy: Double
    var lastSeen: Date

    init(key: String) {
        self.key = key
        attempts = 0
        correct = 0
        recentAccuracy = 0.5
        lastSeen = .distantPast
    }

    var accuracy: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }

    func record(correct isCorrect: Bool, at date: Date = .now) {
        attempts += 1
        if isCorrect { correct += 1 }
        recentAccuracy = recentAccuracy * 0.8 + (isCorrect ? 0.2 : 0)
        lastSeen = date
    }
}

/// One finished workout, assessment or game.
@Model
final class SessionRecord {
    var date: Date
    var kind: String
    var questions: Int
    var correct: Int
    var xp: Int
    var score: Int

    init(date: Date = .now, kind: String, questions: Int, correct: Int, xp: Int, score: Int = 0) {
        self.date = date
        self.kind = kind
        self.questions = questions
        self.correct = correct
        self.xp = xp
        self.score = score
    }

    var accuracy: Double { questions == 0 ? 0 : Double(correct) / Double(questions) }
}

enum Streak {
    /// Consecutive days with at least one session, counting back from today (or yesterday).
    static func current(sessionDates: [Date], calendar: Calendar = .current, now: Date = .now) -> Int {
        let days = Set(sessionDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
