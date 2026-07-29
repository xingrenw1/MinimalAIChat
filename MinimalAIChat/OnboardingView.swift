import SwiftUI

// MARK: - OnboardingView

/// Full-screen setup presented on first launch.
/// Collects the user's name (stored in UserDefaults via @AppStorage)
/// and their API key (stored in the Keychain via KeychainHelper).
/// Sets `hasCompletedSetup = true` to dismiss itself permanently.
struct OnboardingView: View {

    // ── Persistence ───────────────────────────────────────────────────────
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @AppStorage("userName") private var storedUserName = ""

    // ── Local fields ──────────────────────────────────────────────────────
    @State private var userName: String = ""
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var modelName: String = ""
    @State private var tavilyApiKey: String = ""
    @State private var isAPIKeyVisible: Bool = false
    @State private var isTavilyKeyVisible: Bool = false
    @State private var shakeUserName: Bool = false
    @State private var shakeBaseURL: Bool = false
    @State private var shakeModelName: Bool = false

    // Injected so we can push the API key into the shared settings object
    // and the app picks it up immediately without a restart.
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Illustration / Hero ───────────────────────────────────
                heroSection
                    .padding(.bottom, 36)

                // ── Form ─────────────────────────────────────────────────
                VStack(spacing: 20) {
                    nameField
                    baseURLField
                    modelNameField
                    apiKeyField
                    tavilyApiKeyField
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 40)

                // ── CTA ───────────────────────────────────────────────────
                continueButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
            }
            .padding(.top, 60)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 90, height: 90)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 20, x: 0, y: 8)

                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("欢迎使用 MinimalAI")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("只需几秒钟，即可完成\n你的专属助手设置。")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("你的名字", systemImage: "person")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("例如：老师", text: $userName)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .modifier(ShakeEffect(animating: shakeUserName))

            Text("用于个性化你的 AI 对话。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var baseURLField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("API 基础地址（Endpoint）", systemImage: "link")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("例如：https://openrouter.ai/api/v1", text: $baseURL)
                .font(.system(size: 16))
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .modifier(ShakeEffect(animating: shakeBaseURL))
        }
    }

    private var modelNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("模型名称", systemImage: "cpu")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("例如：提供商/模型名称", text: $modelName)
                .font(.system(size: 16))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .modifier(ShakeEffect(animating: shakeModelName))
        }
    }

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("API Key", systemImage: "key.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Group {
                    if isAPIKeyVisible {
                        TextField("sk-...", text: $apiKey)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                    }
                }
                .font(.system(size: 15, design: .monospaced))
                .autocapitalization(.none)
                .disableAutocorrection(true)

                Button { isAPIKeyVisible.toggle() } label: {
                    Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            Text("安全存储在 iOS 钥匙串中。你也可以暂时跳过，稍后在设置中添加。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tavilyApiKeyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tavily API Key（可选）", systemImage: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Group {
                    if isTavilyKeyVisible {
                        TextField("tvly-...", text: $tavilyApiKey)
                    } else {
                        SecureField("tvly-...", text: $tavilyApiKey)
                    }
                }
                .font(.system(size: 15, design: .monospaced))
                .autocapitalization(.none)
                .disableAutocorrection(true)

                Button { isTavilyKeyVisible.toggle() } label: {
                    Image(systemName: isTavilyKeyVisible ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            Text("Tavily 提供实时网页搜索，让助手可以查询最新信息。可在 tavily.com 获取免费 Key。它会安全存储在 iOS 钥匙串中，也可以暂时跳过。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var continueButton: some View {
        Button(action: finish) {
            HStack(spacing: 8) {
                Text("开始使用")
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func finish() {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)

        var hasError = false

        if trimmedName.isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) { shakeUserName = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { shakeUserName = false }
            hasError = true
        }
        if trimmedURL.isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) { shakeBaseURL = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { shakeBaseURL = false }
            hasError = true
        }
        if trimmedModel.isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) { shakeModelName = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { shakeModelName = false }
            hasError = true
        }

        guard !hasError else { return }

        // Persist name
        storedUserName = trimmedName

        // Persist API key into Keychain and live settings object
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            settings.apiKey = trimmedKey   // SettingsViewModel.didSet saves to Keychain
        }

        // Persist Tavily API key the same way — entirely optional, no validation
        let trimmedTavilyKey = tavilyApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTavilyKey.isEmpty {
            settings.tavilyApiKey = trimmedTavilyKey   // SettingsViewModel.didSet saves to Keychain
        }

        settings.baseURL = trimmedURL
        settings.modelName = trimmedModel

        // Mark setup as complete — dismisses this view
        hasCompletedSetup = true
    }
}

// MARK: - Shake Effect (for name field validation)

private struct ShakeEffect: GeometryEffect {
    var animating: Bool
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3

    var animatableData: CGFloat {
        get { animating ? 1 : 0 }
        set { }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(SettingsViewModel())
    }
}
