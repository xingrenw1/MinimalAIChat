import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.presentationMode) private var presentationMode

    /// Controls whether the API key is revealed as plain text
    @State private var isAPIKeyVisible: Bool = false
    /// Toast-style saved confirmation
    @State private var showSavedBanner: Bool = false
    /// Controls the reset confirmation alert
    @State private var showResetAlert: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            // ── Form ──────────────────────────────────────────────────
            Form {
                endpointSection
                modelSection
                apiKeySection
                statusSection
                advancedSection
                dangerSection
            }
            .navigationTitle("API 与连接")
            .navigationBarTitleDisplayMode(.inline)


                // ── Saved Banner ──────────────────────────────────────────
                if showSavedBanner {
                    savedBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showSavedBanner)
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("恢复默认设置"),
                message: Text("这将清除 API Key、基础地址和模型名称，且无法撤销。"),
                primaryButton: .destructive(Text("恢复")) {
                    withAnimation { settings.resetToDefaults() }
                    flashSavedBanner()
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Sections

    /// Base URL section
    private var endpointSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("API 基础地址", systemImage: "network")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                TextField("https://api.openai.com/v1", text: $settings.baseURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 15, design: .monospaced))
                    .onChange(of: settings.baseURL) { _ in flashSavedBanner() }

                Text("支持 OpenAI、OpenRouter、Azure、Ollama 及其他 OpenAI 兼容接口。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader(icon: "server.rack", title: "接口地址")
        }
    }

    /// Model name section
    private var modelSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("模型名称", systemImage: "cpu")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                TextField("gpt-4o-mini", text: $settings.modelName)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 15, design: .monospaced))
                    .onChange(of: settings.modelName) { _ in flashSavedBanner() }

                Text("示例：gpt-4o-mini · claude-3-haiku · llama3 · mistral")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader(icon: "brain.head.profile", title: "模型")
        }
    }

    /// API Key section with show/hide toggle
    private var apiKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("API Key", systemImage: "key.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Group {
                        if isAPIKeyVisible {
                            TextField("sk-...", text: $settings.apiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("sk-...", text: $settings.apiKey)
                        }
                    }
                    .font(.system(size: 15, design: .monospaced))
                    .onChange(of: settings.apiKey) { _ in flashSavedBanner() }

                    Button {
                        isAPIKeyVisible.toggle()
                    } label: {
                        Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }

                Text("安全存储在 iOS 钥匙串中，不会存入 UserDefaults 或 iCloud。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader(icon: "lock.shield", title: "身份认证")
        }
    }

    /// Live status summary
    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                statusDot(settings.isConfigured)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.isConfigured ? "配置有效" : "配置不完整")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(settings.isConfigured ? .primary : .secondary)
                    Text(settings.hasAPIKey ? "已填写 API Key ✓" : "未填写 API Key——大多数提供商需要此项")
                        .font(.system(size: 12))
                        .foregroundColor(settings.hasAPIKey ? Color.green : Color.orange)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader(icon: "checkmark.seal", title: "状态")
        }
    }

    /// Advanced settings link
    private var advancedSection: some View {
        Section {
            NavigationLink(destination: AdvancedSettingsView()) {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text("高级选项")
                        .font(.system(size: 16))
                }
                .padding(.vertical, 4)
            }
        } header: {
            sectionHeader(icon: "gearshape.2", title: "高级设置")
        }
    }

    /// Danger zone
    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("恢复默认设置")
                }
                .font(.system(size: 15, weight: .medium))
            }
        } header: {
            sectionHeader(icon: "exclamationmark.triangle", title: "重置")
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.secondary)
    }

    private func statusDot(_ on: Bool) -> some View {
        Circle()
            .fill(on ? Color.green : Color.orange)
            .frame(width: 10, height: 10)
    }

    /// Shows the "Saved" banner briefly then hides it.
    private func flashSavedBanner() {
        showSavedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showSavedBanner = false }
        }
    }

    private var savedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text("设置已保存")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.accentColor)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.top, 12)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsViewModel())
    }
}

// MARK: - AdvancedSettingsView

struct AdvancedSettingsView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @State private var maxTokensString: String = ""
    @State private var showResetAlert: Bool = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.secondary)
                        SecureField("tvly-...", text: $settings.tavilyApiKey)
                            .font(.system(size: 15))
                        if settings.hasTavilyKey {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)

                    Text("可选。让 AI 在需要时搜索网页以获取最新信息。可在 [tavily.com](https://tavily.com) 获取免费 Key。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("网页搜索（Tavily）")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("温度")
                        Spacer()
                        Text(String(format: "%.1f", settings.temperature))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.temperature, in: 0...2, step: 0.1)
                    Text("数值越低越专注、稳定；数值越高越有创造性和随机性。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("创造性")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("不限制", text: $maxTokensString)
                        .keyboardType(.numberPad)
                        .onChange(of: maxTokensString) { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                maxTokensString = filtered
                            }
                            if filtered.isEmpty {
                                settings.maxTokens = nil
                            } else if let intVal = Int(filtered) {
                                settings.maxTokens = intVal
                            }
                        }
                    Text("限制单次回复长度。留空表示不限制。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("最大 Token 数")
            }
            .onAppear {
                if let mt = settings.maxTokens {
                    maxTokensString = String(mt)
                } else {
                    maxTokensString = ""
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: $settings.historyCharacterBudget, in: 1000...50000, step: 1000) {
                        HStack {
                            Text("预算：")
                            Spacer()
                            Text("\(settings.historyCharacterBudget) 字符")
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("每次请求携带的历史对话长度。数值越高，记忆的上下文越多，同时也会消耗更多 Token。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("对话记忆")
            }

            Section {
                Button(action: {
                    showResetAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("恢复默认设置")
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("高级设置")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("恢复高级设置？"),
                message: Text("温度、最大 Token 数和对话记忆将恢复默认值。"),
                primaryButton: .destructive(Text("恢复")) {
                    withAnimation {
                        settings.temperature = SettingsDefault.temperature
                        settings.maxTokens = nil
                        maxTokensString = ""
                        settings.historyCharacterBudget = SettingsDefault.historyCharacterBudget
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}

