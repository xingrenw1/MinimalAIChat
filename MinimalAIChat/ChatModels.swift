import Foundation

enum ChatConstants {
    static let defaultSystemPrompt = "你是一位友好、准确且乐于助人的 AI 助手。用户的名字是 {name}，合适时可以称呼用户的名字。默认使用简体中文回答，表达自然、简洁。\n\n重要格式规则：列表中的每个项目必须单独占一行，不要把多个项目连在同一行。编号步骤、章节和其他列表也遵循此规则。可以使用 Markdown 粗体表示标题或关键词。"
}

// MARK: - Message Role

enum MessageRole: String, Codable {
    case user      = "user"
    case assistant = "assistant"
    case system    = "system"    // reserved for future system prompts
}

// MARK: - ChatMessage

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isError: Bool
    var isComplete: Bool
    var attachments: [ChatAttachment]

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, isError, isComplete, attachments
    }

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isError: Bool = false,
        isComplete: Bool = true,
        attachments: [ChatAttachment] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.isComplete = isComplete
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
        // Default true: old persisted messages were always fully completed replies
        isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? true
        attachments = try container.decodeIfPresent([ChatAttachment].self, forKey: .attachments) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isError, forKey: .isError)
        try container.encode(isComplete, forKey: .isComplete)
        try container.encode(attachments, forKey: .attachments)
    }
}

// MARK: - ChatSession

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var lastUpdated: Date

    init(id: UUID = UUID(), title: String, messages: [ChatMessage] = [], lastUpdated: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.lastUpdated = lastUpdated
    }
}


// MARK: - Mock Data

extension ChatSession {
    static let mockSessions: [ChatSession] = []
}
