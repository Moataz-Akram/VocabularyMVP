import Foundation
import Speech

/// Compares what the recognizer wrote against the target word.
///
/// The recognizer returns *orthography*, not phonemes, so a correctly-pronounced
/// word can still come back spelled differently ("flour" for "flower"). Exact
/// string matching turns those into false negatives, so matching is fuzzy on both
/// spelling and a coarse phonetic key.
enum PronunciationMatcher {
    struct Target {
        let tokens: [String]
        let joined: String
        let phonetic: String

        init(_ word: String) {
            tokens = PronunciationMatcher.tokens(word)
            joined = tokens.joined()
            phonetic = PronunciationMatcher.phoneticKey(joined)
        }
    }

    /// Similarity needed between the heard window and the target.
    static let spellingThreshold = 0.78
    static let phoneticThreshold = 0.85
    /// Fuzzy matches on near-silent audio are usually the language model guessing
    /// at the biased string rather than a real utterance.
    static let fuzzyConfidenceFloor = 0.1

    static func biasStrings(for word: String) -> [String] {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
    }

    static func meanConfidence(_ text: AttributedString) -> Double? {
        var total = 0.0
        var count = 0
        for run in text.runs {
            if let value = run.transcriptionConfidence {
                total += value
                count += 1
            }
        }
        return count > 0 ? total / Double(count) : nil
    }

    static func matches(_ target: Target, candidates: [String], confidence: Double?) -> Bool {
        guard !target.tokens.isEmpty else { return false }
        for candidate in candidates {
            switch match(target, transcript: candidate) {
            case .none:
                continue
            case .exact:
                return true
            case .fuzzy:
                if let confidence, confidence < fuzzyConfidenceFloor { continue }
                return true
            }
        }
        return false
    }

    private enum MatchKind {
        case none, fuzzy, exact
    }

    private static func match(_ target: Target, transcript: String) -> MatchKind {
        let heard = tokens(transcript)
        guard !heard.isEmpty else { return .none }

        let width = target.tokens.count
        var best = MatchKind.none

        // Widths around the target's length absorb the recognizer splitting one
        // word into two ("con flagration") or merging two into one.
        for span in max(1, width - 1)...(width + 1) where span <= heard.count {
            for start in 0...(heard.count - span) {
                let window = heard[start..<(start + span)].joined()
                if window == target.joined { return .exact }
                if isSimilar(window, target) { best = .fuzzy }
            }
        }
        return best
    }

    private static func isSimilar(_ window: String, _ target: Target) -> Bool {
        let key = phoneticKey(window)
        if key == target.phonetic { return true }
        if ratio(window, target.joined) >= spellingThreshold { return true }
        return ratio(key, target.phonetic) >= phoneticThreshold
    }

    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    /// Metaphone-lite: collapses spellings that sound alike so homophones and
    /// near-homophones compare equal.
    static func phoneticKey(_ word: String) -> String {
        guard !word.isEmpty else { return "" }
        var text = word

        for (pattern, replacement) in [
            ("sch", "sk"), ("ph", "f"), ("gh", ""), ("kn", "n"), ("wr", "r"),
            ("ck", "k"), ("tion", "shn"), ("sion", "shn"), ("qu", "kw"), ("x", "ks")
        ] {
            text = text.replacingOccurrences(of: pattern, with: replacement)
        }

        var result = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            let mapped: Character?
            switch character {
            case "c":
                mapped = (next == "e" || next == "i" || next == "y") ? "s" : "k"
            // Voiced/unvoiced pairs collapse: the distinction rarely survives a
            // recognizer's spelling choice.
            case "b", "p": mapped = "p"
            case "d", "t": mapped = "t"
            case "g", "k", "q": mapped = "k"
            case "v", "f": mapped = "f"
            case "z", "s": mapped = "s"
            case "j": mapped = "j"
            case "h", "w", "y": mapped = index == 0 ? character : nil
            case "a", "e", "i", "o", "u": mapped = index == 0 ? "a" : nil
            default: mapped = character
            }
            if let mapped, result.last != mapped {
                result.append(mapped)
            }
        }
        return result
    }

    /// Normalized Levenshtein similarity in 0...1.
    static func ratio(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 1 }
        if lhs.isEmpty || rhs.isEmpty { return 0 }

        let source = Array(lhs)
        let target = Array(rhs)
        var previous = Array(0...target.count)
        var current = [Int](repeating: 0, count: target.count + 1)

        for i in 1...source.count {
            current[0] = i
            for j in 1...target.count {
                let cost = source[i - 1] == target[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        let distance = Double(previous[target.count])
        return 1 - distance / Double(max(source.count, target.count))
    }
}
