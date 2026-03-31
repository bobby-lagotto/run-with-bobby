import Foundation
import MLXLLM
import MLXLMCommon
import MLX

@MainActor
class MLXProvider: LLMService, ObservableObject {

    var isAvailable: Bool { modelContainer != nil }
    var providerName: String { "Locale (\(displayName))" }

    private let modelId: String
    private let displayName: String
    private var modelContainer: ModelContainer?

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false

    init(modelId: String = "mlx-community/Qwen2.5-0.5B-Instruct-4bit") {
        self.modelId = modelId
        self.displayName = modelId.components(separatedBy: "/").last ?? modelId
    }

    // MARK: - Generation

    func generate(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) async throws -> LLMResponse {
        guard let container = modelContainer else { throw LLMError.modelNotLoaded }

        // Convert to chat message format for the tokenizer's chat template
        let chatMessages: [[String: String]] = messages.map { msg in
            var content = msg.content
            // Inject tool definitions into system message so the local model knows about tools
            if msg.role == .system, let tools = toolDefinitions, !tools.isEmpty {
                content += "\n\nHai a disposizione questi strumenti. Per chiamarne uno, rispondi SOLO con un blocco <tool_call>{...}</tool_call>.\n"
                for tool in tools {
                    let params = tool.parameters.properties.map { "\($0.key): \($0.value.type) — \($0.value.description)" }.joined(separator: ", ")
                    content += "- \(tool.name)(\(params)): \(tool.description)\n"
                }
            }
            return ["role": msg.role.rawValue, "content": content]
        }

        let result = try await container.perform { context in
            let input = try await context.processor.prepare(
                input: .init(messages: chatMessages)
            )
            return try MLXLMCommon.generate(
                input: input,
                parameters: GenerateParameters(temperature: 0.7),
                context: context
            ) { tokens in
                // Continue generating
                if tokens.count >= 1024 {
                    return .stop
                }
                return .more
            }
        }

        let text = result.output
        let toolCalls = parseToolCalls(from: text)

        // Remove tool call blocks from display text
        var cleanText = text
        if !toolCalls.isEmpty {
            let pattern = #"<tool_call>\s*\{[\s\S]*?\}\s*</tool_call>"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
                cleanText = regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: ""
                )
            }
        }

        return LLMResponse(
            text: cleanText.trimmingCharacters(in: .whitespacesAndNewlines),
            toolCalls: toolCalls
        )
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

    // MARK: - Tool Call Parsing

    private func parseToolCalls(from text: String) -> [ToolCall] {
        var toolCalls: [ToolCall] = []

        let pattern = #"<tool_call>\s*(\{[\s\S]*?\})\s*</tool_call>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return toolCalls
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let jsonStr = String(text[range])
                if let data = jsonStr.data(using: .utf8),
                   let json = try? JSONDecoder().decode(ToolCallJSON.self, from: data) {
                    let args = json.arguments.mapValues { JSONValue.string($0) }
                    toolCalls.append(ToolCall(name: json.name, arguments: args))
                }
            }
        }

        return toolCalls
    }

    private struct ToolCallJSON: Decodable {
        let name: String
        let arguments: [String: String]
    }
}
