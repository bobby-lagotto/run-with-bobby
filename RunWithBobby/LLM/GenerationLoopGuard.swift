import Foundation

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

    /// Hide mid-stream so the chat stays on "Sta pensando..." instead of dumping loops.
    static func shouldHideFromStream(_ text: String) -> Bool {
        looksLikeLeakedToolJSON(text) || looksLikeEnglishSchemaDump(text) || isRepeating(text)
    }

    /// Empty, repeating, leaked tool JSON, or English schema dumps should not be shown as a coach reply.
    static func shouldDiscardAsModelOutput(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return shouldHideFromStream(trimmed)
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
