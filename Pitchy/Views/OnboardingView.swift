import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var assessment: AssessmentSession?

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 24) {
            switch step {
            case 0:
                Spacer()
                Image(systemName: "ear.and.waveform")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.pitchy)
                Text("Pitchy").font(.system(size: 48, weight: .bold, design: .rounded))
                Text("Train your ear a few minutes a day: notes, intervals, scale degrees and singing. Free, private, and everything stays on your phone.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
                PrimaryButton(title: "Get started") { step = 1 }

            case 1:
                header("How should notes be named?")
                ForEach(NoteNaming.allCases) { naming in
                    optionRow(naming.label, selected: settings.naming == naming) { settings.naming = naming }
                }
                Spacer()
                PrimaryButton(title: "Next") { step = 2 }

            case 2:
                header("Pick a sound")
                ForEach(Instrument.allCases) { instrument in
                    optionRow(instrument.label, systemImage: instrument.symbol, selected: settings.instrument == instrument) {
                        settings.instrument = instrument
                        Synth.shared.play(midi: 60, instrument: instrument)
                        Synth.shared.play(midi: 64, instrument: instrument, delay: 0.35)
                        Synth.shared.play(midi: 67, instrument: instrument, delay: 0.7)
                    }
                }
                Spacer()
                PrimaryButton(title: "Next") { step = 3 }

            case 3:
                header("Your voice")
                Text("Used for singing questions. You can turn singing off any time in Settings.")
                    .foregroundStyle(.secondary)
                ForEach(VoiceRange.allCases) { voice in
                    optionRow(voice.label, selected: settings.voice == voice) { settings.voice = voice }
                }
                Toggle("Include singing questions", isOn: $settings.singingEnabled)
                    .padding(.top, 8)
                Spacer()
                PrimaryButton(title: "Next") { step = 4 }

            case 4:
                header("Quick check")
                Text("Pitchy plays 12 notes and 6 intervals to find your starting point. It takes about 2 minutes. You'll see every answer afterwards.")
                    .foregroundStyle(.secondary)
                Spacer()
                PrimaryButton(title: "Start the check") {
                    assessment = AssessmentSession(settings: settings, context: context)
                    step = 5
                }
                Button("Skip and start from the beginning") { settings.hasOnboarded = true }
                    .font(.subheadline)

            default:
                if let assessment {
                    AssessmentView(session: assessment) { settings.hasOnboarded = true }
                        .padding(-16)
                }
            }
        }
        .padding()
        .animation(.easeInOut, value: step)
        .onAppear { Synth.shared.start() }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.largeTitle.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 32)
    }

    private func optionRow(_ title: String, systemImage: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let systemImage { Image(systemName: systemImage).frame(width: 28) }
                Text(title).font(.headline)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.pitchy : Color.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
