import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query(sort: \SessionRecord.date, order: .reverse) private var sessions: [SessionRecord]
    @State private var workout: WorkoutSession?

    private var streak: Int { Streak.current(sessionDates: sessions.map(\.date)) }
    private var totalXP: Int { sessions.reduce(0) { $0 + $1.xp } }
    private var trainedToday: Bool {
        sessions.contains { $0.kind == "workout" && Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        StatTile(value: "\(streak)", label: "day streak", systemImage: "flame.fill")
                        StatTile(value: "\(totalXP)", label: "total XP", systemImage: "star.fill")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(trainedToday ? "Nice, today's done" : "Today's workout")
                            .font(.title2.weight(.bold))
                        Text("\(settings.questionsPerWorkout) questions on notes, intervals and scale degrees, aimed at what you miss most. About 5 minutes.")
                            .foregroundStyle(.secondary)
                        PrimaryButton(title: trainedToday ? "Train again" : "Start workout", systemImage: "play.fill") {
                            let session = WorkoutSession(settings: settings, context: context)
                            workout = session
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

                    CurriculumCard(curriculum: settings.curriculum, naming: settings.naming)
                }
                .padding()
            }
            .navigationTitle("Pitchy")
        }
        .fullScreenCover(item: $workout) { session in
            WorkoutView(session: session) { workout = nil }
        }
    }
}

extension WorkoutSession: Identifiable {}

/// What's unlocked so far in each track.
struct CurriculumCard: View {
    let curriculum: Curriculum
    let naming: NoteNaming

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What you're learning").font(.headline)
            row("Notes", "\(curriculum.unlockedNotes) of 12", curriculum.notes.map { $0.name(naming) })
            row("Intervals", "\(curriculum.unlockedIntervals) of 12", curriculum.intervals.map(\.shortName))
            row("Scale degrees", "\(curriculum.unlockedDegrees) of 7", curriculum.degrees.map { naming == .solfege ? $0.solfege : $0.label })
            Text("New items unlock when you get every current one right most of the time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func row(_ title: String, _ count: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(count).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(items.joined(separator: "  ")).font(.callout.monospaced())
        }
    }
}
