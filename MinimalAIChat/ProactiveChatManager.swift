import Foundation
import UserNotifications

/// Handles scheduled proactive AI messages.
/// The first version uses local scheduling. API generation will be connected through ChatAPIService.
@MainActor
final class ProactiveChatManager: ObservableObject {
    static let shared = ProactiveChatManager()

    @Published var enabled: Bool = false
    @Published var minimumDelay: TimeInterval = 3600
    @Published var maximumDelay: TimeInterval = 21600

    private init() {}

    func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    func schedulePlaceholderMessage(_ message: String, after delay: TimeInterval) {
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "AI"
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, delay), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func randomDelay() -> TimeInterval {
        Double.random(in: minimumDelay...maximumDelay)
    }
}
