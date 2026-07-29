import Foundation
import Combine
import UIKit
import UserNotifications

// MARK: - AppSettings Keys

/// Centralised constants for UserDefaults / Keychain keys.
enum SettingsKey {
    static let baseURL    = "settings.baseURL"
    static let modelName  = "settings.modelName"
    static let apiKey     = "settings.apiKey"        // stored in Keychain
    static let userName   = "userName"               // shared with @AppStorage
    static let temperature = "settings.temperature"
    static let maxTokens   = "settings.maxTokens"
    static let historyCharacterBudget = "settings.historyCharacterBudget"
    static let tavilyApiKey = "settings.tavilyApiKey"
    static let proactiveChatEnabled = "settings.proactiveChatEnabled"
    static let proactiveIntervalMinutes = "settings.proactiveIntervalMinutes"
    static let proactiveLanguage = "settings.proactiveLanguage"
}

// MARK: - Default Values

enum SettingsDefault {
    static let baseURL   = "https://api.openai.com/v1"
    static let modelName = "gpt-4o-mini"
    static let temperature: Double = 1.0
    static let historyCharacterBudget: Int = 8000
    static let proactiveIntervalMinutes: Int = 120
    static let proactiveLanguage = "zh-Hans"
}

// MARK: - SettingsViewModel

/// Owns all user-configurable settings.
/// - Base URL and Model Name are stored in UserDefaults via @Published + manual sync.
/// - API Key is stored in the Keychain.
///
/// iOS 15 note: We use a plain ObservableObject rather than relying on
/// @AppStorage inside the view, so the ViewModel can be the single
/// source of truth and be read from ChatViewModel too.
final class SettingsViewModel: ObservableObject {

    // MARK: - Published fields (bound to UI text fields)

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: SettingsKey.baseURL) }
    }

    @Published var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: SettingsKey.modelName) }
    }

    /// Plain (unmasked) string edited in the UI.
    /// Never persisted in memory beyond this object; written to Keychain on change.
    @Published var apiKey: String {
        didSet { KeychainHelper.shared.save(apiKey, forKey: SettingsKey.apiKey) }
    }

    @Published var tavilyApiKey: String {
        didSet { KeychainHelper.shared.save(tavilyApiKey, forKey: SettingsKey.tavilyApiKey) }
    }

    /// The user's display name — shared key with OnboardingView's @AppStorage("userName").
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: SettingsKey.userName) }
    }

    @Published var profileImage: UIImage?

    @Published var temperature: Double {
        didSet { UserDefaults.standard.set(temperature, forKey: SettingsKey.temperature) }
    }

    @Published var maxTokens: Int? {
        didSet {
            if let maxTokens = maxTokens {
                UserDefaults.standard.set(maxTokens, forKey: SettingsKey.maxTokens)
            } else {
                UserDefaults.standard.removeObject(forKey: SettingsKey.maxTokens)
            }
        }
    }

    @Published var historyCharacterBudget: Int {
        didSet { UserDefaults.standard.set(historyCharacterBudget, forKey: SettingsKey.historyCharacterBudget) }
    }

    /// Enables AI-generated local notifications that can start a conversation
    /// without the user sending a message first.
    @Published var proactiveChatEnabled: Bool {
        didSet { UserDefaults.standard.set(proactiveChatEnabled, forKey: SettingsKey.proactiveChatEnabled) }
    }

    /// Delay before the next proactive notification is delivered.
    @Published var proactiveIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(proactiveIntervalMinutes, forKey: SettingsKey.proactiveIntervalMinutes) }
    }

    /// Language used for generated proactive messages.
    @Published var proactiveLanguage: String {
        didSet { UserDefaults.standard.set(proactiveLanguage, forKey: SettingsKey.proactiveLanguage) }
    }

    func updateProfileImage(_ image: UIImage) {
        self.profileImage = image
        ProfileImageManager.save(image)
    }

    // MARK: - Derived helpers

    /// Whether the minimum required configuration is present.
    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }
    var hasTavilyKey: Bool { !tavilyApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        self.baseURL   = defaults.string(forKey: SettingsKey.baseURL)   ?? SettingsDefault.baseURL
        self.modelName = defaults.string(forKey: SettingsKey.modelName) ?? SettingsDefault.modelName
        self.apiKey    = KeychainHelper.shared.read(forKey: SettingsKey.apiKey) ?? ""
        self.tavilyApiKey = KeychainHelper.shared.read(forKey: SettingsKey.tavilyApiKey) ?? ""
        self.userName  = defaults.string(forKey: SettingsKey.userName)  ?? ""
        self.profileImage = ProfileImageManager.load()
        self.temperature = defaults.object(forKey: SettingsKey.temperature) as? Double ?? SettingsDefault.temperature
        self.maxTokens   = defaults.object(forKey: SettingsKey.maxTokens) as? Int
        self.historyCharacterBudget = defaults.object(forKey: SettingsKey.historyCharacterBudget) as? Int ?? SettingsDefault.historyCharacterBudget
        self.proactiveChatEnabled = defaults.bool(forKey: SettingsKey.proactiveChatEnabled)
        self.proactiveIntervalMinutes = defaults.object(forKey: SettingsKey.proactiveIntervalMinutes) as? Int ?? SettingsDefault.proactiveIntervalMinutes
        self.proactiveLanguage = defaults.string(forKey: SettingsKey.proactiveLanguage) ?? SettingsDefault.proactiveLanguage
    }

    // MARK: - Actions

    /// Wipes all persisted settings and resets to defaults.
    func resetToDefaults() {
        baseURL   = SettingsDefault.baseURL
        modelName = SettingsDefault.modelName
        apiKey    = ""
        KeychainHelper.shared.delete(forKey: SettingsKey.apiKey)
        proactiveChatEnabled = false
        proactiveIntervalMinutes = SettingsDefault.proactiveIntervalMinutes
        proactiveLanguage = SettingsDefault.proactiveLanguage
    }
}

