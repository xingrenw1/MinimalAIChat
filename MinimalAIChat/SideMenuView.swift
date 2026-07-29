import SwiftUI

/// Sliding side menu — shows chat history sessions and a "New Chat" button.
struct SideMenuView: View {

    @EnvironmentObject private var viewModel: ChatViewModel
    @EnvironmentObject private var settings: SettingsViewModel
    @Binding var isMenuOpen: Bool

    @AppStorage("userName") private var userName: String = ""
    @State private var showClearAlert: Bool = false
    @State private var isShowingMasterSettings: Bool = false
    @State private var sessionToRename: ChatSession?

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                menuHeader

                Divider()
                    .padding(.vertical, 8)

                // ── New Chat Button ────────────────────────────────────────
                newChatButton

                // ── Clear Chat Button ─────────────────────────────────────
                clearChatButton

                // ── Section Title ─────────────────────────────────────────
                Text("最近对话")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 6)

                // ── Session List ──────────────────────────────────────────
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.sessions) { session in
                            SessionRowView(
                                session: session,
                                isActive: session.id == viewModel.activeSessionID,
                                onTap: {
                                    viewModel.selectSession(session)
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isMenuOpen = false
                                    }
                                },
                                onRename: {
                                    sessionToRename = session
                                },
                                onDelete: {
                                    viewModel.deleteSession(session)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }

                Spacer()

                Divider()

                // ── Footer ────────────────────────────────────────────────
                menuFooter
            }
        }
        .sheet(isPresented: $isShowingMasterSettings) {
            MasterSettingsView()
                .environmentObject(settings)
        }
        .sheet(item: $sessionToRename) { session in
            RenameSessionView(session: session) { title in
                viewModel.renameSession(session, to: title)
            }
        }
        // ── Clear Chat confirmation alert ─────────────────────────────────
        .alert(isPresented: $showClearAlert) {
            Alert(
                title: Text("删除对话"),
                message: Text("此对话将从历史记录中永久删除。"),
                primaryButton: .destructive(Text("删除")) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMenuOpen = false
                    }
                    // Small delay so the menu slides away before the list updates
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        viewModel.deleteCurrentSession()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Sub-views

    private var menuHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MinimalAI")
                    .font(.system(size: 17, weight: .bold))
                Text("你的 AI 助手")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var newChatButton: some View {
        Button {
            viewModel.startNewChat()
            withAnimation(.easeInOut(duration: 0.3)) {
                isMenuOpen = false
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                Text("新建对话")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
            }
            .foregroundColor(.accentColor)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private var clearChatButton: some View {
        Button {
            showClearAlert = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 22)
                Text("删除对话")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
            }
            .foregroundColor(Color(.systemRed))
            .padding(.vertical, 11)
            .padding(.horizontal, 16)
            .background(Color(.systemRed).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private var menuFooter: some View {
        Button {
            isShowingMasterSettings = true
        } label: {
            HStack(spacing: 14) {
                // Avatar: profile image, or first character of the user's name, or a person icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    if let img = settings.profileImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    } else if userName.isEmpty {
                        Image(systemName: "person")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundColor(.accentColor)
                    } else {
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(userName.isEmpty ? "设置你的名字" : userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(userName.isEmpty ? .secondary : .primary)
                    Text("个人设置")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            // A clear background ensures the entire area is tappable
            .background(Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Row

struct SessionRowView: View {

    let session: ChatSession
    let isActive: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? .accentColor : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title == "New Chat" ? "新对话" : session.title)
                        .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .accentColor : .primary)
                        .lineLimit(1)

                    Text(relativeDate(session.lastUpdated))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                isActive
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct RenameSessionView: View {
    let session: ChatSession
    let onSave: (String) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var title: String

    init(session: ChatSession, onSave: @escaping (String) -> Void) {
        self.session = session
        self.onSave = onSave
        _title = State(initialValue: session.title)
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("话题名称", text: $title)
            }
            .navigationTitle("重命名话题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(title)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Preview

struct SideMenuView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = SettingsViewModel()
        SideMenuView(isMenuOpen: .constant(true))
            .environmentObject(ChatViewModel(settings: settings))
            .frame(width: 280)
            .previewLayout(.sizeThatFits)
    }
}
