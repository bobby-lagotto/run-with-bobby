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
    private static let selectedModelIdKey = "ai_selected_model_id"
    private static let downloadedModelIdsKey = "ai_downloaded_model_ids"
    private static let openAIModelKey = "ai_openai_model"
    private static let anthropicModelKey = "ai_anthropic_model"
    private static let apiKeyKeychainKey = "openai_api_key"
    private static let anthropicApiKeyKeychainKey = "anthropic_api_key"

    // Legacy keys for one-time migration
    private static let legacyLocalModelKey = "ai_local_model"
    private static let legacyModelDownloadedKey = "ai_model_downloaded"
    private static let legacyDownloadedModelIdKey = "ai_downloaded_model_id"

    @Published var providerType: LLMProviderType {
        didSet { UserDefaults.standard.set(providerType.rawValue, forKey: Self.providerKey) }
    }

    @Published var selectedModelId: String {
        didSet { UserDefaults.standard.set(selectedModelId, forKey: Self.selectedModelIdKey) }
    }

    @Published var downloadedModelIds: Set<String> {
        didSet {
            let array = Array(downloadedModelIds)
            if let data = try? JSONEncoder().encode(array) {
                UserDefaults.standard.set(data, forKey: Self.downloadedModelIdsKey)
            }
        }
    }

    @Published var openAIModel: String {
        didSet { UserDefaults.standard.set(openAIModel, forKey: Self.openAIModelKey) }
    }

    @Published var anthropicModel: String {
        didSet { UserDefaults.standard.set(anthropicModel, forKey: Self.anthropicModelKey) }
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

    var selectedModel: LocalModelOption? { LocalModelCatalog.find(selectedModelId) }
    var isSelectedModelDownloaded: Bool { downloadedModelIds.contains(selectedModelId) }
    var isLocalAvailable: Bool {
        isSelectedModelDownloaded && (selectedModel?.isSupportedOnThisDevice ?? false)
    }

    func markDownloaded(_ id: String) {
        downloadedModelIds.insert(id)
    }

    func markDeleted(_ id: String) {
        downloadedModelIds.remove(id)
    }

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

        self.selectedModelId = UserDefaults.standard.string(forKey: Self.selectedModelIdKey)
            ?? LocalModelCatalog.defaultId

        self.openAIModel = UserDefaults.standard.string(forKey: Self.openAIModelKey)
            ?? "gpt-4o-mini"

        self.anthropicModel = UserDefaults.standard.string(forKey: Self.anthropicModelKey)
            ?? "claude-sonnet-4-20250514"

        // Decode downloaded model IDs from JSON-encoded array
        if let data = UserDefaults.standard.data(forKey: Self.downloadedModelIdsKey),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            self.downloadedModelIds = Set(ids)
        } else {
            self.downloadedModelIds = []
        }

        // One-time migration from legacy state (single isModelDownloaded:Bool + localModelName:String)
        if downloadedModelIds.isEmpty,
           UserDefaults.standard.bool(forKey: Self.legacyModelDownloadedKey),
           let legacyName = UserDefaults.standard.string(forKey: Self.legacyLocalModelKey) {
            let legacyId = legacyName.contains("/") ? legacyName : "mlx-community/\(legacyName)"
            downloadedModelIds.insert(legacyId)
            UserDefaults.standard.removeObject(forKey: Self.legacyModelDownloadedKey)
            UserDefaults.standard.removeObject(forKey: Self.legacyLocalModelKey)
            UserDefaults.standard.removeObject(forKey: Self.legacyDownloadedModelIdKey)
        }
    }
}
