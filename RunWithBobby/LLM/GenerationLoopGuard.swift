import Foundation

struct CoachFactBag: Equatable {
    var kilometers: Set<Double> = []
    var heartRates: Set<Int> = []
    var hrvMs: Set<Int> = []

    static let empty = CoachFactBag()

    func allowingProfile(_ profile: RunnerProfile) -> CoachFactBag {
        var copy = self
        copy.kilometers.insert(((profile.weeklyKilometers * 10).rounded()) / 10)
        return copy
    }

    func allowsKilometer(_ value: Double) -> Bool {
        kilometers.contains { abs($0 - value) < 0.15 }
    }
}

enum GenerationLoopGuard {
    static let minNGramLength = 12
    static let maxNGramLength = 120
    static let repeatThreshold = 4
    static let phraseWindow = 24
    static let phraseRepeatThreshold = 4
    static let sentenceRepeatThreshold = 3

    static func isRepeating(_ text: String) -> Bool {
        hasConsecutiveNGrams(text) || hasRepeatedSentence(text) || hasRepeatedPhrase(text)
    }

    static func looksLikeLeakedToolJSON(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("<tool_call>") { return true }
        if lower.contains("new_piano") { return true }
        if lower.contains("\"function\"") && (lower.contains("\"args\"") || lower.contains("\"arguments\"")) {
            return true
        }
        if lower.contains("\"name\"") && lower.contains("\"arguments\"") && lower.contains("{") {
            return true
        }
        return false
    }

    static func looksLikeEnglishSchemaDump(_ text: String) -> Bool {
        let lower = text.lowercased()
        let markers = [
            "name keyword",
            "the function name",
            "type of the argument"
        ]
        return markers.contains { lower.contains($0) }
    }

    /// Qwen 2.5 often answers health/coaching questions with a canned legal-privacy refusal
    /// when the system prompt is truncated or ignored.
    static func looksLikeLegalPrivacyRefusal(_ text: String) -> Bool {
        let lower = text.lowercased()
        let markers = [
            "diritto alla privacy",
            "libertà di informazioni",
            "liberta di informazioni",
            "regole legali",
            "normative che governano",
            "non posso fornire un'opzione specifica",
            "non posso fornire un’opzione specifica",
            "questione relativa alle regole legali",
            "consultare una fonte affidabile",
            "privacy rights",
            "freedom of information",
            "i cannot provide a specific option"
        ]
        return markers.contains { lower.contains($0) }
    }

    static func looksLikeOffRole(_ text: String) -> Bool {
        let lower = text.lowercased()
        let markers = [
            "as an ai",
            "sono un modello",
            "non sono un coach",
            "consultare un avvocato",
            "i am an ai"
        ]
        return markers.contains { lower.contains($0) }
    }

    static func containsUnverifiedNumericClaims(_ text: String, allowed: CoachFactBag) -> Bool {
        if extractedKilometers(from: text).contains(where: { !allowed.allowsKilometer($0) }) {
            return true
        }
        if extractedInts(from: text, pattern: #"(\d+)\s*bpm"#).contains(where: { !allowed.heartRates.contains($0) }) {
            return true
        }
        let hrvPattern = #"hrv[^\d]{0,16}(\d+)"#
        if extractedInts(from: text, pattern: hrvPattern).contains(where: { !allowed.hrvMs.contains($0) }) {
            return true
        }
        return false
    }

    /// Hide mid-stream so the chat stays on "Sta pensando..." instead of dumping loops.
    static func shouldHideFromStream(_ text: String) -> Bool {
        looksLikeLeakedToolJSON(text)
            || looksLikeEnglishSchemaDump(text)
            || looksLikeLegalPrivacyRefusal(text)
            || looksLikeOffRole(text)
            || isRepeating(text)
    }

    /// Empty, repeating, leaked tool JSON, or English schema dumps should not be shown as a coach reply.
    static func shouldDiscardAsModelOutput(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return shouldHideFromStream(trimmed)
    }

    static func shouldDiscardAsModelOutput(_ text: String, allowedFacts: CoachFactBag) -> Bool {
        if shouldDiscardAsModelOutput(text) { return true }
        return containsUnverifiedNumericClaims(text, allowed: allowedFacts)
    }

    private static func extractedKilometers(from text: String) -> [Double] {
        let regex = try? NSRegularExpression(pattern: #"(\d+(?:[.,]\d+)?)\s*km"#, options: .caseInsensitive)
        let ns = text as NSString
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? []
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let raw = ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ".")
            return Double(raw)
        }
    }

    private static func extractedInts(from text: String, pattern: String) -> [Int] {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let ns = text as NSString
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? []
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return Int(ns.substring(with: match.range(at: 1)))
        }
    }

    private static func hasConsecutiveNGrams(_ text: String) -> Bool {
        let chars = Array(text)
        let maxNGram = min(maxNGramLength, chars.count / repeatThreshold)
        guard maxNGram >= minNGramLength else { return false }

        for ngram in minNGramLength...maxNGram {
            if hasConsecutiveRepeats(chars, ngramLength: ngram, times: repeatThreshold) {
                return true
            }
        }
        return false
    }

    private static func hasRepeatedSentence(_ text: String) -> Bool {
        let separators = CharacterSet(charactersIn: ".!?")
        var counts: [String: Int] = [:]
        for raw in text.components(separatedBy: separators) {
            let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard sentence.count >= 20 else { continue }
            counts[sentence, default: 0] += 1
            if counts[sentence]! >= sentenceRepeatThreshold {
                return true
            }
        }
        return false
    }

    private static func hasRepeatedPhrase(_ text: String) -> Bool {
        let chars = Array(text)
        guard chars.count >= phraseWindow * phraseRepeatThreshold else { return false }

        var counts: [String: Int] = [:]
        var index = 0
        while index + phraseWindow <= chars.count {
            let key = String(chars[index..<(index + phraseWindow)])
            if !key.allSatisfy(\.isWhitespace) {
                counts[key, default: 0] += 1
                if counts[key]! >= phraseRepeatThreshold {
                    return true
                }
            }
            index += 8
        }
        return false
    }

    private static func hasConsecutiveRepeats(_ chars: [Character], ngramLength: Int, times: Int) -> Bool {
        guard chars.count >= ngramLength * times else { return false }
        let start = chars.count - (ngramLength * times)
        let first = chars[start..<(start + ngramLength)]
        guard !first.allSatisfy(\.isWhitespace) else { return false }

        for index in 1..<times {
            let sliceStart = start + (index * ngramLength)
            let slice = chars[sliceStart..<(sliceStart + ngramLength)]
            if slice != first {
                return false
            }
        }
        return true
    }
}
