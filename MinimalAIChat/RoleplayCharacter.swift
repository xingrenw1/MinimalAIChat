import Foundation
import UIKit

enum RoleplaySettingsKey {
    static let enabled = "roleplay.enabled"
    static let activeCharacterID = "roleplay.activeCharacterID"
}

struct RoleplayCharacter: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var characterDescription: String
    var personality: String
    var scenario: String
    var firstMessage: String
    var exampleDialogue: String
    var systemPrompt: String
    var postHistoryInstructions: String
    var alternateGreetings: [String]
    var tags: [String]
    var creator: String
    var sourceFormat: String

    init(
        id: UUID = UUID(),
        name: String = "",
        characterDescription: String = "",
        personality: String = "",
        scenario: String = "",
        firstMessage: String = "",
        exampleDialogue: String = "",
        systemPrompt: String = "",
        postHistoryInstructions: String = "",
        alternateGreetings: [String] = [],
        tags: [String] = [],
        creator: String = "",
        sourceFormat: String = "手动创建"
    ) {
        self.id = id
        self.name = name
        self.characterDescription = characterDescription
        self.personality = personality
        self.scenario = scenario
        self.firstMessage = firstMessage
        self.exampleDialogue = exampleDialogue
        self.systemPrompt = systemPrompt
        self.postHistoryInstructions = postHistoryInstructions
        self.alternateGreetings = alternateGreetings
        self.tags = tags
        self.creator = creator
        self.sourceFormat = sourceFormat
    }

    func replacingVariables(userName: String, in text: String) -> String {
        text
            .replacingOccurrences(of: "{{char}}", with: name)
            .replacingOccurrences(of: "<char>", with: name)
            .replacingOccurrences(of: "{{user}}", with: userName)
            .replacingOccurrences(of: "<user>", with: userName)
    }

    func resolvedFirstMessage(userName: String) -> String {
        replacingVariables(userName: userName, in: firstMessage)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func combinedPrompt(userName: String) -> String {
        var sections: [String] = []
        sections.append("""
        当前启用了角色扮演模式。你必须始终扮演“\(name)”，自然地延续对话，不要把角色设定复述给用户，不要替用户决定动作、对白或心理活动。除非角色卡明确要求其他语言，否则使用简体中文。
        """)

        appendSection("角色说明", characterDescription, to: &sections)
        appendSection("性格", personality, to: &sections)
        appendSection("当前场景", scenario, to: &sections)
        appendSection("角色系统提示", systemPrompt, to: &sections)
        appendSection("示例对话", exampleDialogue, to: &sections)
        appendSection("后置指令", postHistoryInstructions, to: &sections)

        return replacingVariables(userName: userName, in: sections.joined(separator: "\n\n"))
    }

    private func appendSection(_ title: String, _ content: String, to sections: inout [String]) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sections.append("【\(title)】\n\(trimmed)")
    }
}

struct ParsedRoleplayCard {
    let character: RoleplayCharacter
    let avatarData: Data?
}

enum RoleplayCardError: LocalizedError {
    case unsupportedFile
    case fileTooLarge
    case invalidJSON
    case missingCharacterData
    case unsupportedPNGMetadata
    case storageFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "仅支持 SillyTavern JSON 或包含角色数据的 PNG 卡。"
        case .fileTooLarge:
            return "文件过大，角色卡不能超过 40 MB。"
        case .invalidJSON:
            return "JSON 内容无效，无法识别角色卡结构。"
        case .missingCharacterData:
            return "角色卡缺少名称或主要角色数据。"
        case .unsupportedPNGMetadata:
            return "这张 PNG 没有找到 chara/ccv3 角色数据。普通图片不能直接作为角色卡。"
        case .storageFailed:
            return "无法把角色卡保存到本机。"
        }
    }
}

enum RoleplayCardParser {
    private static let maximumFileSize = 40 * 1024 * 1024

