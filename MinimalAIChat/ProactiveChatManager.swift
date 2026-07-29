import Foundation
import UserNotifications

struct PreparedProactiveMessage {
    let sessionID: UUID
    let content: String
}

private struct PendingProactiveMessage: Codable {
    let id: UUID
    let sessionID: UUID
    let content: String
    let deliveryDate: Date
}

/// Coordinates one locally prepared proactive message at a time.
///
/// iOS does not guarantee arbitrary background network execution. The app therefore
/// generates the next message while it is active, schedules its local notification,
/// and commits it to chat history when it becomes due (or on the next activation).
@MainActor
final class ProactiveChatManager: ObservableObject {
    static let shared = ProactiveChatManager()

    @Published private(set) var nextDeliveryDate: Date?
    @Published private(set) var isPreparing = false
    @Published private(set) var lastPreparationError: String?

    private static let pendingKey = "proactive.pendingMessage"
    private static let notificationPrefix = "proactive-message-"

    private var settingsProvider: (() -> SettingsViewModel?)?
    private var generator: (() async throws -> PreparedProactiveMessage?)?
    private var deliveryHandler: ((UUID, String) -> Void)?
    private var timerTask: Task<Void, Never>?
    private var pending: PendingProactiveMessage? {
        didSet {
            nextDeliveryDate = pending?.deliveryDate
            persistPending()
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.pendingKey) {
            pending = try? JSONDecoder().decode(PendingProactiveMessage.self, from: data)
        }
        nextDeliveryDate = pending?.deliveryDate
    }

    func configure(
        settingsProvider: @escaping () -> SettingsViewModel?,
        generator: @escaping () async throws -> PreparedProactiveMessage?,
        deliveryHandler: @escaping (UUID, String) -> Void
    ) {
        self.settingsProvider = settingsProvider
        self.generator = generator
        self.deliveryHandler = deliveryHandler
    }

    func activate() async {
        guard let settings = settingsProvider?(), settings.proactiveEnabled else {
            cancelPending()
            return
        }

        deliverIfDue()
        armForegroundTimer()
        await prepareNextIfNeeded()
    }

    func settingsDidChange() async {
        guard let settings = settingsProvider?(), settings.proactiveEnabled else {
            cancelPending()
            return
        }

        await requestNotificationPermission()
        cancelPending()
        await prepareNextIfNeeded()
    }

    /// A real user/assistant exchange invalidates a pre-generated message because
    /// its context is now stale. Generate a new one from the updated conversation.
    func conversationDidChange() async {
        guard settingsProvider?()?.proactiveEnabled == true else { return }
        cancelPending()
        await prepareNextIfNeeded()
    }

    func cancelPending() {
        timerTask?.cancel()
        timerTask = nil
        if let pending {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [notificationIdentifier(for: pending.id)]
            )
        }
        pending = nil
    }

    private func prepareNextIfNeeded() async {
        guard pending == nil,
              !isPreparing,
              let settings = settingsProvider?(),
              settings.proactiveEnabled,
              let generator else { return }

        isPreparing = true
        lastPreparationError = nil
        defer { isPreparing = false }

        do {
            guard let prepared = try await generator() else { return }
            let date = adjustedDeliveryDate(for: settings)
            let item = PendingProactiveMessage(
                id: UUID(),
                sessionID: prepared.sessionID,
                content: prepared.content,
                deliveryDate: date
            )
            pending = item
            scheduleNotification(for: item, title: settings.proactiveNotificationTitle)
            armForegroundTimer()
        } catch {
            lastPreparationError = error.localizedDescription
        }
    }

    private func deliverIfDue() {
        guard let pending, pending.deliveryDate <= Date() else { return }
        deliveryHandler?(pending.sessionID, pending.content)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: pending.id)]
        )
        self.pending = nil
    }

    private func armForegroundTimer() {
        timerTask?.cancel()
        guard let pending else { return }

        let nanoseconds = UInt64(max(0, pending.deliveryDate.timeIntervalSinceNow) * 1_000_000_000)
        timerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled, let self else { return }
            self.deliverIfDue()
            await self.prepareNextIfNeeded()
        }
    }

    private func adjustedDeliveryDate(for settings: SettingsViewModel) -> Date {
        let minimum = max(1, min(settings.proactiveMinimumMinutes, settings.proactiveMaximumMinutes))
        let maximum = max(minimum, max(settings.proactiveMinimumMinutes, settings.proactiveMaximumMinutes))
        let delay = TimeInterval(Int.random(in: minimum...maximum) * 60)
        var candidate = Date().addingTimeInterval(delay)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: candidate)
        let start = min(23, max(0, settings.proactiveQuietStartHour))
        let end = min(23, max(0, settings.proactiveQuietEndHour))
        let isQuiet = start == end ? false : (start < end ? (hour >= start && hour < end) : (hour >= start || hour < end))

        if isQuiet {
            var components = calendar.dateComponents([.year, .month, .day], from: candidate)
            components.hour = end
            components.minute = Int.random(in: 0...20)
            components.second = 0
            if let sameDayEnd = calendar.date(from: components) {
                candidate = sameDayEnd > candidate ? sameDayEnd : calendar.date(byAdding: .day, value: 1, to: sameDayEnd) ?? candidate
            }
        }
        return candidate
    }

    private func scheduleNotification(for message: PendingProactiveMessage, title: String) {
        let content = UNMutableNotificationContent()
        content.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SettingsDefault.proactiveNotificationTitle : title
        content.body = message.content
        content.sound = .default
        content.userInfo = ["sessionID": message.sessionID.uuidString]

        let interval = max(1, message.deliveryDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: message.id),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            lastPreparationError = error.localizedDescription
        }
    }

    private func notificationIdentifier(for id: UUID) -> String {
        Self.notificationPrefix + id.uuidString
    }

    private func persistPending() {
        if let pending, let data = try? JSONEncoder().encode(pending) {
            UserDefaults.standard.set(data, forKey: Self.pendingKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.pendingKey)
        }
    }
}
