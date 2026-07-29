import SwiftUI

/// ChatBox-style composer with attachments, web search and quick model switching.
struct InputBarView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    @EnvironmentObject private var settings: SettingsViewModel
    @FocusState private var isTextFieldFocused: Bool

    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingModelLibrary = false
    @State private var activeAlert: ComposerAlert?

    private let minHeight: CGFloat = 38
    private let maxHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.pendingAttachments.isEmpty {
                attachmentStrip
            }

            quickTools

            HStack(alignment: .bottom, spacing: 8) {
                attachmentMenu
                textComposer
                sendButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: -2)
        )
        .sheet(isPresented: $showingImagePicker) {
            SystemImagePicker(selectedImage: Binding(
                get: { nil },
                set: { image in
                    guard let image else { return }
                    importImage(image)
                }
            ))
        }
        .sheet(isPresented: $showingDocumentPicker) {
            ChatAttachmentDocumentPicker { result in
                switch result {
                case .success(let attachments):
                    do {
                        try viewModel.addPendingAttachments(attachments)
                    } catch {
                        activeAlert = ComposerAlert(title: "无法添加附件", message: error.localizedDescription)
                    }
                case .failure(let error):
                    activeAlert = ComposerAlert(title: "无法添加附件", message: error.localizedDescription)
                }
            }
        }
        .sheet(isPresented: $showingModelLibrary) {
            ModelLibraryView()
                .environmentObject(settings)
        }
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("好"))
            )
        }
    }

    private var quickTools: some View {
        HStack(spacing: 8) {
            Button {
                showingModelLibrary = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "cube")
                    Text(currentModelDisplayName)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                if settings.hasTavilyKey {
                    settings.webSearchEnabled.toggle()
                } else {
                    activeAlert = ComposerAlert(
                        title: "尚未配置联网搜索",
                        message: "请在“设置 → API 与连接设置 → 高级选项”中填写 Tavily API Key，之后即可在聊天栏随时开关联网搜索。"
                    )
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: settings.canUseWebSearch ? "globe.americas.fill" : "globe.americas")
                    Text("联网")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(settings.canUseWebSearch ? .white : .secondary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(settings.canUseWebSearch ? Color.accentColor : Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            if !viewModel.pendingAttachments.isEmpty {
                Text("\(viewModel.pendingAttachments.count)/\(ChatAttachmentManager.maximumAttachmentCount)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var attachmentMenu: some View {
        Menu {
            Button {
                showingImagePicker = true
            } label: {
                Label("选择照片", systemImage: "photo")
            }
            Button {
                showingDocumentPicker = true
            } label: {
                Label("选择文件", systemImage: "doc")
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 38, height: 38)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
    }

    private var textComposer: some View {
        ZStack(alignment: .leading) {
            if viewModel.inputText.isEmpty {
                Text(viewModel.pendingAttachments.isEmpty ? "输入消息" : "添加说明（可选）")
                    .foregroundColor(Color(.placeholderText))
                    .font(.system(size: 16))
                    .padding(.leading, 6)
                    .padding(.bottom, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $viewModel.inputText)
                .font(.system(size: 16))
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .fixedSize(horizontal: false, vertical: true)
                .focused($isTextFieldFocused)
                .scrollContentBackgroundHidden()
                .padding(.vertical, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var sendButton: some View {
        Button(action: sendTapped) {
            ZStack {
                Circle()
                    .fill(canSend ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(width: 38, height: 38)
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canSend ? .white : Color(.tertiaryLabel))
            }
        }
        .disabled(!canSend)
        .animation(.easeInOut(duration: 0.15), value: canSend)
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(viewModel.pendingAttachments) { attachment in
                    PendingAttachmentCard(attachment: attachment) {
                        viewModel.removePendingAttachment(attachment)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var currentModelDisplayName: String {
        if let model = ModelLibraryStore.shared.model(for: settings.modelName) {
            return model.name
        }
        return settings.modelName.split(separator: "/").last.map(String.init) ?? settings.modelName
    }

    private var canSend: Bool {
        (!viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
         !viewModel.pendingAttachments.isEmpty) &&
        !viewModel.isTyping
    }

    private func importImage(_ image: UIImage) {
        do {
            let attachment = try ChatAttachmentManager.importImage(image)
            try viewModel.addPendingAttachments([attachment])
        } catch {
            activeAlert = ComposerAlert(title: "无法添加图片", message: error.localizedDescription)
        }
    }

    private func sendTapped() {
        viewModel.sendMessage()
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        isTextFieldFocused = true
    }
}

private struct PendingAttachmentCard: View {
    let attachment: ChatAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if attachment.kind == .image,
                   let image = ChatAttachmentManager.image(for: attachment) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipped()
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Image(systemName: attachmentIcon)
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                        Text(attachment.fileName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(2)
                        Text(attachment.sizeDescription)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(width: 120, height: 72, alignment: .leading)
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.black.opacity(0.72))
                    .clipShape(Circle())
            }
            .offset(x: 5, y: -5)
        }
        .padding(.top, 5)
        .padding(.trailing, 5)
    }

    private var attachmentIcon: String {
        switch attachment.kind {
        case .pdf: return "doc.richtext"
        case .text: return "doc.text"
        case .file: return "doc"
        case .image: return "photo"
        }
    }
}

private struct ComposerAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private extension View {
    func scrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, *) {
            return AnyView(self.scrollContentBackground(.hidden))
        } else {
            return AnyView(self.onAppear {
                UITextView.appearance().backgroundColor = .clear
            })
        }
    }
}

struct InputBarView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = SettingsViewModel()
        VStack {
            Spacer()
            InputBarView()
        }
        .environmentObject(settings)
        .environmentObject(ChatViewModel(settings: settings))
        .ignoresSafeArea(edges: .bottom)
    }
}
