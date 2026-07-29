import SwiftUI

// MARK: - MasterSettingsView

/// Master settings sheet presenting navigation options for Profile and API settings.
struct MasterSettingsView: View {

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section {
                    NavigationLink(destination: ProfileSettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                            Text("编辑个人资料")
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink(destination: PromptSettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                            Text("AI 人格设定")
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink(destination: ProactiveChatSettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "message.badge")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                            Text("主动聊天")
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink(destination: SettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "network")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                            Text("API 与连接设置")
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 4)
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                            Text("关于")
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("设置")
                }
            }
            .navigationTitle("设置")
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

// MARK: - ProfileSettingsView

/// Sub-view for editing the user's display name.
struct ProfileSettingsView: View {

    @AppStorage("userName") private var userName: String = ""
    @EnvironmentObject private var settings: SettingsViewModel
    @State private var showingImagePicker = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Button {
                        showingImagePicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            if let img = settings.profileImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else if userName.isEmpty {
                                Image(systemName: "person")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(.accentColor)
                            } else {
                                Text(String(userName.prefix(1)).uppercased())
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                            
                            Circle()
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                .frame(width: 80, height: 80)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 10)
            } header: {
                Text("头像")
            }

            Section {
                TextField("例如：老师", text: $userName)
                    .font(.system(size: 16))
                    .padding(.vertical, 4)
            } header: {
                Text("你的名字")
            } footer: {
                Text("用于个性化你的 AI 对话。")
            }
        }
        .navigationTitle("编辑个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePicker) {
            SystemImagePicker(selectedImage: Binding(get: { settings.profileImage }, set: { newImg in
                if let newImg = newImg {
                    settings.updateProfileImage(newImg)
                }
            }))
        }
    }
}

// MARK: - PromptSettingsView

/// Sub-view for editing the AI system prompt.
struct PromptSettingsView: View {

    @AppStorage("customSystemPrompt") private var customSystemPrompt: String = ""
    @State private var showResetAlert: Bool = false

    var body: some View {
        Form {
            Section {
                TextEditor(text: $customSystemPrompt)
                    .frame(minHeight: 150)
                    .font(.system(size: 16))
                    .padding(.vertical, 4)
                
                Button(action: {
                    showResetAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("恢复默认")
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.red)
                }
            } header: {
                Text("系统提示词")
            } footer: {
                Text("这段文字决定 AI 的行为。可在提示词中使用 {name} 自动插入你的名字。")
            }
        }
        .onAppear {
            if customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                customSystemPrompt = ChatConstants.defaultSystemPrompt
            }
        }
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("恢复默认提示词？"),
                message: Text("当前自定义提示词将被默认内容替换。"),
                primaryButton: .destructive(Text("恢复")) {
                    withAnimation {
                        customSystemPrompt = ChatConstants.defaultSystemPrompt
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .navigationTitle("AI 人格设定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ProactiveChatSettingsView

struct ProactiveChatSettingsView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @ObservedObject private var manager = ProactiveChatManager.shared

    private let hourOptions = Array(0..<24)

    var body: some View {
        Form {
            Section {
                Toggle("启用主动聊天", isOn: $settings.proactiveEnabled)
                    .onChange(of: settings.proactiveEnabled) { _ in
                        Task { await chatViewModel.proactiveSettingsDidChange() }
                    }
            } footer: {
                Text("开启后，应用会在前台预先生成下一条角色消息，并在随机时间通过本地通知发送。消息到期后会自动写入对应聊天记录。")
            }

            Section {
                Stepper("最短间隔：\(settings.proactiveMinimumMinutes) 分钟", value: $settings.proactiveMinimumMinutes, in: 5...1440, step: 5)
                Stepper("最长间隔：\(settings.proactiveMaximumMinutes) 分钟", value: $settings.proactiveMaximumMinutes, in: 5...2880, step: 5)
            } header: {
                Text("发送间隔")
            } footer: {
                Text("系统会在最短与最长间隔之间随机选择时间。若最短值大于最长值，应用会自动按较小值到较大值计算。")
            }

            Section {
                Picker("安静时段开始", selection: $settings.proactiveQuietStartHour) {
                    ForEach(hourOptions, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                Picker("安静时段结束", selection: $settings.proactiveQuietEndHour) {
                    ForEach(hourOptions, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
            } header: {
                Text("安静时段")
            } footer: {
                Text("开始与结束相同表示不启用安静时段。跨午夜时段会自动处理。")
            }

            Section {
                TextField("通知标题", text: $settings.proactiveNotificationTitle)
                TextEditor(text: $settings.proactivePrompt)
                    .frame(minHeight: 160)

                Button("恢复默认主动消息提示词") {
                    settings.proactivePrompt = SettingsDefault.proactivePrompt
                }
                .foregroundColor(.red)
            } header: {
                Text("角色主动消息")
            } footer: {
                Text("提示词会与当前角色设定和聊天记录一起发送给当前 API。默认要求模型只使用中文输出。")
            }

            Section {
                if manager.isPreparing {
                    HStack {
                        ProgressView()
                        Text("正在准备下一条主动消息…")
                    }
                } else if let date = manager.nextDeliveryDate {
                    HStack {
                        Text("下一条消息")
                        Spacer()
                        Text(date, style: .date)
                        Text(date, style: .time)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(settings.proactiveEnabled ? "需要先在当前会话中发送至少一条用户消息。" : "主动聊天已关闭。")
                        .foregroundColor(.secondary)
                }

                if let error = manager.lastPreparationError {
                    Text("准备失败：\(error)")
                        .foregroundColor(.red)
                }
            } header: {
                Text("状态")
            }
        }
        .navigationTitle("主动聊天")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Task { await chatViewModel.proactiveSettingsDidChange() }
        }
    }
}

// MARK: - Preview

struct MasterSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MasterSettingsView()
            .environmentObject(SettingsViewModel())
    }
}

// MARK: - AboutView

/// Simple about screen with links and version info.
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text("版本")
                        Spacer()
                        Text(version)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("应用信息")
            }

            Section {
                Button(action: {
                    if let url = URL(string: "https://github.com/valerioghost/MinimalAIChat") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        Text("GitHub 仓库")
                            .foregroundColor(.primary)
                    }
                }

                Button(action: {
                    if let url = URL(string: "https://discord.gg/ryy2h6j5aq") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        Text("Discord 社区")
                            .foregroundColor(.primary)
                    }
                }
            } header: {
                Text("链接")
            } footer: {
                Text("加入 Discord 社区以获取支持或提交反馈。")
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
