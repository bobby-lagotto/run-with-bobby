import Foundation

/// MLX Local Model Provider
///
/// This provider uses mlx-swift-examples LLM library for on-device inference.
/// To enable local models, add to Package.swift:
///   .package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main")
/// and uncomment the MLX imports and implementation below.
///
/// Supported models (from mlx-community on HuggingFace):
/// - mlx-community/Phi-3.5-mini-instruct-4bit (~2GB)
/// - mlx-community/Llama-3.2-1B-Instruct-4bit (~700MB)
/// - mlx-community/Llama-3.2-3B-Instruct-4bit (~1.8GB)

// TODO: Uncomment when mlx-swift-examples is added as dependency
// import LLM
// import MLX

class MLXProvider: LLMService {

    var isAvailable: Bool { isModelLoaded }
    var providerName: String { "Locale (\(modelName))" }

    private let modelName: String
    private var isModelLoaded = false

    // TODO: Replace with actual MLX ModelContainer
    // private var modelContainer: ModelContainer?

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false

    init(modelName: String = "Phi-3.5-mini-instruct-4bit") {
        self.modelName = modelName
        checkModelAvailability()
    }

    func generate(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) async throws -> LLMResponse {
        guard isModelLoaded else { throw LLMError.modelNotLoaded }

        // TODO: Implement actual MLX inference
        // let prompt = formatMessages(messages, toolDefinitions: toolDefinitions)
        // let output = try await modelContainer?.generate(prompt: prompt, parameters: .init(temperature: 0.7))
        // return parseMLXOutput(output)

        throw LLMError.modelNotLoaded
    }

    // MARK: - Model Management

    func downloadModel() async throws {
        isDownloading = true
        downloadProgress = 0

        // TODO: Implement model download from HuggingFace Hub
        // let config = ModelConfiguration.huggingFace("mlx-community/\(modelName)")
        // modelContainer = try await ModelContainer.load(configuration: config) { progress in
        //     Task { @MainActor in
        //         self.downloadProgress = progress.fractionCompleted
        //     }
        // }

        isDownloading = false
        isModelLoaded = true
    }

    func unloadModel() {
        // Free memory
        // modelContainer = nil
        isModelLoaded = false
    }

    private func checkModelAvailability() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelDir = documentsPath.appendingPathComponent("Models/\(modelName)")
        isModelLoaded = FileManager.default.fileExists(atPath: modelDir.path)
    }

    // MARK: - Message Formatting for Local Models

    private func formatMessages(_ messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) -> String {
        // Format as chat template for the model
        // Most instruction-tuned models use a specific chat format
        var prompt = ""

        for message in messages {
            switch message.role {
            case .system:
                prompt += "<|system|>\n\(message.content)\n"
                // Append tool descriptions for local models
                if let tools = toolDefinitions, !tools.isEmpty {
                    prompt += "\nPer chiamare uno strumento, usa questo formato:\n<tool_call>{\"name\": \"nome_tool\", \"arguments\": {...}}</tool_call>\n"
                }
            case .user:
                prompt += "<|user|>\n\(message.content)\n"
            case .assistant:
                prompt += "<|assistant|>\n\(message.content)\n"
            case .tool:
                prompt += "<|tool|>\n\(message.content)\n"
            }
        }

        prompt += "<|assistant|>\n"
        return prompt
    }

    /// Parse tool calls from local model text output
    private func parseToolCalls(from text: String) -> [ToolCall] {
        var toolCalls: [ToolCall] = []

        // Look for <tool_call>...</tool_call> blocks
        let pattern = #"<tool_call>\s*(\{[^}]+\})\s*</tool_call>"#
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
