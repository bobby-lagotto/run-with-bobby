import Foundation
import Hub
import MLXLLM
import MLXLMCommon
import MLX
import Tokenizers

@MainActor
class MLXProvider: @MainActor LLMService, ObservableObject {

    nonisolated static let defaultModelId = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"

    var isAvailable: Bool { modelContainer != nil }
    var providerName: String { "Locale (\(displayName))" }

    @Published private(set) var modelId: String
    private var displayName: String
    private var modelContainer: ModelContainer?

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false

    init(modelId: String = MLXProvider.defaultModelId) {
        self.modelId = modelId
        self.displayName = modelId.components(separatedBy: "/").last ?? modelId
    }

    /// Switch the active model. Unloads the current container so the next
    /// generate() / loadIfAvailable() loads the new model.
    func setModel(_ newId: String) {
        guard newId != modelId else { return }
        unloadModel()
        modelId = newId
        displayName = newId.components(separatedBy: "/").last ?? newId
    }

    /// Delete the on-disk files for a given model id (HuggingFace cache).
    /// Safe to call on a model that isn't cached — it just no-ops.
    func deleteModelFiles(_ id: String) {
        let repo = Hub.Repo(id: id, type: .models)
        let cacheDir = HubApi.shared.localRepoLocation(repo)
        try? FileManager.default.removeItem(at: cacheDir)
        if id == modelId {
            unloadModel()
        }
    }

    // MARK: - Generation

    func generate(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) async throws -> LLMResponse {
        try await generate(messages: messages, toolDefinitions: toolDefinitions, retried: false)
    }

    private func generate(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?, retried: Bool) async throws -> LLMResponse {
        guard let container = modelContainer else { throw LLMError.modelNotLoaded }

        let userInput = Self.makeUserInput(messages: messages, toolDefinitions: toolDefinitions)
        let params = generateParameters

        let result: (text: String, calls: [MLXLMCommon.ToolCall]) = try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            var text = ""
            var calls: [MLXLMCommon.ToolCall] = []
            for await event in try MLXLMCommon.generate(input: lmInput, parameters: params, context: context) {
                switch event {
                case .chunk(let s):
                    text += s
                    if GenerationLoopGuard.shouldHideFromStream(text) { break }
                case .toolCall(let tc): calls.append(tc)
                case .info: break
                }
                if GenerationLoopGuard.shouldHideFromStream(text) { break }
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

        return Self.sanitizedResponse(text: trimmed, calls: result.calls)
    }

    func generateStream(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard let container = self.modelContainer else {
                    continuation.finish(throwing: LLMError.modelNotLoaded)
                    return
                }
                let userInput = Self.makeUserInput(messages: messages, toolDefinitions: toolDefinitions)
                let params = self.generateParameters

                do {
                    try await container.perform { context in
                        let lmInput = try await context.processor.prepare(input: userInput)
                        var text = ""
                        var calls: [MLXLMCommon.ToolCall] = []
                        for await event in try MLXLMCommon.generate(input: lmInput, parameters: params, context: context) {
                            switch event {
                            case .chunk(let s):
                                text += s
                                if !GenerationLoopGuard.shouldHideFromStream(s)
                                    && !GenerationLoopGuard.shouldHideFromStream(text) {
                                    continuation.yield(.textDelta(s))
                                }
                                if GenerationLoopGuard.shouldHideFromStream(text) { break }
                            case .toolCall(let tc):
                                calls.append(tc)
                            case .info:
                                break
                            }
                            if GenerationLoopGuard.shouldHideFromStream(text) { break }
                        }
                        let response = Self.sanitizedResponse(text: text, calls: calls)
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

    /// Keep KV small on-device. 27B also uses 4-bit KV to stay inside the iOS per-app budget.
    /// Small Qwen models get a tighter token cap; all local models use a repetition penalty
    /// so structured JSON loops cannot run until the KV window fills.
    private var generateParameters: GenerateParameters {
        let maxTokens = modelId.contains("0.5B") ? 384 : 768
        if modelId.contains("Bonsai-27B") {
            return GenerateParameters(
                maxTokens: maxTokens,
                maxKVSize: 2048,
                kvBits: 4,
                temperature: 0.3,
                repetitionPenalty: 1.15,
                repetitionContextSize: 64
            )
        }
        return GenerateParameters(
            maxTokens: maxTokens,
            maxKVSize: 2048,
            temperature: 0.3,
            repetitionPenalty: 1.15,
            repetitionContextSize: 64
        )
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

    private nonisolated static func sanitizedResponse(text: String, calls: [MLXLMCommon.ToolCall]) -> LLMResponse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if calls.isEmpty && GenerationLoopGuard.shouldDiscardAsModelOutput(trimmed) {
            return LLMResponse(text: "", toolCalls: [])
        }
        return LLMResponse(text: trimmed, toolCalls: calls.map(convert))
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