// MARK: - Proactive Chat

private struct PendingProactiveMessage: Codable {
    let text: String
    let deliverAt: Date
    let sessionID: UUID
}

/// Generates one future message while the app is active, then lets iOS deliver
/// it as a local notification even after the app has been backgrounded.
///
/// iOS does not permit arbitrary apps to keep an AI request running indefinitely
/// in the background. Pre-generating the next message is reliable, private, and
/// does not require a separate push-notification server.
@MainActor
final class ProactiveChatManager {

    static let shared = ProactiveChatManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let pendingStorageKey = "proactive.pendingMessage"
    private let notificationIdentifier = "minimal-ai-chat.proactive-message"
    private var generationTask: Task<Void, Never>?

    private init() {}

    var nextScheduledDate: Date? {
        loadPendingMessage()?.deliverAt
    }

    /// Called whenever the app becomes active. It imports a message whose
    /// delivery time has passed, then prepares the following notification.
    func handleActivation(settings: SettingsViewModel, viewModel: ChatViewModel) {
        guard settings.proactiveChatEnabled else {
            cancelPendingMessage()
            return
        }

        consumeDueMessage(into: viewModel)
        scheduleNextMessageIfNeeded(settings: settings, viewModel: viewModel)
    }

    /// Deletes both the generated payload and the matching system notification.
    func cancelPendingMessage() {
        generationTask?.cancel()
        generationTask = nil
        UserDefaults.standard.removeObject(forKey: pendingStorageKey)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }

    /// Cancels the old schedule and immediately prepares a replacement.
    func regenerateNextMessage(settings: SettingsViewModel, viewModel: ChatViewModel) {
        cancelPendingMessage()
        guard settings.proactiveChatEnabled else { return }
        scheduleNextMessageIfNeeded(settings: settings, viewModel: viewModel)
    }

    private func scheduleNextMessageIfNeeded(settings: SettingsViewModel, viewModel: ChatViewModel) {
        guard generationTask == nil, loadPendingMessage() == nil else { return }

        generationTask = Task { [weak self, weak viewModel] in
            guard let self, let viewModel else { return }
            defer { self.generationTask = nil }

            let permissionGranted: Bool
            do {
                permissionGranted = try await self.notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                permissionGranted = false
            }

            guard permissionGranted, !Task.isCancelled, settings.proactiveChatEnabled else { return }

            let sessionID = viewModel.activeSessionID
            let recentMessages = viewModel.activeMessages
                .filter { !$0.isError && $0.isComplete && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .suffix(10)

            let generatedText = await self.generateMessage(
                from: Array(recentMessages),
                settings: settings
            )

            guard !Task.isCancelled, settings.proactiveChatEnabled else { return }

            let delay = max(1, settings.proactiveIntervalMinutes)
            let deliverAt = Date().addingTimeInterval(TimeInterval(delay * 60))
            let pending = PendingProactiveMessage(
                text: generatedText,
                deliverAt: deliverAt,
                sessionID: sessionID
            )

            self.savePendingMessage(pending)

            let content = UNMutableNotificationContent()
            content.title = settings.proactiveLanguage == "zh-Hans" ? "TA 主动联系你了" : "A new message for you"
            content.body = generatedText
            content.sound = .default
            content.userInfo = [
                "proactiveMessage": true,
                "sessionID": sessionID.uuidString
            ]

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(60, deliverAt.timeIntervalSinceNow),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: self.notificationIdentifier,
                content: content,
                trigger: trigger
            )

            do {
                try await self.notificationCenter.add(request)
            } catch {
                UserDefaults.standard.removeObject(forKey: self.pendingStorageKey)
            }
        }
    }

