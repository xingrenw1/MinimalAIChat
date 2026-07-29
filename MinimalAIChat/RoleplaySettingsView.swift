import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct RoleplaySettingsView: View {
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @AppStorage(RoleplaySettingsKey.enabled) private var roleplayEnabled = false
    @AppStorage(RoleplaySettingsKey.activeCharacterID) private var activeCharacterID = ""

    @State private var characters = RoleplayCharacterManager.loadCharacters()
    @State private var showingImporter = false
    @State private var showingNewCharacter = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var showingResult = false

    var body: some View {
        Form {
            Section {
                Toggle("启用角色扮演", isOn: $roleplayEnabled)
                    .disabled(characters.isEmpty || activeCharacter == nil)

                if let character = activeCharacter {
                    CharacterSummaryRow(character: character, selected: true)

                    Button {
                        roleplayEnabled = true
                        chatViewModel.startNewChat()
                        resultTitle = "已新建角色对话"
                        resultMessage = "当前对话已使用“\(character.name)”的角色设定和开场白。"
                        showingResult = true
                    } label: {
                        Label("使用当前角色新建对话", systemImage: "plus.bubble")
                    }
                } else {
                    Text("请先导入或手动创建一张角色卡。")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("当前角色")
            } footer: {
                Text("切换角色后建议新建对话，避免不同角色的聊天记录混在一起。")
            }

            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label("导入酒馆角色卡", systemImage: "square.and.arrow.down")
                }

                Button {
                    showingNewCharacter = true
                } label: {
                    Label("手动新建角色", systemImage: "square.and.pencil")
                }
            } header: {
                Text("添加角色")
            } footer: {
                Text("支持 SillyTavern Character Card V1/V2/V3 的 JSON，以及内嵌 chara 或 ccv3 数据的 PNG。普通 PNG 图片不包含角色设定，不能作为角色卡导入。")
            }

            if !characters.isEmpty {
                Section {
                    ForEach(characters) { character in
                        NavigationLink {
                            RoleplayCharacterEditorView(character: character) {
                                reloadCharacters()
                            }
                        } label: {
                            CharacterSummaryRow(
                                character: character,
                                selected: character.id.uuidString == activeCharacterID
                            )
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                select(character)
                            } label: {
                                Label("使用", systemImage: "checkmark.circle")
                            }
                            .tint(.accentColor)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(character)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                select(character)
                            } label: {
                                Label("设为当前角色", systemImage: "checkmark.circle")
                            }
                        }
                    }
                } header: {
                    Text("角色库（\(characters.count)）")
                } footer: {
                    Text("向右轻扫角色可快速启用；向左轻扫可删除。点击角色可以查看和编辑完整设定。")
                }
            }
        }
        .navigationTitle("角色扮演与酒馆")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImporter) {
            RoleplayDocumentPicker { result in
                handleImport(result)
            }
        }
        .sheet(isPresented: $showingNewCharacter) {
            NavigationView {
                RoleplayCharacterEditorView(character: nil) {
                    reloadCharacters()
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert(isPresented: $showingResult) {
            Alert(
                title: Text(resultTitle),
                message: Text(resultMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .onAppear {
            reloadCharacters()
        }
    }

    private var activeCharacter: RoleplayCharacter? {
        characters.first { $0.id.uuidString == activeCharacterID }
    }

    private func select(_ character: RoleplayCharacter) {
        activeCharacterID = character.id.uuidString
        roleplayEnabled = true
    }

    private func delete(_ character: RoleplayCharacter) {
        do {
            try RoleplayCharacterManager.delete(character)
            reloadCharacters()
        } catch {
            showError(error)
        }
    }

    private func reloadCharacters() {
        characters = RoleplayCharacterManager.loadCharacters()
        if characters.isEmpty {
            activeCharacterID = ""
            roleplayEnabled = false
        } else if activeCharacter == nil, let first = characters.first {
            activeCharacterID = first.id.uuidString
        }
    }

    private func handleImport(_ result: Result<ParsedRoleplayCard, Error>) {
        switch result {
        case .success(let parsed):
            do {
                try RoleplayCharacterManager.upsert(parsed.character, avatarData: parsed.avatarData)
                activeCharacterID = parsed.character.id.uuidString
                roleplayEnabled = true
                reloadCharacters()
                resultTitle = "导入成功"
                resultMessage = "已导入“\(parsed.character.name)”（\(parsed.character.sourceFormat)）。"
                showingResult = true
            } catch {
                showError(error)
            }
        case .failure(let error):
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        resultTitle = "操作失败"
        resultMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showingResult = true
    }
}

private struct CharacterSummaryRow: View {
    let character: RoleplayCharacter
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let avatar = RoleplayCharacterManager.avatar(for: character) {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.accentColor.opacity(0.14)
                        Text(String(character.name.prefix(1)))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(character.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(character.sourceFormat)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 3)
    }
}

struct RoleplayCharacterEditorView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage(RoleplaySettingsKey.enabled) private var roleplayEnabled = false
    @AppStorage(RoleplaySettingsKey.activeCharacterID) private var activeCharacterID = ""

    @State private var character: RoleplayCharacter
    @State private var avatarImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let isNewCharacter: Bool
    private let onSave: () -> Void

    init(character: RoleplayCharacter?, onSave: @escaping () -> Void) {
        let draft = character ?? RoleplayCharacter()
        _character = State(initialValue: draft)
        _avatarImage = State(initialValue: character.flatMap { RoleplayCharacterManager.avatar(for: $0) })
        isNewCharacter = character == nil
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Button {
                        showingImagePicker = true
                    } label: {
                        Group {
                            if let avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color.accentColor.opacity(0.14)
                                    Image(systemName: "person.crop.square")
                                        .font(.system(size: 32))
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } header: {
                Text("角色头像")
            } footer: {
                Text("点击头像可从相册选择。PNG 角色卡导入时会自动使用卡面。")
            }

            Section {
                TextField("角色名称（必填）", text: $character.name)
                TextField("作者（可选）", text: $character.creator)
                TextField(
                    "标签，用逗号分隔",
                    text: Binding(
                        get: { character.tags.joined(separator: ", ") },
                        set: {
                            character.tags = $0
                                .components(separatedBy: CharacterSet(charactersIn: ",，"))
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                        }
                    )
                )
            } header: {
                Text("基本信息")
            }

            RoleplayTextEditorSection(title: "角色说明", placeholder: "身份、经历、外貌、能力等完整设定", text: $character.characterDescription, minHeight: 150)
            RoleplayTextEditorSection(title: "性格", placeholder: "角色的性格、偏好和行为逻辑", text: $character.personality)
            RoleplayTextEditorSection(title: "场景", placeholder: "世界观与当前剧情背景", text: $character.scenario)
            RoleplayTextEditorSection(title: "首次消息", placeholder: "新建角色对话时显示的开场白", text: $character.firstMessage, minHeight: 130)
            RoleplayTextEditorSection(title: "示例对话", placeholder: "支持 {{char}} 与 {{user}} 酒馆变量", text: $character.exampleDialogue, minHeight: 140)
            RoleplayTextEditorSection(title: "角色系统提示", placeholder: "角色专用的系统规则", text: $character.systemPrompt)
            RoleplayTextEditorSection(title: "后置指令", placeholder: "Post History Instructions", text: $character.postHistoryInstructions)

            Section {
                TextEditor(
                    text: Binding(
                        get: { character.alternateGreetings.joined(separator: "\n\n---\n\n") },
                        set: {
                            character.alternateGreetings = $0
                                .components(separatedBy: "\n\n---\n\n")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                        }
                    )
                )
                .frame(minHeight: 120)
            } header: {
                Text("备用开场白")
            } footer: {
                Text("使用空行、三个短横线、空行分隔多个开场白。")
            }
        }
        .navigationTitle(isNewCharacter ? "新建角色" : "编辑角色")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    save()
                }
                .font(.system(size: 16, weight: .semibold))
                .disabled(character.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            SystemImagePicker(selectedImage: $avatarImage, allowsEditing: true)
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("无法保存角色"),
                message: Text(errorMessage),
                dismissButton: .default(Text("确定"))
            )
        }
    }

    private func save() {
        character.name = character.name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try RoleplayCharacterManager.upsert(character)
            if let avatarImage {
                try RoleplayCharacterManager.saveAvatar(avatarImage, for: character.id)
            }
            activeCharacterID = character.id.uuidString
            roleplayEnabled = true
            onSave()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showingError = true
        }
    }
}

private struct RoleplayTextEditorSection: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 110

    var body: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
            }
        } header: {
            Text(title)
        }
    }
}

struct RoleplayDocumentPicker: UIViewControllerRepresentable {
    let completion: (Result<ParsedRoleplayCard, Error>) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.json, UTType.png],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: RoleplayDocumentPicker

        init(parent: RoleplayDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.presentationMode.wrappedValue.dismiss()
            guard let url = urls.first else {
                parent.completion(.failure(RoleplayCardError.unsupportedFile))
                return
            }
            do {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                let parsed = try RoleplayCardParser.parse(
                    data: data,
                    fileExtension: url.pathExtension
                )
                parent.completion(.success(parsed))
            } catch {
                parent.completion(.failure(error))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
