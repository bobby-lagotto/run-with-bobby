import Foundation

class OpenAICompatibleProvider: LLMService {
    let apiKey: String
    let model: String
    let baseURL: String
    let displayName: String
    let additionalHeaders: [String: String]

    var isAvailable: Bool { !apiKey.isEmpty }
    var providerName: String { "\(displayName) (\(model))" }

    init(
        apiKey: String,
        model: String,
        baseURL: String,
        displayName: String,
        additionalHeaders: [String: String] = [:]
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.displayName = displayName
        self.additionalHeaders = additionalHeaders
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

        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        return parseResponse(chatResponse)
    }

    // MARK: - Request Building

    private func buildRequest(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) throws -> URLRequest {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        for (header, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: header)
        }
        request.timeoutInterval = 60

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { msg -> [String: Any] in
                var dict: [String: Any] = ["role": msg.role.rawValue]

                // Tool role messages need tool_call_id and content
                if msg.role == .tool {
                    dict["content"] = msg.content
                    if let toolCallId = msg.toolCallId {
                        dict["tool_call_id"] = toolCallId
                    }
                }
                // Assistant messages with tool_calls
                else if msg.role == .assistant, let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                    // Content can be null when assistant only calls tools
                    if msg.content.isEmpty {
                        dict["content"] = NSNull()
                    } else {
                        dict["content"] = msg.content
                    }
                    dict["tool_calls"] = toolCalls.map { tc -> [String: Any] in
                        let argsString: String
                        if let data = try? JSONEncoder().encode(tc.arguments),
                           let str = String(data: data, encoding: .utf8) {
                            argsString = str
                        } else {
                            argsString = "{}"
                        }
                        return [
                            "id": tc.id,
                            "type": "function",
                            "function": [
                                "name": tc.name,
                                "arguments": argsString
                            ]
                        ]
                    }
                }
                // Normal messages (system, user, assistant without tools)
                else {
                    dict["content"] = msg.content
                }

                return dict
            },
            "temperature": 0.7,
            "max_tokens": 2000
        ]

        // Add tools if provided
        if let tools = toolDefinitions, !tools.isEmpty {
            body["tools"] = tools.map { tool -> [String: Any] in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": buildParametersDict(tool.parameters)
                    ]
                ]
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildParametersDict(_ params: ToolParametersSchema) -> [String: Any] {
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

    // MARK: - Streaming

    func generateStream(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { [self] continuation in
            Task {
                do {
                    guard !apiKey.isEmpty else { throw LLMError.apiKeyMissing }

                    var request = try self.buildRequest(messages: messages, toolDefinitions: toolDefinitions)
                    if let body = request.httpBody,
                       var json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                        json["stream"] = true
                        request.httpBody = try JSONSerialization.data(withJSONObject: json)
                    }

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.invalidResponse
                    }
                    guard httpResponse.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line }
                        throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(errorBody)")
                    }

                    var accumulatedText = ""
                    var toolCallsById: [Int: (id: String, name: String, args: String)] = [:]

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard jsonStr != "[DONE]" else { break }

                        guard let data = jsonStr.data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = event["choices"] as? [[String: Any]],
                              let choice = choices.first,
                              let delta = choice["delta"] as? [String: Any] else { continue }

                        if let content = delta["content"] as? String {
                            accumulatedText += content
                            continuation.yield(.textDelta(content))
                        }

                        if let tcs = delta["tool_calls"] as? [[String: Any]] {
                            for tc in tcs {
                                let index = tc["index"] as? Int ?? 0
                                if let id = tc["id"] as? String {
                                    let fname = (tc["function"] as? [String: Any])?["name"] as? String ?? ""
                                    toolCallsById[index] = (id: id, name: fname, args: "")
                                }
                                if let fn = tc["function"] as? [String: Any],
                                   let args = fn["arguments"] as? String {
                                    var existing = toolCallsById[index] ?? (id: "", name: "", args: "")
                                    existing.args += args
                                    toolCallsById[index] = existing
                                }
                            }
                        }
                    }

                    var toolCalls: [ToolCall] = []
                    for (_, tc) in toolCallsById.sorted(by: { $0.key < $1.key }) {
                        if let argsDict = self.parseArguments(tc.args) {
                            toolCalls.append(ToolCall(id: tc.id, name: tc.name, arguments: argsDict))
                        }
                    }

                    let finalResponse = LLMResponse(text: accumulatedText, toolCalls: toolCalls)
                    continuation.yield(.done(finalResponse))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: OpenAIChatResponse) -> LLMResponse {
        guard let choice = response.choices.first else {
            return LLMResponse(text: "", toolCalls: [])
        }

        let text = choice.message.content ?? ""

        var toolCalls: [ToolCall] = []
        if let apiToolCalls = choice.message.tool_calls {
            for tc in apiToolCalls {
                if let args = parseArguments(tc.function.arguments) {
                    toolCalls.append(ToolCall(
                        id: tc.id,
                        name: tc.function.name,
                        arguments: args
                    ))
                }
            }
        }

        return LLMResponse(text: text, toolCalls: toolCalls)
    }

    private func parseArguments(_ jsonString: String) -> [String: JSONValue]? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            return nil
        }
        return dict
    }
}

class OpenAIProvider: OpenAICompatibleProvider {
    init(apiKey: String, model: String = "gpt-4o-mini") {
        super.init(
            apiKey: apiKey,
            model: model,
            baseURL: "https://api.openai.com/v1/chat/completions",
            displayName: "OpenAI"
        )
    }
}

class OpenRouterProvider: OpenAICompatibleProvider {
    init(apiKey: String, model: String = "openai/gpt-4o-mini") {
        super.init(
            apiKey: apiKey,
            model: model,
            baseURL: "https://openrouter.ai/api/v1/chat/completions",
            displayName: "OpenRouter"
        )
    }

    func validateKey() async throws {
        guard !apiKey.isEmpty else { throw LLMError.apiKeyMissing }
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/key")!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError("HTTP \(httpResponse.statusCode): \(body)")
        }
    }
}

// MARK: - OpenAI API Response Types

struct OpenAIChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
        let finish_reason: String?
    }

    struct Message: Decodable {
        let role: String
        let content: String?
        let tool_calls: [APIToolCall]?
    }

    struct APIToolCall: Decodable {
        let id: String
        let type: String
        let function: FunctionCall
    }

    struct FunctionCall: Decodable {
        let name: String
        let arguments: String
    }
}
