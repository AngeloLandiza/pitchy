import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var skills: [SkillRecord]
    @Query(sort: \SessionRecord.date, order: .reverse) private var sessions: [SessionRecord]

    private var byKey: [String: SkillRecord] {
        Dictionary(skills.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 12) {
                        StatTile(value: "\(Streak.current(sessionDates: sessions.map(\.date)))", label: "day streak", systemImage: "flame.fill")
                        StatTile(value: "\(sessions.filter { $0.kind == "workout" }.count)", label: "workouts", systemImage: "figure.mind.and.body")
                    }

                    section("Notes") {
                        grid(PitchClass.all.map { pc in
                            (pc.name(settings.naming), byKey[Answer.note(pc).skillKey])
                        }, columns: 4)
                    }
                    section("Intervals") {
                        grid(Interval.allCases.map { ($0.shortName, byKey[Answer.interval($0).skillKey]) }, columns: 4)
                    }
                    section("Scale degrees") {
                        grid(ScaleDegree.allCases.map { d in
                            (settings.naming == .solfege ? d.solfege : d.label, byKey[Answer.degree(d).skillKey])
                        }, columns: 4)
                    }
                    section("Singing") {
                        grid(ScaleDegree.allCases.map { d in
                            (settings.naming == .solfege ? d.solfege : d.label, byKey["sing:" + Answer.degree(d).skillKey])
                        }, columns: 4)
                    }

                    if !sessions.isEmpty {
                        section("Recent") {
                            VStack(spacing: 8) {
                                ForEach(sessions.prefix(10)) { s in
                                    HStack {
                                        Text(s.kind.capitalized)
                                        Spacer()
                                        Text(s.kind == "workout" || s.kind == "assessment"
                                             ? "\(s.correct)/\(s.questions)"
                                             : "Score \(s.score)")
                                            .monospacedDigit()
                                        Text(s.date, format: .dateTime.month().day())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 60, alignment: .trailing)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    /// Cells coloured by accuracy. Grey means not tried yet.
    private func grid(_ items: [(String, SkillRecord?)], columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(items.indices, id: \.self) { i in
                let record = items[i].1
                VStack(spacing: 2) {
                    Text(items[i].0).font(.subheadline.weight(.semibold))
                    Text(record.map { "\(Int(($0.accuracy * 100).rounded()))%" } ?? "–")
                        .font(.caption.monospacedDigit())
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(color(for: record), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func color(for record: SkillRecord?) -> Color {
        guard let record, record.attempts > 0 else { return Color(.tertiarySystemFill) }
        switch record.accuracy {
        case ..<0.5: return Color.pitchyBad.opacity(0.35)
        case ..<0.8: return Color.orange.opacity(0.35)
        default: return Color.pitchyGood.opacity(0.35)
        }
    }
}
