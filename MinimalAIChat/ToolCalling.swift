import Foundation

// MARK: - Tool Calling Models

/// Represents a tool we declare to the model, telling it what it can do.
struct ToolDefinition: Encodable {
    let type: String // always "function"
    let function: FunctionDefinition

    struct FunctionDefinition: Encodable {
        let name: String
        let description: String
        let parameters: ParametersDefinition
    }

    struct ParametersDefinition: Encodable {
        let type: String // always "object"
        let properties: [String: PropertyDefinition]
        let required: [String]

        struct PropertyDefinition: Encodable {
            let type: String
            let description: String
        }
    }
}

extension ToolDefinition {
    static let webSearch = ToolDefinition(
        type: "function",
        function: FunctionDefinition(
            name: "web_search",
            description: "Search the web for current, real-time, or recent information — news, events, releases, or anything that may have happened after your training data cutoff. Only use this when the user's question requires up-to-date information; do not use it for general knowledge, creative writing, or questions you can already answer confidently.",
            parameters: ParametersDefinition(
                type: "object",
                properties: [
                    "query": ParametersDefinition.PropertyDefinition(
                        type: "string",
                        description: "The search query to look up"
                    )
                ],
                required: ["query"]
            )
        )
    )
}

/// Represents a tool call that the model wants to execute, as returned in the API response.
struct ToolCall: Codable {
    var index: Int?
    var id: String?
    var type: String? // "function"
    var function: FunctionCall
    var extraContent: ExtraContent?
    
    enum CodingKeys: String, CodingKey {
        case index, id, type, function
        case extraContent = "extra_content"
    }
    
    struct ExtraContent: Codable {
        let google: GoogleExtra?
        struct GoogleExtra: Codable {
            let thoughtSignature: String?
            enum CodingKeys: String, CodingKey {
                case thoughtSignature = "thought_signature"
            }
        }
    }

    struct FunctionCall: Codable {
        var name: String?
        var arguments: String? // Raw JSON string fragment
    }
}