    static func parse(data: Data, fileExtension: String) throws -> ParsedRoleplayCard {
        guard data.count <= maximumFileSize else { throw RoleplayCardError.fileTooLarge }
        switch fileExtension.lowercased() {
        case "json":
            return ParsedRoleplayCard(character: try parseJSON(data, sourceFormat: "SillyTavern JSON"), avatarData: nil)
        case "png":
            let jsonData = try extractCharacterJSON(fromPNG: data)
            let character = try parseJSON(jsonData, sourceFormat: "SillyTavern PNG")
            return ParsedRoleplayCard(character: character, avatarData: data)
        default:
            throw RoleplayCardError.unsupportedFile
        }
    }

    private static func parseJSON(_ data: Data, sourceFormat: String) throws -> RoleplayCharacter {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RoleplayCardError.invalidJSON
        }

        let payload = (root["data"] as? [String: Any]) ?? root
        let name = string(payload["name"]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw RoleplayCardError.missingCharacterData }

        let description = firstNonEmpty(
            string(payload["description"]),
            string(payload["char_persona"])
        )
        let personality = string(payload["personality"])
        let scenario = string(payload["scenario"])
        let firstMessage = firstNonEmpty(
            string(payload["first_mes"]),
            string(payload["first_message"]),
            string(payload["greeting"])
        )
        let examples = firstNonEmpty(
            string(payload["mes_example"]),
            string(payload["example_dialogue"])
        )
        let systemPrompt = string(payload["system_prompt"])
        let postHistory = firstNonEmpty(
            string(payload["post_history_instructions"]),
            string(payload["post_history_instruction"])
        )
        let alternates = stringArray(payload["alternate_greetings"])
        let tags = stringArray(payload["tags"])
        let creator = string(payload["creator"])

        return RoleplayCharacter(
            name: name,
            characterDescription: description,
            personality: personality,
            scenario: scenario,
            firstMessage: firstMessage,
            exampleDialogue: examples,
            systemPrompt: systemPrompt,
            postHistoryInstructions: postHistory,
            alternateGreetings: alternates,
            tags: tags,
            creator: creator,
            sourceFormat: sourceFormat
        )
    }

    private static func extractCharacterJSON(fromPNG png: Data) throws -> Data {
        let signature = Data([137, 80, 78, 71, 13, 10, 26, 10])
        guard png.count >= 8, png.prefix(8) == signature else {
            throw RoleplayCardError.unsupportedFile
        }

        var offset = 8
        while offset + 12 <= png.count {
            let length = Int(readUInt32(png, at: offset))
            let typeStart = offset + 4
            let dataStart = typeStart + 4
            let dataEnd = dataStart + length
            guard length >= 0, dataEnd + 4 <= png.count else { break }

            let typeData = png.subdata(in: typeStart..<(typeStart + 4))
            let type = String(data: typeData, encoding: .ascii) ?? ""
            let chunk = png.subdata(in: dataStart..<dataEnd)

            if type == "tEXt", let result = decodeTextChunk(chunk) {
                return result
            }
            if type == "iTXt", let result = decodeInternationalTextChunk(chunk) {
                return result
            }
            if type == "IEND" { break }
            offset = dataEnd + 4
        }

        throw RoleplayCardError.unsupportedPNGMetadata
    }

    private static func decodeTextChunk(_ chunk: Data) -> Data? {
        guard let separator = chunk.firstIndex(of: 0) else { return nil }
        let keyword = String(data: chunk[..<separator], encoding: .isoLatin1)?.lowercased() ?? ""
        guard keyword == "chara" || keyword == "ccv3" else { return nil }
        let textStart = chunk.index(after: separator)
        let textData = Data(chunk[textStart...])
        return decodeEmbeddedJSON(textData)
    }

    private static func decodeInternationalTextChunk(_ chunk: Data) -> Data? {
        guard let firstNull = chunk.firstIndex(of: 0) else { return nil }
        let keyword = String(data: chunk[..<firstNull], encoding: .utf8)?.lowercased() ?? ""
        guard keyword == "chara" || keyword == "ccv3" else { return nil }

        var cursor = chunk.index(after: firstNull)
        guard cursor + 2 <= chunk.endIndex else { return nil }
        let compressionFlag = chunk[cursor]
        cursor += 2
        guard compressionFlag == 0 else { return nil }

        guard let languageEnd = chunk[cursor...].firstIndex(of: 0) else { return nil }
        cursor = chunk.index(after: languageEnd)
        guard let translatedEnd = chunk[cursor...].firstIndex(of: 0) else { return nil }
        cursor = chunk.index(after: translatedEnd)
        guard cursor < chunk.endIndex else { return nil }
        return decodeEmbeddedJSON(Data(chunk[cursor...]))
    }

    private static func decodeEmbeddedJSON(_ textData: Data) -> Data? {
        let trimmed = String(data: textData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.first == "{" {
            return trimmed.data(using: .utf8)
        }
        return Data(base64Encoded: trimmed, options: [.ignoreUnknownCharacters])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func string(_ value: Any?) -> String {
        value as? String ?? ""
    }

    private static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] { return strings }
        if let values = value as? [Any] { return values.compactMap { $0 as? String } }
        return []
    }

    private static func firstNonEmpty(_ values: String...) -> String {
        values.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }
}

