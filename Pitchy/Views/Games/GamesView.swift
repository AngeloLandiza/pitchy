import SwiftData
import SwiftUI

struct GamesView: View {
    @Query private var sessions: [SessionRecord]

    private func best(_ kind: String) -> Int {
        sessions.filter { $0.kind == kind }.map(\.score).max() ?? 0
    }

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    NoteBlitzView()
                } label: {
                    gameRow("Note Blitz", "Name as many notes as you can in 30 seconds.", "bolt.fill", best: best("blitz"))
                }
                NavigationLink {
                    PitchPilotView()
                } label: {
                    gameRow("Pitch Pilot", "Steer with your voice through the gaps.", "airplane", best: best("pilot"))
                }
            }
            .navigationTitle("Games")
        }
    }

    private func gameRow(_ title: String, _ subtitle: String, _ icon: String, best: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.pitchy, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                if best > 0 {
                    Text("Best: \(best)").font(.caption.weight(.semibold)).foregroundStyle(Color.pitchy)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
