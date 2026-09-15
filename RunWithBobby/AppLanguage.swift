import Foundation

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case italian
    case english

    var id: String { rawValue }

    static let storageKey = "app_language_preference"

    var title: String {
        switch self {
        case .system: return L10n.tr("Sistema (iPhone)", english: "System (iPhone)")
        case .italian: return "Italiano"
        case .english: return "English"
        }
    }

    var subtitle: String {
        switch self {
        case .system:
            return L10n.tr("Segue la lingua del dispositivo", english: "Follows the device language")
        case .italian:
            return L10n.tr("Sempre italiano", english: "Always Italian")
        case .english:
            return L10n.tr("Sempre inglese", english: "Always English")
        }
    }
}

enum AppLanguage {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cachedCode = resolveCode(storedPreference())

    static var code: String {
        lock.lock()
        defer { lock.unlock() }
        return cachedCode
    }

    static var isEnglish: Bool { code == "en" }

    static var locale: Locale {
        Locale(identifier: isEnglish ? "en_US" : "it_IT")
    }

    static func storedPreference() -> AppLanguagePreference {
        if let raw = UserDefaults.standard.string(forKey: AppLanguagePreference.storageKey),
           let preference = AppLanguagePreference(rawValue: raw) {
            return preference
        }
        return .system
    }

    static func sync(from preference: AppLanguagePreference) {
        let resolved = resolveCode(preference)
        lock.lock()
        cachedCode = resolved
        lock.unlock()
    }

    static func resolveCode(_ preference: AppLanguagePreference) -> String {
        switch preference {
        case .italian:
            return "it"
        case .english:
            return "en"
        case .system:
            for identifier in Locale.preferredLanguages {
                if identifier.hasPrefix("it") { return "it" }
                if identifier.hasPrefix("en") { return "en" }
            }
            if Locale.current.language.languageCode?.identifier.hasPrefix("it") == true {
                return "it"
            }
            return "en"
        }
    }
}

enum L10n {
    static func tr(_ italian: String, english: String) -> String {
        AppLanguage.isEnglish ? english : italian
    }

    static func format(_ italian: String, english: String, _ arguments: CVarArg...) -> String {
        String(format: tr(italian, english: english), locale: AppLanguage.locale, arguments: arguments)
    }
}
