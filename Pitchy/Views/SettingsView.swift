import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @State private var confirmReset = false
    @State private var assessment: AssessmentSession?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Sound") {
                    Picker("Instrument", selection: $settings.instrument) {
                        ForEach(Instrument.allCases) { Text($0.label).tag($0) }
                    }
                    Button("Preview sound") {
                        Synth.shared.play(midi: 60, instrument: settings.instrument, transpose: settings.transpose)
                        Synth.shared.play(midi: 64, instrument: settings.instrument, delay: 0.35, transpose: settings.transpose)
                        Synth.shared.play(midi: 67, instrument: settings.instrument, delay: 0.7, transpose: settings.transpose)
                    }
                    Stepper("Transpose: \(settings.transpose > 0 ? "+" : "")\(settings.transpose) semitones",
                            value: $settings.transpose, in: -12...12)
                }

                Section {
                    Picker("Note names", selection: $settings.naming) {
                        ForEach(NoteNaming.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Change key", selection: $settings.keyChange) {
                        ForEach(KeyChangeFrequency.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Questions per workout: \(settings.questionsPerWorkout)",
                            value: $settings.questionsPerWorkout, in: 5...40, step: 5)
                } header: {
                    Text("Training")
                } footer: {
                    Text("Changing key often stops you from guessing notes relative to the last one.")
                }

                Section {
                    Toggle("Singing questions", isOn: $settings.singingEnabled)
                    Picker("Voice", selection: $settings.voice) {
                        ForEach(VoiceRange.allCases) { Text($0.label).tag($0) }
                    }
                    VStack(alignment: .leading) {
                        Text("Tolerance: ±\(Int(settings.singTolerance)) cents")
                        Slider(value: $settings.singTolerance, in: 15...60, step: 5)
                    }
                } header: {
                    Text("Singing")
                } footer: {
                    Text("How close you need to be. 50 cents is halfway to the next note. Start loose and tighten it as you improve.")
                }

                Section("Progress") {
                    Button("Retake the starting check") {
                        assessment = AssessmentSession(settings: settings, context: context)
                    }
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }

                Section {
                    Text("Pitchy has no accounts, ads, tracking or servers. Your progress and microphone audio never leave this phone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { reset() }
            } message: {
                Text("This deletes your stats, streak and unlocked items, then restarts setup.")
            }
            .fullScreenCover(item: $assessment) { session in
                AssessmentView(session: session) { assessment = nil }
            }
        }
    }

    private func reset() {
        try? context.delete(model: SkillRecord.self)
        try? context.delete(model: SessionRecord.self)
        try? context.save()
        settings.resetProgress()
    }
}

extension AssessmentSession: Identifiable {}
