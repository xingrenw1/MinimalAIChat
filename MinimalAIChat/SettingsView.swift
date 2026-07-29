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
    @State private var availableModels: [AvailableModel] = []
    @State private var isLoadingModels: Bool = false
    @State private var showModelPicker: Bool = false
    @State private var showModelLibrary: Bool = false
    @State private var showCustomModelSheet: Bool = false
    @State private var customModelID: String = ""
    @State private var modelListError: String? = nil

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
        .sheet(isPresented: $showModelPicker) {
            ModelPickerView(
                models: availableModels,
                selectedModel: $settings.modelName,
                onSelect: { model in
                    ModelLibraryStore.shared.add(
                        id: model.id,
                        name: model.displayName,
                        summary: model.description ?? "从在线模型列表添加",
                        tags: model.visibleCapabilities.map(\.name)
                    )
                }
            )
        }
        .sheet(isPresented: $showModelLibrary) {
            ModelLibraryView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showCustomModelSheet) {
            CustomModelView(modelID: $customModelID) {
                let value = customModelID.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    settings.modelName = value
                    ModelLibraryStore.shared.add(id: value)
                    flashSavedBanner()
                }
                showCustomModelSheet = false
            } onCancel: {
                showCustomModelSheet = false
            }
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

                HStack(spacing: 8) {
                    modelActionButton(
                        title: isLoadingModels ? "正在获取" : "获取列表",
                        icon: isLoadingModels ? "hourglass" : "arrow.triangle.2.circlepath"
                    ) {
                        fetchModelList()
                    }
                    .disabled(isLoadingModels)

                    modelActionButton(title: "新建", icon: "plus") {
                        customModelID = ""
                        showCustomModelSheet = true
                    }

                    modelActionButton(title: "重置", icon: "arrow.counterclockwise") {
                        settings.modelName = settings.baseURL.lowercased().contains("openrouter")
                            ? "openrouter/auto"
                            : SettingsDefault.modelName
                        flashSavedBanner()
                    }
                }
                .padding(.top, 6)

                Button {
                    showModelLibrary = true
                } label: {
                    Label("打开推荐与自定义模型库", systemImage: "square.stack.3d.up")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                if let modelListError {
                    Text(modelListError)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

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

    private func modelActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func fetchModelList() {
        isLoadingModels = true
        modelListError = nil

        Task {
            do {
                let models = try await ModelCatalogService.shared.fetchModels(
                    baseURL: settings.baseURL,
                    apiKey: settings.apiKey
                )
                await MainActor.run {
                    availableModels = models
                    isLoadingModels = false
                    showModelPicker = true
                }
            } catch {
                await MainActor.run {
                    isLoadingModels = false
                    modelListError = error.localizedDescription
                }
            }
        }
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

// MARK: - Model Catalog

enum ModelCapability: String, CaseIterable, Identifiable, Hashable {
    case tools
    case reasoning
    case structuredOutput
    case imageInput
    case audioInput
    case fileInput

    var id: String { rawValue }

    var name: String {
        switch self {
        case .tools: return "工具调用"
        case .reasoning: return "推理"
        case .structuredOutput: return "结构化输出"
        case .imageInput: return "图片输入"
        case .audioInput: return "音频输入"
        case .fileInput: return "文件输入"
        }
    }

    var icon: String {
        switch self {
        case .tools: return "wrench.and.screwdriver"
        case .reasoning: return "brain.head.profile"
        case .structuredOutput: return "curlybraces"
        case .imageInput: return "photo"
        case .audioInput: return "waveform"
        case .fileInput: return "doc"
        }
    }
}

private enum ModelModerationFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case unmoderated
    case moderated
    case unknown

    var id: String { rawValue }

    var name: String {
        switch self {
        case .all: return "不限"
        case .unmoderated: return "未启用审核"
        case .moderated: return "已启用审核"
        case .unknown: return "未标明"
        }
    }
}

private enum ModelPriceFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case free
    case paid

    var id: String { rawValue }

    var name: String {
        switch self {
        case .all: return "全部"
        case .free: return "免费"
        case .paid: return "付费"
        }
    }
}

struct AvailableModel: Decodable, Identifiable, Hashable {
    struct Pricing: Decodable, Hashable {
        let prompt: String?
        let completion: String?
    }

    struct Provider: Decodable, Hashable {
        let isModerated: Bool?

        enum CodingKeys: String, CodingKey {
            case isModerated = "is_moderated"
        }
    }

    struct Architecture: Decodable, Hashable {
        let inputModalities: [String]?
        let outputModalities: [String]?

        enum CodingKeys: String, CodingKey {
            case inputModalities = "input_modalities"
            case outputModalities = "output_modalities"
        }
    }

    let id: String
    let name: String?
    let description: String?
    let contextLength: Int?
    let pricing: Pricing?
    let supportedParameters: [String]?
    let topProvider: Provider?
    let architecture: Architecture?

    enum CodingKeys: String, CodingKey {
        case id, name, description, pricing
        case contextLength = "context_length"
        case supportedParameters = "supported_parameters"
        case topProvider = "top_provider"
        case architecture
    }

    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? id : trimmed
    }

    var contextDescription: String? {
        guard let contextLength else { return nil }
        if contextLength >= 1_000_000 {
            return String(format: "%.1fM 上下文", Double(contextLength) / 1_000_000)
        }
        if contextLength >= 1_000 {
            return String(format: "%.0fK 上下文", Double(contextLength) / 1_000)
        }
        return "\(contextLength) 上下文"
    }

    var priceDescription: String? {
        guard let pricing else { return nil }
        let prompt = pricing.prompt.flatMap(Double.init).map { $0 * 1_000_000 }
        let completion = pricing.completion.flatMap(Double.init).map { $0 * 1_000_000 }

        if prompt == 0, completion == 0 {
            return "免费"
        }
        guard prompt != nil || completion != nil else { return nil }
        let inputText = prompt.map { Self.priceString($0) } ?? "—"
        let outputText = completion.map { Self.priceString($0) } ?? "—"
        return "输入 $\(inputText) / 输出 $\(outputText)（每百万 Token）"
    }

    var isFree: Bool {
        guard let pricing,
              let prompt = pricing.prompt.flatMap(Double.init),
              let completion = pricing.completion.flatMap(Double.init) else {
            return id.hasSuffix(":free")
        }
        return prompt == 0 && completion == 0
    }

    func supports(_ capability: ModelCapability) -> Bool {
        let parameters = Set((supportedParameters ?? []).map { $0.lowercased() })
        let inputs = Set((architecture?.inputModalities ?? []).map { $0.lowercased() })
        switch capability {
        case .tools:
            return parameters.contains("tools") || parameters.contains("tool_choice")
        case .reasoning:
            return parameters.contains("reasoning") || parameters.contains("include_reasoning")
        case .structuredOutput:
            return parameters.contains("structured_outputs") || parameters.contains("response_format")
        case .imageInput:
            return inputs.contains("image")
        case .audioInput:
            return inputs.contains("audio")
        case .fileInput:
            return inputs.contains("file")
        }
    }

    var visibleCapabilities: [ModelCapability] {
        ModelCapability.allCases.filter { supports($0) }
    }

    private static func priceString(_ value: Double) -> String {
        if value == 0 { return "0" }
        if value < 0.01 { return String(format: "%.4f", value) }
        if value < 1 { return String(format: "%.3f", value) }
        return String(format: "%.2f", value)
    }
}

