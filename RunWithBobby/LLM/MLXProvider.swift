import Foundation
import MLXLLM
import MLXLMCommon
import MLX
import Tokenizers

@MainActor
class MLXProvider: LLMService, ObservableObject {

    nonisolated static let defaultModelId = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"

    var isAvailable: Bool { modelContainer != nil }
    var providerName: String { "Locale (\(displayName))" }

    private let modelId: String
    private let displayName: String
    private var modelContainer: ModelContainer?

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false

    init(modelId: String = MLXProvider.defaultModelId) {
        self.modelId = modelId
        self.displayName = modelId.components(separatedBy: "/").last ?? modelId
    }

    nonisolated static func isDeviceSupported() -> Bool {
        ProcessInfo.processInfo.physicalMemory >= 5_500_000_000
    }

    // MARK: - Generation

    func generate(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) async throws -> LLMResponse {
        try await generate(messages: messages, toolDefinitions: toolDefinitions, retried: false)
    }

    private func generate(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?, retried: Bool) async throws -> LLMResponse {
        guard let container = modelContainer else { throw LLMError.modelNotLoaded }

        let userInput = Self.makeUserInput(messages: messages, toolDefinitions: toolDefinitions)
        let params = GenerateParameters(maxKVSize: 2048, temperature: 0.3)

        let result: (text: String, calls: [MLXLMCommon.ToolCall]) = try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            var text = ""
            var calls: [MLXLMCommon.ToolCall] = []
            for await event in try MLXLMCommon.generate(input: lmInput, parameters: params, context: context) {
                switch event {
                case .chunk(let s): text += s
                case .toolCall(let tc): calls.append(tc)
                case .info: break
                }
            }
            return (text, calls)
        }

        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Retry once if model emitted <tool_call> markers but parser couldn't extract structured calls (malformed JSON).
        if result.calls.isEmpty, trimmed.contains("<tool_call>"), !retried {
            var retryMessages = messages
            retryMessages.append(LLMMessage(role: .system, content: "Il tuo ultimo tool_call non era JSON valido. Riprova SOLO con un blocco <tool_call>{...}</tool_call> sintatticamente corretto."))
            return try await generate(messages: retryMessages, toolDefinitions: toolDefinitions, retried: true)
        }

        return LLMResponse(
            text: trimmed,
            toolCalls: result.calls.map(Self.convert)
        )
    }

    func generateStream(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard let container = self.modelContainer else {
                    continuation.finish(throwing: LLMError.modelNotLoaded)
                    return
                }
                let userInput = Self.makeUserInput(messages: messages, toolDefinitions: toolDefinitions)
                let params = GenerateParameters(maxKVSize: 2048, temperature: 0.3)

                do {
                    try await container.perform { context in
                        let lmInput = try await context.processor.prepare(input: userInput)
                        var text = ""
                        var calls: [MLXLMCommon.ToolCall] = []
                        for await event in try MLXLMCommon.generate(input: lmInput, parameters: params, context: context) {
                            switch event {
                            case .chunk(let s):
                                text += s
                                continuation.yield(.textDelta(s))
                            case .toolCall(let tc):
                                calls.append(tc)
                            case .info:
                                break
                            }
                        }
                        let response = LLMResponse(
                            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                            toolCalls: calls.map(Self.convert)
                        )
                        continuation.yield(.done(response))
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Model Management

    func downloadModel() async throws {
        isDownloading = true
        downloadProgress = 0

        do {
            let config = ModelConfiguration(id: modelId)

            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress.fractionCompleted
                }
            }

            self.modelContainer = container
            downloadProgress = 1.0
            isDownloading = false
        } catch {
            isDownloading = false
            downloadProgress = 0
            throw error
        }
    }

    /// Try to load an already-downloaded model from cache (no network needed)
    func loadIfAvailable() async {
        let config = ModelConfiguration(id: modelId)
        do {
            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { _ in }
            self.modelContainer = container
        } catch {
            // Model not cached yet — that's fine
        }
    }

    func unloadModel() {
        modelContainer = nil
    }

    // MARK: - Helpers

    private nonisolated static func makeUserInput(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) -> UserInput {
        let chatMessages: [Chat.Message] = messages.map { msg in
            switch msg.role {
            case .system:    return .system(msg.content)
            case .user:      return .user(msg.content)
            case .assistant: return .assistant(msg.content)
            case .tool:      return .tool(msg.content)
            }
        }
        let toolSpecs: [ToolSpec]? = toolDefinitions?.map { toolSpec(from: $0) }
        return UserInput(chat: chatMessages, tools: toolSpecs)
    }

    private nonisolated static func toolSpec(from def: ToolDefinitionSchema) -> ToolSpec {
        var properties: [String: Any] = [:]
        for (k, v) in def.parameters.properties {
            var p: [String: Any] = ["type": v.type, "description": v.description]
            if let e = v.enumValues { p["enum"] = e }
            properties[k] = p
        }
        let parameters: [String: Any] = [
            "type": "object",
            "properties": properties,
            "required": def.parameters.required
        ]
        let function: [String: Any] = [
            "name": def.name,
            "description": def.description,
            "parameters": parameters
        ]
        return [
            "type": "function",
            "function": function
        ]
    }

    private nonisolated static func convert(_ tc: MLXLMCommon.ToolCall) -> ToolCall {
        let args = tc.function.arguments.reduce(into: [String: JSONValue]()) { acc, kv in
            acc[kv.key] = bridge(kv.value)
        }
        return ToolCall(name: tc.function.name, arguments: args)
    }

    private nonisolated static func bridge(_ v: MLXLMCommon.JSONValue) -> JSONValue {
        switch v {
        case .null:           return .null
        case .bool(let b):    return .bool(b)
        case .int(let i):     return .int(i)
        case .double(let d):  return .number(d)
        case .string(let s):  return .string(s)
        case .array(let a):   return .array(a.map(bridge))
        case .object(let o):  return .object(o.mapValues(bridge))
        }
    }
}
