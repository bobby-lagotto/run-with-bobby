import Foundation
import SwiftUI

enum LLMProviderType: String, Codable, CaseIterable {
    case local = "Locale"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case auto = "Automatico"

    var icon: String {
        switch self {
        case .local: return "iphone"
        case .openai: return "cloud"
        case .anthropic: return "brain.head.profile"
        case .auto: return "arrow.triangle.2.circlepath"
        }
    }
}

class AISettings: ObservableObject {
    private static let providerKey = "ai_provider_type"
    private static let localModelKey = "ai_local_model"
    private static let openAIModelKey = "ai_openai_model"
    private static let anthropicModelKey = "ai_anthropic_model"
    private static let apiKeyKeychainKey = "openai_api_key"
    private static let anthropicApiKeyKeychainKey = "anthropic_api_key"
    private static let modelDownloadedKey = "ai_model_downloaded"
    private static let downloadedModelIdKey = "ai_downloaded_model_id"

    @Published var providerType: LLMProviderType {
        didSet { UserDefaults.standard.set(providerType.rawValue, forKey: Self.providerKey) }
    }

    @Published var localModelName: String {
        didSet { UserDefaults.standard.set(localModelName, forKey: Self.localModelKey) }
    }

    @Published var openAIModel: String {
        didSet { UserDefaults.standard.set(openAIModel, forKey: Self.openAIModelKey) }
    }

    @Published var anthropicModel: String {
        didSet { UserDefaults.standard.set(anthropicModel, forKey: Self.anthropicModelKey) }
    }

    @Published var isModelDownloaded: Bool {
        didSet {
            UserDefaults.standard.set(isModelDownloaded, forKey: Self.modelDownloadedKey)
            if isModelDownloaded {
                UserDefaults.standard.set(localModelName, forKey: Self.downloadedModelIdKey)
            }
        }
    }
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false

    var openAIAPIKey: String? {
        get {
            #if DEBUG
            if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            #endif
            return KeychainHelper.load(key: Self.apiKeyKeychainKey)
        }
        set {
            if let value = newValue, !value.isEmpty {
                try? KeychainHelper.save(key: Self.apiKeyKeychainKey, value: value)
            } else {
                KeychainHelper.delete(key: Self.apiKeyKeychainKey)
            }
            objectWillChange.send()
        }
    }

    var anthropicAPIKey: String? {
        get {
            #if DEBUG
            if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
                return envKey
            }
            #endif
            return KeychainHelper.load(key: Self.anthropicApiKeyKeychainKey)
        }
        set {
            if let value = newValue, !value.isEmpty {
                try? KeychainHelper.save(key: Self.anthropicApiKeyKeychainKey, value: value)
            } else {
                KeychainHelper.delete(key: Self.anthropicApiKeyKeychainKey)
            }
            objectWillChange.send()
        }
    }

    var hasOpenAIKey: Bool {
        guard let key = openAIAPIKey else { return false }
        return !key.isEmpty
    }

    var hasAnthropicKey: Bool {
        guard let key = anthropicAPIKey else { return false }
        return !key.isEmpty
    }

    // Keep backward compatibility
    var hasAPIKey: Bool { hasOpenAIKey }

    var isOpenAIAvailable: Bool { hasOpenAIKey }
    var isAnthropicAvailable: Bool { hasAnthropicKey }
    var isLocalAvailable: Bool { isModelDownloaded && isDeviceSupported }

    var isDeviceSupported: Bool { MLXProvider.isDeviceSupported() }

    /// Check if a string looks like a valid OpenAI API key
    static func looksLikeOpenAIKey(_ value: String) -> Bool {
        value.hasPrefix("sk-") && value.count > 20
    }

    /// Check if a string looks like a valid Anthropic API key
    static func looksLikeAnthropicKey(_ value: String) -> Bool {
        value.hasPrefix("sk-ant-") && value.count > 20
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.providerKey),
           let type = LLMProviderType(rawValue: raw) {
            self.providerType = type
        } else {
            self.providerType = .auto
        }

        self.localModelName = UserDefaults.standard.string(forKey: Self.localModelKey)
            ?? "Qwen2.5-1.5B-Instruct-4bit"

        self.openAIModel = UserDefaults.standard.string(forKey: Self.openAIModelKey)
            ?? "gpt-4o-mini"

        self.anthropicModel = UserDefaults.standard.string(forKey: Self.anthropicModelKey)
            ?? "claude-sonnet-4-20250514"

        // Must initialize before accessing self.localModelName
        self.isModelDownloaded = false

        // Restore download state, but reset if model name changed
        let savedModelId = UserDefaults.standard.string(forKey: Self.downloadedModelIdKey)
        if UserDefaults.standard.bool(forKey: Self.modelDownloadedKey),
           savedModelId == localModelName {
            self.isModelDownloaded = true
        }
    }
}
