import Foundation

public struct SimilaritySettings: Codable, Equatable {
    public var keywordWeight = 0.6
    public var phraseWeight = 0.3
    public var coverageWeight = 0.1
    public var minimumScore = 0.4
    public var minimumSharedTerms = 2
    public var excludePlaceNames = true
    public var excludeWordingConflicts = true
    public var showWeakMatches = false
    public var ignoredTerms = ""
    public init() {}
    public var normalized: Self {
        var value = self
        func bounded(_ number: Double, fallback: Double) -> Double { number.isFinite ? max(0, min(1, number)) : fallback }
        value.keywordWeight = bounded(keywordWeight, fallback: 0.6)
        value.phraseWeight = bounded(phraseWeight, fallback: 0.3)
        value.coverageWeight = bounded(coverageWeight, fallback: 0.1)
        value.minimumScore = bounded(minimumScore, fallback: 0.4)
        value.minimumSharedTerms = max(1, min(5, minimumSharedTerms))
        value.ignoredTerms = String(ignoredTerms.prefix(1000))
        return value
    }
    public var summary: String {
        let s = normalized, total = s.keywordWeight + s.phraseWeight + s.coverageWeight
        let weights = total > 0 ? String(format: "K %.0f%% / P %.0f%% / C %.0f%%", s.keywordWeight / total * 100, s.phraseWeight / total * 100, s.coverageWeight / total * 100) : "All weights zero"
        return "\(weights); minimum \(Int((s.minimumScore * 100).rounded()))/100; \(s.minimumSharedTerms) shared terms; exclude places: \(s.excludePlaceNames); exclude wording conflicts: \(s.excludeWordingConflicts)"
    }
}

public struct HeadlineVector: Equatable {
    public let keyword: Double?
    public let phrase: Double?
    public let coverage: Double?
    public let score: Double?
    public let sharedTerms: [String]
    public let sharedPhrases: [String]
    public let seedOnly: [String]
    public let candidateOnly: [String]
    public let ignored: [String]
    public let reasons: [String]
    public let wordingConflict: Bool
    public let eligible: Bool
    public var rankScore: Double? { eligible ? score : nil }
    public var summary: String {
        func display(_ value: Double?) -> String { value.map { String(format: "%.0f", $0 * 100) } ?? "unknown" }
        return "K=\(display(keyword)), P=\(display(phrase)), C=\(display(coverage)); index=\(display(score)); \(eligible ? "passes filters" : reasons.joined(separator: "; "))"
    }
}

/// Precision-oriented lexical comparison. It is not an embedding or an event-linkage model.
public enum HeadlineSimilarity {
    private static let generic: Set<String> = ["a", "an", "the", "in", "on", "at", "and", "or", "to", "of", "for", "from", "with", "by", "is", "are", "was", "were", "as", "it", "its", "this", "that", "after", "before", "over", "new", "news", "says", "say", "said", "about", "has", "have", "had", "be", "been", "will", "would", "can", "could", "their", "they", "them", "he", "she", "his", "her", "report", "reports", "reported", "reporting", "update", "updates", "latest", "live", "breaking", "watch", "video", "videos", "photo", "photos", "today", "yesterday", "tomorrow", "local", "official", "officials", "according"]
    private static let negative: Set<String> = ["not", "no", "never", "without", "deny", "denies", "denied", "false", "hoax", "debunk", "debunked"]
    private struct Features {
        var tokens: Set<String>
        var phrases: Set<String>
        var ignored: Set<String>
        var negated: Bool
    }
    private static func features(_ title: String, places: [String], settings: SimilaritySettings) -> Features {
        let raw = TextSimilarity.words(title)
        var removed = Set<Int>()
        if settings.excludePlaceNames {
            for place in places {
                let words = TextSimilarity.words(place)
                guard !words.isEmpty, words.count <= raw.count else { continue }
                for start in 0...(raw.count - words.count) where Array(raw[start..<(start + words.count)]) == words {
                    removed.formUnion(start..<(start + words.count))
                }
            }
        }
        let custom = Set(TextSimilarity.words(settings.ignoredTerms))
        let content: [String?] = raw.enumerated().map { index, word in
            removed.contains(index) || generic.contains(word) || negative.contains(word) || custom.contains(word) || word.count < 2 || word.allSatisfy(\.isNumber) ? nil : word
        }
        var phrases = Set<String>()
        // Keep actual adjacency. Removing "not" or a place must not invent a phrase.
        if content.count > 1 {
            for index in 0..<(content.count - 1) {
                if let a = content[index], let b = content[index + 1] { phrases.insert(a + " " + b) }
            }
        }
        return Features(tokens: Set(content.compactMap { $0 }), phrases: phrases,
                        ignored: Set(raw.enumerated().compactMap { content[$0.offset] == nil ? $0.element : nil }),
                        negated: raw.contains { negative.contains($0) })
    }
    public static func compare(seed: String, candidate: String, places: [String] = [], settings: SimilaritySettings = SimilaritySettings(), shortQuery: Bool = false) -> HeadlineVector {
        let settings = settings.normalized
        let a = features(seed, places: places, settings: settings), b = features(candidate, places: places, settings: settings)
        let shared = a.tokens.intersection(b.tokens), commonPhrases = a.phrases.intersection(b.phrases)
        let hasContent = !a.tokens.isEmpty && !b.tokens.isEmpty
        let keyword = hasContent ? Double(shared.count) / Double(a.tokens.union(b.tokens).count) : nil
        // Unknown if neither text has an eligible phrase; zero if only one does.
        let phrase = a.phrases.isEmpty && b.phrases.isEmpty ? nil : Double(commonPhrases.count) / Double(a.phrases.union(b.phrases).count)
        let coverage = hasContent ? Double(shared.count) / Double(a.tokens.count) : nil
        let dimensions: [(Double?, Double)] = [(keyword, settings.keywordWeight), (phrase, settings.phraseWeight), (coverage, settings.coverageWeight)]
        let total = dimensions.reduce(0.0) { $0 + ($1.0 == nil ? 0 : $1.1) }
        let score = hasContent && total > 0 ? dimensions.reduce(0.0) { $0 + ($1.0 ?? 0) * $1.1 } / total : nil
        let conflict = a.negated != b.negated
        let required = shortQuery && !a.tokens.isEmpty ? min(settings.minimumSharedTerms, a.tokens.count) : settings.minimumSharedTerms
        var reasons: [String] = []
        if !hasContent { reasons.append("No meaningful content after exclusions") }
        if total == 0 { reasons.append("No weighted dimensions available") }
        if hasContent && shared.count < required { reasons.append("Only \(shared.count) shared terms; \(required) required") }
        if settings.excludeWordingConflicts && conflict { reasons.append("Negation/denial wording differs; review the claim") }
        if let score, score < settings.minimumScore { reasons.append("Below \(Int((settings.minimumScore * 100).rounded()))/100 threshold") }
        return HeadlineVector(keyword: keyword, phrase: phrase, coverage: coverage, score: score,
                              sharedTerms: shared.sorted(), sharedPhrases: commonPhrases.sorted(),
                              seedOnly: a.tokens.subtracting(b.tokens).sorted(), candidateOnly: b.tokens.subtracting(a.tokens).sorted(),
                              ignored: a.ignored.union(b.ignored).sorted(), reasons: reasons, wordingConflict: conflict,
                              eligible: reasons.isEmpty && score != nil)
    }
}
