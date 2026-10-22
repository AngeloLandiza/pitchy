import SwiftUI

/// Grid of answer buttons. After an answer, the right choice turns green and a wrong pick turns red.
struct AnswerGrid: View {
    let choices: [Answer]
    let naming: NoteNaming
    var picked: Answer?
    var correct: Answer?
    let onPick: (Answer) -> Void

    private var columns: [GridItem] {
        let count = choices.count <= 4 ? 2 : choices.count <= 9 ? 3 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(choices, id: \.self) { choice in
                Button {
                    onPick(choice)
                } label: {
                    VStack(spacing: 2) {
                        Text(choice.label(naming))
                            .font(.title3.weight(.semibold))
                        if let detail = choice.detail, choices.count <= 6 {
                            Text(detail).font(.caption2).opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(background(for: choice), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(foreground(for: choice))
                }
                .buttonStyle(.plain)
                .disabled(picked != nil)
                .accessibilityLabel(choice.detail ?? choice.label(naming))
            }
        }
    }

    private func background(for choice: Answer) -> Color {
        guard picked != nil else { return Color(.secondarySystemBackground) }
        if choice == correct { return .pitchyGood }
        if choice == picked { return .pitchyBad }
        return Color(.secondarySystemBackground).opacity(0.5)
    }

    private func foreground(for choice: Answer) -> Color {
        guard picked != nil else { return .primary }
        return choice == correct || choice == picked ? .white : .secondary
    }
}

struct ReplayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Play again", systemImage: "speaker.wave.2.fill")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.pitchy.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.pitchy)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.pitchy, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

/// Horizontal tuner: the needle shows how many cents you are from the target.
struct TunerNeedle: View {
    /// Cents from target, nil when no voice is heard.
    let cents: Double?
    let tolerance: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let scale = width / 200 // shows -100...+100 cents
            ZStack {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(Color.pitchyGood.opacity(0.35))
                    .frame(width: tolerance * 2 * scale)
                Rectangle().fill(Color.secondary).frame(width: 2)
                if let cents {
                    let clamped = max(-100, min(100, cents))
                    Circle()
                        .fill(abs(cents) <= tolerance ? Color.pitchyGood : Color.pitchy)
                        .frame(width: 26, height: 26)
                        .offset(x: clamped * scale)
                        .animation(.easeOut(duration: 0.1), value: clamped)
                }
            }
        }
        .frame(height: 34)
        .accessibilityElement()
        .accessibilityLabel(cents.map { String(format: "%.0f cents %@", abs($0), $0 < 0 ? "flat" : "sharp") } ?? "No voice heard")
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(Color.pitchy)
            Text(value).font(.title2.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
