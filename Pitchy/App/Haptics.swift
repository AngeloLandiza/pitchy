import UIKit

@MainActor
enum Haptics {
    static func answer(correct: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