private struct ModelCatalogResponse: Decodable {
    let data: [AvailableModel]
}

private enum ModelCatalogError: LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case emptyList

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无法生成模型列表地址，请检查 API 基础地址。"
        case .httpError(let code, let message):
            return "获取模型列表失败（HTTP \(code)）：\(message)"
        case .emptyList:
            return "接口没有返回可用模型。"
        }
    }
}

private final class ModelCatalogService {
    static let shared = ModelCatalogService()
    private init() {}

    func fetchModels(baseURL: String, apiKey: String) async throws -> [AvailableModel] {
        let trimmedBase = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedBase.isEmpty, let url = URL(string: trimmedBase + "/models") else {
            throw ModelCatalogError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = Self.serverMessage(from: data)
            throw ModelCatalogError.httpError(http.statusCode, message)
        }

        let result = try JSONDecoder().decode(ModelCatalogResponse.self, from: data)
        guard !result.data.isEmpty else { throw ModelCatalogError.emptyList }
        return result.data.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private static func serverMessage(from data: Data) -> String {
        struct ErrorBody: Decodable {
            struct Detail: Decodable { let message: String? }
            let error: Detail?
        }
        if let decoded = try? JSONDecoder().decode(ErrorBody.self, from: data),
           let message = decoded.error?.message {
            return message
        }
        return String(data: data, encoding: .utf8).map { String($0.prefix(160)) } ?? "未知错误"
    }
}

private struct ModelPickerView: View {
    let models: [AvailableModel]
    @Binding var selectedModel: String
    let onSelect: (AvailableModel) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText: String = ""
    @State private var moderationFilter: ModelModerationFilter = .all
    @State private var priceFilter: ModelPriceFilter = .all
    @State private var minimumContext: Int = 0
    @State private var requiredCapabilities: Set<ModelCapability> = []
    @State private var showingFilters = false

