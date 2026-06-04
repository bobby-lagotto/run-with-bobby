import Foundation

// MARK: - Message Types

struct LLMMessage {
    enum Role: String, Codable {
        case system
        case user
        case assistant
        case tool
    }

    let role: Role
    let content: String
    var toolCallId: String?
    var toolCalls: [ToolCall]?  // For assistant messages that invoke tools
}

// MARK: - Tool Call Types

struct ToolCall: Codable {
    let id: String
    let name: String
    let arguments: [String: JSONValue]

    init(id: String = UUID().uuidString, name: String, arguments: [String: JSONValue]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

struct ToolResult {
    let toolCallId: String
    let name: String
    let content: String
}

// MARK: - JSON Value (lightweight any-type for tool arguments)

enum JSONValue: Codable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case int(Int)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .number(let n): return Int(n)
        default: return nil
        }
    }

    var description: String {
        switch self {
        case .string(let s): return "\"\(s)\""
        case .number(let n): return "\(n)"
        case .int(let i): return "\(i)"
        case .bool(let b): return "\(b)"
        case .object(let o): return "\(o)"
        case .array(let a): return "\(a)"
        case .null: return "null"
        }
    }

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
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .int(let i): try container.encode(i)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - LLM Response

struct LLMResponse {
    let text: String
    let toolCalls: [ToolCall]
}

// MARK: - Streaming

enum StreamEvent {
    case textDelta(String)
    case done(LLMResponse)
}

// MARK: - LLM Service Protocol

protocol LLMService {
    var isAvailable: Bool { get }
    var providerName: String { get }
    func generate(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) async throws -> LLMResponse
    func generateStream(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) -> AsyncThrowingStream<StreamEvent, Error>
}

extension LLMService {
    func generateStream(messages: [LLMMessage], toolDefinitions: [ToolDefinitionSchema]?) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await self.generate(messages: messages, toolDefinitions: toolDefinitions)
                    if !response.text.isEmpty {
                        continuation.yield(.textDelta(response.text))
                    }
                    continuation.yield(.done(response))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Tool Definition Schema (for OpenAI function calling format)

struct ToolDefinitionSchema: Codable {
    let name: String
    let description: String
    let parameters: ToolParametersSchema
}

struct ToolParametersSchema: Codable {
    let type: String
    let properties: [String: ToolPropertySchema]
    let required: [String]
}

struct ToolPropertySchema: Codable {
    let type: String
    let description: String
    var enumValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
    }
}

// MARK: - LLM Errors

enum LLMError: LocalizedError {
    case noProviderAvailable
    case apiKeyMissing
    case apiError(String)
    case modelNotLoaded
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            return "Nessun provider AI disponibile. Configura un modello locale o inserisci una API key (OpenAI, Anthropic o OpenRouter) nelle impostazioni."
        case .apiKeyMissing:
            return "API key mancante. Inseriscila nelle impostazioni."
        case .apiError(let msg):
            return "Errore API: \(msg)"
        case .modelNotLoaded:
            return "Modello locale non caricato. Scaricalo dalle impostazioni."
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .invalidResponse:
            return "Risposta non valida dal modello."
        }
    }
}