enum RoleplayCharacterManager {
    private static var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("RoleplayCharacters", isDirectory: true)
    }

    private static var charactersURL: URL {
        storageDirectory.appendingPathComponent("characters.json")
    }

    static func loadCharacters() -> [RoleplayCharacter] {
        guard let data = try? Data(contentsOf: charactersURL),
              let characters = try? JSONDecoder().decode([RoleplayCharacter].self, from: data) else {
            return []
        }
        return characters
    }

    static func saveCharacters(_ characters: [RoleplayCharacter]) throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(characters)
        try data.write(to: charactersURL, options: .atomic)
    }

    static func upsert(_ character: RoleplayCharacter, avatarData: Data? = nil) throws {
        var characters = loadCharacters()
        if let index = characters.firstIndex(where: { $0.id == character.id }) {
            characters[index] = character
        } else {
            characters.append(character)
        }
        try saveCharacters(characters)
        if let avatarData {
            try saveAvatarData(avatarData, for: character.id)
        }
    }

    static func delete(_ character: RoleplayCharacter) throws {
        var characters = loadCharacters()
        characters.removeAll { $0.id == character.id }
        try saveCharacters(characters)
        try? FileManager.default.removeItem(at: avatarURL(for: character.id))

        let defaults = UserDefaults.standard
        if defaults.string(forKey: RoleplaySettingsKey.activeCharacterID) == character.id.uuidString {
            defaults.removeObject(forKey: RoleplaySettingsKey.activeCharacterID)
            defaults.set(false, forKey: RoleplaySettingsKey.enabled)
        }
    }

    static func activeCharacter() -> RoleplayCharacter? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: RoleplaySettingsKey.enabled),
              let idString = defaults.string(forKey: RoleplaySettingsKey.activeCharacterID),
              let id = UUID(uuidString: idString) else { return nil }
        return loadCharacters().first { $0.id == id }
    }

    static func activePrompt(userName: String) -> String? {
        activeCharacter()?.combinedPrompt(userName: userName)
    }

    static func avatar(for character: RoleplayCharacter) -> UIImage? {
        UIImage(contentsOfFile: avatarURL(for: character.id).path)
    }

    static func saveAvatar(_ image: UIImage, for characterID: UUID) throws {
        let maxDimension: CGFloat = 1000
        let maxSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / maxSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = resized.jpegData(compressionQuality: 0.86) else {
            throw RoleplayCardError.storageFailed
        }
        try saveAvatarData(data, for: characterID)
    }

    private static func saveAvatarData(_ data: Data, for characterID: UUID) throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.88) else {
            throw RoleplayCardError.storageFailed
        }
        try jpeg.write(to: avatarURL(for: characterID), options: .atomic)
    }

    private static func avatarURL(for characterID: UUID) -> URL {
        storageDirectory.appendingPathComponent("\(characterID.uuidString).jpg")
    }
}