    private var filteredModels: [AvailableModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return models.filter { model in
            let matchesQuery = query.isEmpty ||
                model.id.localizedCaseInsensitiveContains(query) ||
                model.displayName.localizedCaseInsensitiveContains(query) ||
                (model.description?.localizedCaseInsensitiveContains(query) ?? false)

            let matchesModeration: Bool = {
                switch moderationFilter {
                case .all: return true
                case .unmoderated: return model.topProvider?.isModerated == false
                case .moderated: return model.topProvider?.isModerated == true
                case .unknown: return model.topProvider?.isModerated == nil
                }
            }()

            let matchesPrice: Bool = {
                switch priceFilter {
                case .all: return true
                case .free: return model.isFree
                case .paid: return !model.isFree
                }
            }()

            let matchesContext = minimumContext == 0 || (model.contextLength ?? 0) >= minimumContext
            let matchesCapabilities = requiredCapabilities.allSatisfy { model.supports($0) }

            return matchesQuery && matchesModeration && matchesPrice &&
                matchesContext && matchesCapabilities
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if moderationFilter != .all { count += 1 }
        if priceFilter != .all { count += 1 }
        if minimumContext > 0 { count += 1 }
        count += requiredCapabilities.count
        return count
    }

    var body: some View {
        NavigationView {
            Group {
                if filteredModels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 38))
                            .foregroundColor(.secondary)
                        Text("没有符合条件的模型")
                            .font(.headline)
                        Text("请减少筛选条件或清除搜索词。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("重置筛选") {
                            resetFilters()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredModels) { model in
                        Button {
                            selectedModel = model.id
                            onSelect(model)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(model.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedModel == model.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                }

                                Text(model.id)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.accentColor)
                                    .textSelection(.enabled)

                                HStack(spacing: 8) {
                                    if let context = model.contextDescription {
                                        Text(context)
                                    }
                                    if let price = model.priceDescription {
                                        Text(price)
                                    }
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                                if !model.visibleCapabilities.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 5) {
                                            ForEach(model.visibleCapabilities) { capability in
                                                Label(capability.name, systemImage: capability.icon)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.accentColor)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 4)
                                                    .background(Color.accentColor.opacity(0.1))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }

                                if let description = model.description, !description.isEmpty {
                                    Text(description)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }

                                moderationBadge(for: model)
                            }
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索名称、模型 ID 或描述")
            .navigationTitle("选择模型（\(filteredModels.count)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: activeFilterCount == 0
                                  ? "line.3.horizontal.decrease.circle"
                                  : "line.3.horizontal.decrease.circle.fill")
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2)
                            }
                        }
                    }
                    .accessibilityLabel("筛选模型")
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingFilters) {
            ModelFilterView(
                moderationFilter: $moderationFilter,
                priceFilter: $priceFilter,
                minimumContext: $minimumContext,
                requiredCapabilities: $requiredCapabilities,
                resultCount: filteredModels.count,
                onReset: resetFilters
            )
        }
    }

    @ViewBuilder
    private func moderationBadge(for model: AvailableModel) -> some View {
        if let moderated = model.topProvider?.isModerated {
            Label(
                moderated ? "服务商标记：启用内容审查" : "服务商标记：未启用内容审查",
                systemImage: moderated ? "checkmark.shield" : "shield.slash"
            )
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(moderated ? .orange : .green)
        } else {
            Label("服务商未提供审查状态", systemImage: "questionmark.shield")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private func resetFilters() {
        moderationFilter = .all
        priceFilter = .all
        minimumContext = 0
        requiredCapabilities.removeAll()
    }
}

private struct ModelFilterView: View {
    @Binding var moderationFilter: ModelModerationFilter
    @Binding var priceFilter: ModelPriceFilter
    @Binding var minimumContext: Int
    @Binding var requiredCapabilities: Set<ModelCapability>
    let resultCount: Int
    let onReset: () -> Void

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("价格", selection: $priceFilter) {
                        ForEach(ModelPriceFilter.allCases) { filter in
                            Text(filter.name).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("价格")
                }

                Section {
                    Picker("审查状态", selection: $moderationFilter) {
                        ForEach(ModelModerationFilter.allCases) { filter in
                            Text(filter.name).tag(filter)
                        }
                    }
                } header: {
                    Text("内容审查")
                } footer: {
                    Text("此状态来自 OpenRouter 的 top_provider.is_moderated 字段。“未启用审核”只表示当前服务商这样标记，不保证模型没有自身限制，也不代表可以绕过平台规则。")
                }

                Section {
                    Picker("最低上下文", selection: $minimumContext) {
                        Text("不限").tag(0)
                        Text("至少 32K").tag(32_000)
                        Text("至少 64K").tag(64_000)
                        Text("至少 128K").tag(128_000)
                        Text("至少 256K").tag(256_000)
                        Text("至少 1M").tag(1_000_000)
                    }
                } header: {
                    Text("上下文长度")
                }

                Section {
                    ForEach(ModelCapability.allCases) { capability in
                        Toggle(
                            isOn: Binding(
                                get: { requiredCapabilities.contains(capability) },
                                set: { enabled in
                                    if enabled {
                                        requiredCapabilities.insert(capability)
                                    } else {
                                        requiredCapabilities.remove(capability)
                                    }
                                }
                            )
                        ) {
                            Label(capability.name, systemImage: capability.icon)
                        }
                    }
                } header: {
                    Text("必须支持的能力")
                } footer: {
                    Text("同时打开多个能力时，模型必须满足全部条件。能力信息来自接口返回的 supported_parameters 和 architecture 字段。")
                }

                Section {
                    Button(role: .destructive) {
                        onReset()
                    } label: {
                        Label("重置全部筛选", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("筛选模型（\(resultCount)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct CustomModelView: View {
    @Binding var modelID: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("例如：nousresearch/hermes-4-70b", text: $modelID)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(size: 14, design: .monospaced))
                } header: {
                    Text("模型 ID")
                } footer: {
                    Text("填写提供商要求的完整模型 ID。OpenRouter 通常使用“作者/模型名”格式。")
                }
            }
            .navigationTitle("新建自定义模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存", action: onSave)
                        .disabled(modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

