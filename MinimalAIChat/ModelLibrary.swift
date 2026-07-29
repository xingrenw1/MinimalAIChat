import Foundation
import SwiftUI

struct SavedModel: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var provider: String
    var summary: String
    var tags: [String]
    var isRecommended: Bool

    var policyLabel: String {
        if tags.contains("开放型") { return "开放型" }
        return "提供商规则"
    }
}

@MainActor
final class ModelLibraryStore: ObservableObject {
    static let shared = ModelLibraryStore()
    private static let storageKey = "savedModelLibrary.v1"

    @Published private(set) var models: [SavedModel] = []

    static let recommended: [SavedModel] = [
        SavedModel(id: "openai/gpt-5.6-sol", name: "GPT-5.6 SOL", provider: "OpenAI", summary: "综合能力、编程与复杂任务", tags: ["推理", "工具", "多模态"], isRecommended: true),
        SavedModel(id: "anthropic/claude-sonnet-5", name: "Claude Sonnet 5", provider: "Anthropic", summary: "写作、长文本与角色理解", tags: ["写作", "长上下文", "多模态"], isRecommended: true),
        SavedModel(id: "google/gemini-3.6-flash", name: "Gemini 3.6 Flash", provider: "Google", summary: "快速、多模态与高性价比", tags: ["快速", "多模态", "工具"], isRecommended: true),
        SavedModel(id: "deepseek/deepseek-v4-flash", name: "DeepSeek V4 Flash", provider: "DeepSeek", summary: "中文、推理与代码", tags: ["中文", "推理", "代码"], isRecommended: true),
        SavedModel(id: "x-ai/grok-4.5", name: "Grok 4.5", provider: "xAI", summary: "通用聊天与实时话题", tags: ["通用", "工具"], isRecommended: true),
        SavedModel(id: "qwen/qwen3.7-plus", name: "Qwen 3.7 Plus", provider: "Qwen", summary: "中文创作与综合任务", tags: ["中文", "写作", "工具"], isRecommended: true),
        SavedModel(id: "mistralai/mistral-large-2512", name: "Mistral Large", provider: "Mistral", summary: "通用、速度与长文本", tags: ["通用", "长上下文"], isRecommended: true),
        SavedModel(id: "minimax/minimax-m3", name: "MiniMax M3", provider: "MiniMax", summary: "中文对话、长篇与角色扮演", tags: ["中文", "角色扮演", "长文本"], isRecommended: true),
        SavedModel(id: "nousresearch/hermes-4-70b", name: "Hermes 4 70B", provider: "Nous Research", summary: "角色扮演、创作与高可控性", tags: ["角色扮演", "开放型", "长上下文"], isRecommended: true),
        SavedModel(id: "cognitivecomputations/dolphin-mistral-24b-venice-edition", name: "Venice Uncensored", provider: "Cognitive Computations", summary: "开放型创作与角色扮演", tags: ["角色扮演", "开放型", "创作"], isRecommended: true)
    ]

    private init() {
        load()
    }

    func model(for id: String) -> SavedModel? {
        models.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
    }

    func add(
        id: String,
        name: String? = nil,
        provider: String? = nil,
        summary: String = "自定义模型",
        tags: [String] = ["自定义"]
    ) {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return }
        if models.contains(where: { $0.id.caseInsensitiveCompare(trimmedID) == .orderedSame }) {
            return
        }
        let parts = trimmedID.split(separator: "/", maxSplits: 1).map(String.init)
        let inferredProvider = provider ?? (parts.first ?? "自定义")
        let inferredName = name ?? (parts.last ?? trimmedID)
        models.append(
            SavedModel(
                id: trimmedID,
                name: inferredName,
                provider: inferredProvider,
                summary: summary,
                tags: tags,
                isRecommended: false
            )
        )
        persist()
    }

    func remove(_ model: SavedModel) {
        guard !model.isRecommended else { return }
        models.removeAll { $0.id == model.id }
        persist()
    }

    func restoreRecommended() {
        let custom = models.filter { !$0.isRecommended }
        models = Self.recommended + custom.filter { customModel in
            !Self.recommended.contains(where: { $0.id == customModel.id })
        }
        persist()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([SavedModel].self, from: data) {
            let custom = saved.filter { savedModel in
                !Self.recommended.contains(where: { $0.id == savedModel.id })
            }
            models = Self.recommended + custom
        } else {
            models = Self.recommended
        }
        deduplicate()
    }

    private func deduplicate() {
        var seen = Set<String>()
        models = models.filter { seen.insert($0.id.lowercased()).inserted }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

struct ModelLibraryView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var store = ModelLibraryStore.shared
    @State private var searchText = ""
    @State private var showingAddModel = false

    private var filteredModels: [SavedModel] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return store.models }
        return store.models.filter { model in
            model.name.localizedCaseInsensitiveContains(keyword) ||
            model.id.localizedCaseInsensitiveContains(keyword) ||
            model.provider.localizedCaseInsensitiveContains(keyword) ||
            model.tags.joined(separator: " ").localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(filteredModels) { model in
                        Button {
                            settings.modelName = model.id
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            ModelLibraryRow(model: model, isSelected: settings.modelName == model.id)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !model.isRecommended {
                                Button(role: .destructive) {
                                    store.remove(model)
                                } label: {
                                    Label("删除自定义模型", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("推荐与自定义模型")
                } footer: {
                    Text("“开放型”仅表示模型定位较少拒绝，不保证无审查；实际内容规则仍由 OpenRouter、模型提供商和具体路由决定。")
                }

                Section {
                    Button {
                        showingAddModel = true
                    } label: {
                        Label("添加自定义模型 ID", systemImage: "plus")
                    }
                    Button {
                        store.restoreRecommended()
                    } label: {
                        Label("恢复 10 个推荐模型", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索名称、提供商或能力")
            .navigationTitle("选择模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddModel) {
                AddSavedModelView()
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct ModelLibraryRow: View {
    let model: SavedModel
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "cube")
                .font(.system(size: 19))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(model.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    if model.isRecommended {
                        Text("推荐")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                }
                Text(model.id)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(model.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(model.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(tag == "开放型" ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.1))
                                .foregroundColor(tag == "开放型" ? .orange : .secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AddSavedModelView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var store = ModelLibraryStore.shared
    @State private var modelID = ""
    @State private var displayName = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("例如：provider/model-name", text: $modelID)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("显示名称（可选）", text: $displayName)
                } footer: {
                    Text("请输入 OpenRouter 模型 ID；也可以在“API 与连接设置”中获取在线模型列表并按能力筛选。")
                }
            }
            .navigationTitle("添加模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        store.add(id: modelID, name: displayName.isEmpty ? nil : displayName)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
