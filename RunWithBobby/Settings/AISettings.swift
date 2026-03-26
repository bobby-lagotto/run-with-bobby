import Foundation
import SwiftUI

enum LLMProviderType: String, Codable, CaseIterable {
    case local = "Locale"
    case openai = "OpenAI"
    case auto = "Automatico"

    var icon: String {
        switch self {
        case .local: return "iphone"
        case .openai: return "cloud"
        case .auto: return "arrow.triangle.2.circlepath"
        }
    }
}

class AISettings: ObservableObject {
    private static let providerKey = "ai_provider_type"
    private static let localModelKey = "ai_local_model"
    private static let openAIModelKey = "ai_openai_model"
    private static let apiKeyKeychainKey = "openai_api_key"

    @Published var providerType: LLMProviderType {
        didSet { UserDefaults.standard.set(providerType.rawValue, forKey: Self.providerKey) }
    }

    @Published var localModelName: String {
        didSet { UserDefaults.standard.set(localModelName, forKey: Self.localModelKey) }
    }

    @Published var openAIModel: String {
        didSet { UserDefaults.standard.set(openAIModel, forKey: Self.openAIModelKey) }
    }

    @Published var isModelDownloaded = false
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false

    var openAIAPIKey: String? {
        get {
            // In debug, check .env first via process environment
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

    var hasAPIKey: Bool {
        guard let key = openAIAPIKey else { return false }
        return !key.isEmpty
    }

    var isOpenAIAvailable: Bool { hasAPIKey }
    var isLocalAvailable: Bool { isModelDownloaded }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.providerKey),
           let type = LLMProviderType(rawValue: raw) {
            self.providerType = type
        } else {
            self.providerType = .auto
        }

        self.localModelName = UserDefaults.standard.string(forKey: Self.localModelKey)
            ?? "Phi-3.5-mini-instruct-4bit"

        self.openAIModel = UserDefaults.standard.string(forKey: Self.openAIModelKey)
            ?? "gpt-4o-mini"
    }
}