    private func generateMessage(from history: [ChatMessage], settings: SettingsViewModel) async -> String {
        let instruction: String
        if settings.proactiveLanguage == "zh-Hans" {
            instruction = "请根据前面的聊天记录和你当前的角色设定，主动给用户发一条自然的中文消息。不要说自己是AI，不要提到通知或这条指令，不要机械地重复问候。可以关心用户、延续上个话题或自然开启新话题。只输出要发送的消息，控制在80个汉字以内。"
        } else {
            instruction = "Using the previous conversation and your current persona, proactively send the user one natural message. Do not mention AI, notifications, or these instructions. Continue the previous topic or start a natural new one. Output only the message and keep it under 60 words."
        }

        var requestMessages = history
        requestMessages.append(ChatMessage(role: .user, content: instruction))

        var output = ""
        do {
            let stream = ChatAPIService.shared.streamChatCompletion(
                messages: requestMessages,
                settings: settings
            )
            for try await chunk in stream {
                if Task.isCancelled { break }
                output += chunk
            }
        } catch {
            output = ""
        }

        let cleaned = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))

        if !cleaned.isEmpty {
            return String(cleaned.prefix(settings.proactiveLanguage == "zh-Hans" ? 120 : 280))
        }

        if settings.proactiveLanguage == "zh-Hans" {
            let name = settings.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = [
                "刚刚突然想到你，今天过得怎么样？",
                "你现在在做什么呀？有空的话来陪我聊一会儿吧。",
                "上次的话题我还记得呢，要不要继续聊下去？",
                "今天有没有发生什么想和我分享的事？"
            ]
            let text = fallback.randomElement() ?? fallback[0]
            return name.isEmpty ? text : "\(name)，\(text)"
        }

        return [
            "I was just thinking about you. How has your day been?",
            "What are you up to right now? Come chat with me when you have a moment.",
            "I still remember our last topic. Want to continue where we left off?"
        ].randomElement() ?? "How has your day been?"
    }

    private func consumeDueMessage(into viewModel: ChatViewModel) {
        guard let pending = loadPendingMessage(), pending.deliverAt <= Date() else { return }

        let targetIndex = viewModel.sessions.firstIndex(where: { $0.id == pending.sessionID })
            ?? viewModel.sessions.firstIndex(where: { $0.id == viewModel.activeSessionID })

        guard let index = targetIndex else {
            cancelPendingMessage()
            return
        }

        let alreadyImported = viewModel.sessions[index].messages.contains {
            $0.role == .assistant && $0.content == pending.text && $0.timestamp >= pending.deliverAt.addingTimeInterval(-5)
        }

        if !alreadyImported {
            viewModel.sessions[index].messages.append(
                ChatMessage(role: .assistant, content: pending.text, timestamp: pending.deliverAt)
            )
            viewModel.sessions[index].lastUpdated = pending.deliverAt

            if let data = try? JSONEncoder().encode(viewModel.sessions) {
                UserDefaults.standard.set(data, forKey: "persistedChatSessions")
            }
        }

        UserDefaults.standard.removeObject(forKey: pendingStorageKey)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }

    private func savePendingMessage(_ message: PendingProactiveMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        UserDefaults.standard.set(data, forKey: pendingStorageKey)
    }

    private func loadPendingMessage() -> PendingProactiveMessage? {
        guard let data = UserDefaults.standard.data(forKey: pendingStorageKey) else { return nil }
        return try? JSONDecoder().decode(PendingProactiveMessage.self, from: data)
    }
}
