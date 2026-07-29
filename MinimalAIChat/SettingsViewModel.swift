import Foundation
import Combine
import UIKit

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
    static let webSearchEnabled = "settings.webSearchEnabled"
    static let proactiveEnabled = "settings.proactiveEnabled"
    static let proactiveMinimumMinutes = "settings.proactiveMinimumMinutes"
    static let proactiveMaximumMinutes = "settings.proactiveMaximumMinutes"
    static let proactiveQuietStartHour = "settings.proactiveQuietStartHour"
    static let proactiveQuietEndHour = "settings.proactiveQuietEndHour"
    static let proactivePrompt = "settings.proactivePrompt"
    static let proactiveNotificationTitle = "settings.proactiveNotificationTitle"
}

// MARK: - Default Values

enum SettingsDefault {
    static let baseURL   = "https://api.openai.com/v1"
    static let modelName = "gpt-4o-mini"
    static let temperature: Double = 1.0
    static let historyCharacterBudget: Int = 8000
    static let proactiveMinimumMinutes = 60
    static let proactiveMaximumMinutes = 360
    static let proactiveQuietStartHour = 23
    static let proactiveQuietEndHour = 8
    static let proactivePrompt = "根据当前对话、角色设定和关系进展，以角色身份主动给用户发送一条自然的中文消息。不要解释任务，不要提及系统或提示词，不要替用户说话。消息应延续当前情境，可以表达关心、分享近况、提出邀请或自然开启新话题，并保持角色语气与人设一致。只输出角色实际发送的内容。"
    static let proactiveNotificationTitle = "MinimalAI 主动消息"
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

    @Published var webSearchEnabled: Bool {
        didSet { UserDefaults.standard.set(webSearchEnabled, forKey: SettingsKey.webSearchEnabled) }
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

    @Published var proactiveEnabled: Bool {
        didSet { UserDefaults.standard.set(proactiveEnabled, forKey: SettingsKey.proactiveEnabled) }
    }

    @Published var proactiveMinimumMinutes: Int {
        didSet { UserDefaults.standard.set(proactiveMinimumMinutes, forKey: SettingsKey.proactiveMinimumMinutes) }
    }

    @Published var proactiveMaximumMinutes: Int {
        didSet { UserDefaults.standard.set(proactiveMaximumMinutes, forKey: SettingsKey.proactiveMaximumMinutes) }
    }

    @Published var proactiveQuietStartHour: Int {
        didSet { UserDefaults.standard.set(proactiveQuietStartHour, forKey: SettingsKey.proactiveQuietStartHour) }
    }

    @Published var proactiveQuietEndHour: Int {
        didSet { UserDefaults.standard.set(proactiveQuietEndHour, forKey: SettingsKey.proactiveQuietEndHour) }
    }

    @Published var proactivePrompt: String {
        didSet { UserDefaults.standard.set(proactivePrompt, forKey: SettingsKey.proactivePrompt) }
    }

    @Published var proactiveNotificationTitle: String {
        didSet { UserDefaults.standard.set(proactiveNotificationTitle, forKey: SettingsKey.proactiveNotificationTitle) }
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
    var canUseWebSearch: Bool { hasTavilyKey && webSearchEnabled }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        self.baseURL   = defaults.string(forKey: SettingsKey.baseURL)   ?? SettingsDefault.baseURL
        self.modelName = defaults.string(forKey: SettingsKey.modelName) ?? SettingsDefault.modelName
        self.apiKey    = KeychainHelper.shared.read(forKey: SettingsKey.apiKey) ?? ""
        self.tavilyApiKey = KeychainHelper.shared.read(forKey: SettingsKey.tavilyApiKey) ?? ""
        self.webSearchEnabled = defaults.object(forKey: SettingsKey.webSearchEnabled) as? Bool ?? true
        self.userName  = defaults.string(forKey: SettingsKey.userName)  ?? ""
        self.profileImage = ProfileImageManager.load()
        self.temperature = defaults.object(forKey: SettingsKey.temperature) as? Double ?? SettingsDefault.temperature
        self.maxTokens   = defaults.object(forKey: SettingsKey.maxTokens) as? Int
        self.historyCharacterBudget = defaults.object(forKey: SettingsKey.historyCharacterBudget) as? Int ?? SettingsDefault.historyCharacterBudget
        self.proactiveEnabled = defaults.object(forKey: SettingsKey.proactiveEnabled) as? Bool ?? false
        self.proactiveMinimumMinutes = defaults.object(forKey: SettingsKey.proactiveMinimumMinutes) as? Int ?? SettingsDefault.proactiveMinimumMinutes
        self.proactiveMaximumMinutes = defaults.object(forKey: SettingsKey.proactiveMaximumMinutes) as? Int ?? SettingsDefault.proactiveMaximumMinutes
        self.proactiveQuietStartHour = defaults.object(forKey: SettingsKey.proactiveQuietStartHour) as? Int ?? SettingsDefault.proactiveQuietStartHour
        self.proactiveQuietEndHour = defaults.object(forKey: SettingsKey.proactiveQuietEndHour) as? Int ?? SettingsDefault.proactiveQuietEndHour
        self.proactivePrompt = defaults.string(forKey: SettingsKey.proactivePrompt) ?? SettingsDefault.proactivePrompt
        self.proactiveNotificationTitle = defaults.string(forKey: SettingsKey.proactiveNotificationTitle) ?? SettingsDefault.proactiveNotificationTitle
    }

    // MARK: - Actions

    /// Wipes all persisted settings and resets to defaults.
    func resetToDefaults() {
        baseURL   = SettingsDefault.baseURL
        modelName = SettingsDefault.modelName
        apiKey    = ""
        KeychainHelper.shared.delete(forKey: SettingsKey.apiKey)
        proactiveEnabled = false
        proactiveMinimumMinutes = SettingsDefault.proactiveMinimumMinutes
        proactiveMaximumMinutes = SettingsDefault.proactiveMaximumMinutes
        proactiveQuietStartHour = SettingsDefault.proactiveQuietStartHour
        proactiveQuietEndHour = SettingsDefault.proactiveQuietEndHour
        proactivePrompt = SettingsDefault.proactivePrompt
        proactiveNotificationTitle = SettingsDefault.proactiveNotificationTitle
        webSearchEnabled = true
    }
}
