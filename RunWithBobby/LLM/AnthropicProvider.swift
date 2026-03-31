import Foundation

class AnthropicProvider: LLMService {

    private let apiKey: String
    private let model: String
    private let baseURL = "https://api.anthropic.com/v1/messages"

    var isAvailable: Bool { !apiKey.isEmpty }
    var providerName: String { "Anthropic (\(model))" }

    init(apiKey: String, model: String = "claude-sonnet-4-20250514") {
        self.apiKey = apiKey
        self.model = model
    }

    func generate(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) async throws -> LLMResponse {
        guard !apiKey.isEmpty else { throw LLMError.apiKeyMissing }

        let request = try buildRequest(messages: messages, toolDefinitions: toolDefinitions)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(body)")
        }

        let anthropicResponse = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
        return parseResponse(anthropicResponse)
    }

    // MARK: - Request Building

    private func buildRequest(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) throws -> URLRequest {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 60

        // Separate system prompt from conversation messages
        var systemPrompt: String? = nil
        var conversationMessages: [[String: Any]] = []

        for msg in messages {
            switch msg.role {
            case .system:
                // Anthropic uses a top-level system field
                if systemPrompt == nil {
                    systemPrompt = msg.content
                } else {
                    systemPrompt! += "\n\n" + msg.content
                }

            case .user:
                conversationMessages.append([
                    "role": "user",
                    "content": msg.content
                ])

            case .assistant:
                if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                    // Assistant message with tool use — build content blocks
                    var contentBlocks: [[String: Any]] = []
                    if !msg.content.isEmpty {
                        contentBlocks.append(["type": "text", "text": msg.content])
                    }
                    for tc in toolCalls {
                        let inputDict: [String: Any]
                        if let data = try? JSONEncoder().encode(tc.arguments),
                           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            inputDict = parsed
                        } else {
                            inputDict = [:]
                        }
                        contentBlocks.append([
                            "type": "tool_use",
                            "id": tc.id,
                            "name": tc.name,
                            "input": inputDict
                        ])
                    }
                    conversationMessages.append([
                        "role": "assistant",
                        "content": contentBlocks
                    ])
                } else {
                    conversationMessages.append([
                        "role": "assistant",
                        "content": msg.content
                    ])
                }

            case .tool:
                // Anthropic expects tool results as user messages with tool_result content blocks
                let toolResultBlock: [String: Any] = [
                    "type": "tool_result",
                    "tool_use_id": msg.toolCallId ?? "",
                    "content": msg.content
                ]
                // If the last message is already a user message with tool_result blocks, merge
                if let lastIdx = conversationMessages.indices.last,
                   conversationMessages[lastIdx]["role"] as? String == "user",
                   var existingContent = conversationMessages[lastIdx]["content"] as? [[String: Any]],
                   existingContent.first?["type"] as? String == "tool_result" {
                    existingContent.append(toolResultBlock)
                    conversationMessages[lastIdx]["content"] = existingContent
                } else {
                    conversationMessages.append([
                        "role": "user",
                        "content": [toolResultBlock]
                    ])
                }
            }
        }

        // Ensure messages alternate user/assistant (Anthropic requirement)
        // The first message must be from user
        var body: [String: Any] = [
            "model": model,
            "messages": conversationMessages,
            "max_tokens": 2000,
            "temperature": 0.7
        ]

        if let system = systemPrompt {
            body["system"] = system
        }

        // Add tools if provided
        if let tools = toolDefinitions, !tools.isEmpty {
            body["tools"] = tools.map { tool -> [String: Any] in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": buildInputSchema(tool.parameters)
                ]
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildInputSchema(_ params: ToolParametersSchema) -> [String: Any] {
        var dict: [String: Any] = [
            "type": params.type,
            "required": params.required
        ]

        var props: [String: Any] = [:]
        for (key, prop) in params.properties {
            var propDict: [String: Any] = [
                "type": prop.type,
                "description": prop.description
            ]
            if let enums = prop.enumValues {
                propDict["enum"] = enums
            }
            props[key] = propDict
        }
        dict["properties"] = props

        return dict
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: AnthropicMessageResponse) -> LLMResponse {
        var text = ""
        var toolCalls: [ToolCall] = []

        for block in response.content {
            switch block {
            case .text(let textBlock):
                text += textBlock.text
            case .toolUse(let toolUseBlock):
                let arguments = convertInputToJSONValues(toolUseBlock.input)
                toolCalls.append(ToolCall(
                    id: toolUseBlock.id,
                    name: toolUseBlock.name,
                    arguments: arguments
                ))
            }
        }

        return LLMResponse(text: text, toolCalls: toolCalls)
    }

    private func convertInputToJSONValues(_ input: [String: AnthropicJSONValue]) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for (key, value) in input {
            result[key] = value.toLLMJSONValue()
        }
        return result
    }
}

// MARK: - Anthropic API Response Types

struct AnthropicMessageResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContentBlock]
    let stop_reason: String?

    struct TextBlock: Decodable {
        let text: String
    }

    struct ToolUseBlock: Decodable {
        let id: String
        let name: String
        let input: [String: AnthropicJSONValue]
    }
}

enum AnthropicContentBlock: Decodable {
    case text(AnthropicMessageResponse.TextBlock)
    case toolUse(AnthropicMessageResponse.ToolUseBlock)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let block = try AnthropicMessageResponse.TextBlock(from: decoder)
            self = .text(block)
        case "tool_use":
            let block = try AnthropicMessageResponse.ToolUseBlock(from: decoder)
            self = .toolUse(block)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }
}

// MARK: - Anthropic JSON Value (for tool input parsing)

enum AnthropicJSONValue: Decodable {
    case string(String)
    case number(Double)
    case int(Int)
    case bool(Bool)
    case object([String: AnthropicJSONValue])
    case array([AnthropicJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .number(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let o = try? container.decode([String: AnthropicJSONValue].self) {
            self = .object(o)
        } else if let a = try? container.decode([AnthropicJSONValue].self) {
            self = .array(a)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func toLLMJSONValue() -> JSONValue {
        switch self {
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .int(let i): return .int(i)
        case .bool(let b): return .bool(b)
        case .null: return .null
        case .object(let o):
            var result: [String: JSONValue] = [:]
            for (k, v) in o { result[k] = v.toLLMJSONValue() }
            return .object(result)
        case .array(let a):
            return .array(a.map { $0.toLLMJSONValue() })
        }
    }
}
