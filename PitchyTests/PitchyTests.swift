import SwiftData
import XCTest
@testable import Pitchy

@MainActor
final class PitchyTests: XCTestCase {
    private func tone(_ frequency: Double, sampleRate: Double = 48_000, count: Int = 2048) -> [Float] {
        (0..<count).map { i in
            let t = Double(i) / sampleRate
            // A few harmonics, like a real voice or instrument.
            return Float(0.3 * sin(2 * .pi * frequency * t)
                + 0.15 * sin(4 * .pi * frequency * t)
                + 0.1 * sin(6 * .pi * frequency * t))
        }
    }

    func testYINFindsFundamentalWithinTwoCents() throws {
        for frequency in [98.0, 130.81, 220, 261.63, 440, 659.25, 987.77] {
            let estimate = try XCTUnwrap(YIN.detect(tone(frequency), sampleRate: 48_000), "\(frequency) Hz")
            let cents = 1200 * log2(estimate.frequency / frequency)
            XCTAssertLessThan(abs(cents), 2, "\(frequency) Hz read as \(estimate.frequency)")
            XCTAssertGreaterThan(estimate.confidence, 0.9)
        }
    }

    func testYINIgnoresSilence() {
        XCTAssertNil(YIN.detect([Float](repeating: 0, count: 2048), sampleRate: 48_000))
    }

    func testPitchConversions() {
        XCTAssertEqual(Pitch.frequency(midi: 69), 440, accuracy: 0.001)
        XCTAssertEqual(Pitch.midi(frequency: 261.6256), 60, accuracy: 0.001)
        XCTAssertEqual(Pitch.frequency(midi: 60, transpose: 12), 523.2511, accuracy: 0.01)
        XCTAssertEqual(PitchClass(-1).value, 11)
        XCTAssertEqual(PitchClass(4).name(.letters), "E")
        XCTAssertEqual(PitchClass(7).name(.solfege), "Sol")
    }

    func testSingingAcceptsAnyOctave() {
        let e = PitchClass(4)
        XCTAssertEqual(SingView.centsFromTarget(midi: 64, target: e), 0, accuracy: 0.001)
        XCTAssertEqual(SingView.centsFromTarget(midi: 52.2, target: e), 20, accuracy: 0.001)
        XCTAssertEqual(SingView.centsFromTarget(midi: 75.7, target: e), -30, accuracy: 0.001)
    }

    func testStreakCountsConsecutiveDays() {
        let calendar = Calendar.current
        let now = Date()
        let day: (Int) -> Date = { calendar.date(byAdding: .day, value: -$0, to: now)! }
        XCTAssertEqual(Streak.current(sessionDates: [], now: now), 0)
        XCTAssertEqual(Streak.current(sessionDates: [day(0), day(1), day(2)], now: now), 3)
        XCTAssertEqual(Streak.current(sessionDates: [day(1), day(2)], now: now), 2)
        XCTAssertEqual(Streak.current(sessionDates: [day(0), day(2)], now: now), 1)
        XCTAssertEqual(Streak.current(sessionDates: [day(3)], now: now), 0)
    }

    func testWorkoutPlanMix() {
        let plan = WorkoutSession.makePlan(count: 15, singing: true)
        XCTAssertEqual(plan.count, 15)
        XCTAssertEqual(plan.filter { $0 == .sing }.count, 1)
        XCTAssertFalse(WorkoutSession.makePlan(count: 15, singing: false).contains(.sing))
    }

    func testCurriculumUnlocksAfterMastery() throws {
        // SwiftData models need a live container, even in tests.
        let container = try ModelContainer(for: SkillRecord.self, SessionRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var curriculum = Curriculum(unlockedNotes: 3, unlockedIntervals: 3, unlockedDegrees: 3)
        var records: [String: SkillRecord] = [:]
        for pc in curriculum.notes {
            let r = SkillRecord(key: Answer.note(pc).skillKey)
            container.mainContext.insert(r)
            for _ in 0..<10 { r.record(correct: true) }
            records[r.key] = r
        }
        let unlocked = curriculum.advance(records: records, naming: .letters)
        XCTAssertEqual(curriculum.unlockedNotes, 4)
        XCTAssertEqual(curriculum.unlockedIntervals, 3)
        XCTAssertEqual(unlocked, ["note A"])
    }
}
