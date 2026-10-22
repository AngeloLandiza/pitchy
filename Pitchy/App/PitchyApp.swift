import SwiftData
import SwiftUI

@main
struct PitchyApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .tint(.pitchy)
        }
        .modelContainer(for: [SkillRecord.self, SessionRecord.self])
    }
}

struct RootView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if settings.hasOnboarded {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Train", systemImage: "ear") }
            GamesView()
                .tabItem { Label("Games", systemImage: "gamecontroller") }
            StatsView()
                .tabItem { Label("Progress", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear { Synth.shared.start() }
    }
}

extension Color {
    static let pitchy = Color(red: 0.42, green: 0.33, blue: 0.95)
    static let pitchyGood = Color(red: 0.18, green: 0.72, blue: 0.45)
    static let pitchyBad = Color(red: 0.92, green: 0.32, blue: 0.36)
}
