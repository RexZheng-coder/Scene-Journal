import Foundation
import NaturalLanguage

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SmartHighlightInput {
    var type: EntryType
    var title: String
    var venue: String
    var people: String
    var detailA: String
    var detailB: String
    var notes: String
    var existingTags: [String]

    var combinedText: String {
        [
            type.displayName,
            title,
            venue,
            people,
            detailA,
            detailB,
            notes,
            existingTags.joined(separator: " ")
        ]
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SmartHighlights {
    enum Source {
        case appleIntelligence
        case localFallback
    }

    var summary: String
    var keywords: [String]
    var source: Source
}

extension SmartHighlights.Source {
    var displayName: String {
        switch self {
        case .appleIntelligence: return "Apple Intelligence"
        case .localFallback: return "On-device NLP fallback"
        }
    }
}

actor SmartHighlightsService {
    static let shared = SmartHighlightsService()

    private init() {}

    func generate(from input: SmartHighlightInput) async -> SmartHighlights {
        let text = input.combinedText

#if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let generated = try? await generateUsingAppleIntelligence(text: text) {
            return generated
        }
#endif

        return generateLocalFallback(text: text, input: input)
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateUsingAppleIntelligence(text: String) async throws -> SmartHighlights {
        guard SystemLanguageModel.default.isAvailable else {
            throw NSError(domain: "SmartHighlights", code: 1)
        }

        let session = LanguageModelSession(
            instructions: """
            You extract concise highlights from live event notes.
            Return exactly two lines in English:
            SUMMARY: <1 sentence, max 22 words>
            KEYWORDS: <comma-separated keywords, exactly 3 important nouns/proper nouns>
            """
        )

        let response = try await session.respond(to: text)
        let parsed = parseModelResponse(response.content)

        if parsed.keywords.isEmpty {
            throw NSError(domain: "SmartHighlights", code: 2)
        }

        return SmartHighlights(summary: parsed.summary, keywords: parsed.keywords, source: .appleIntelligence)
    }
#endif

    private func generateLocalFallback(text: String, input: SmartHighlightInput) -> SmartHighlights {
        let summary = fallbackSummary(from: text, title: input.title, venue: input.venue, type: input.type)
        let keywords = fallbackKeywords(from: text, existingTags: input.existingTags)
        return SmartHighlights(summary: summary, keywords: keywords, source: .localFallback)
    }

    private func parseModelResponse(_ content: String) -> (summary: String, keywords: [String]) {
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var summary = ""
        var keywordLine = ""

        for line in lines {
            if line.uppercased().hasPrefix("SUMMARY:") {
                summary = String(line.dropFirst("SUMMARY:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.uppercased().hasPrefix("KEYWORDS:") {
                keywordLine = String(line.dropFirst("KEYWORDS:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let keywords = keywordLine
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return (summary: summary, keywords: sanitizeKeywords(keywords))
    }

    private func fallbackSummary(from text: String, title: String, venue: String, type: EntryType) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            let firstSentence = trimmed
                .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !firstSentence.isEmpty {
                return String(firstSentence.prefix(120))
            }
        }

        if !title.isEmpty && !venue.isEmpty {
            return "A memorable \(type.displayName.lowercased()) moment at \(venue): \(title)."
        }
        if !title.isEmpty {
            return "A memorable \(type.displayName.lowercased()) moment: \(title)."
        }
        return "A memorable live moment worth keeping."
    }

    private func fallbackKeywords(from text: String, existingTags: [String]) -> [String] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return sanitizeKeywords(existingTags)
        }

        var counts: [String: Int] = [:]
        let stopWords: Set<String> = [
            "the", "a", "an", "and", "or", "to", "of", "in", "on", "for", "with", "at", "from",
            "is", "are", "was", "were", "it", "this", "that", "my", "our", "their", "your",
            "i", "we", "you", "he", "she", "they", "me", "us", "them", "his", "her", "its",
            "very", "really", "just", "also", "there", "here", "then", "than", "into", "over",
            "show", "event", "moment", "live"
        ]

        let lexicalTagger = NLTagger(tagSchemes: [.lexicalClass])
        lexicalTagger.string = normalized
        lexicalTagger.enumerateTags(
            in: normalized.startIndex..<normalized.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, tokenRange in
            guard let tag, tag == .noun else { return true }
            let token = String(normalized[tokenRange]).lowercased()
            if token.count < 4 || stopWords.contains(token) { return true }
            counts[token, default: 0] += 1
            return true
        }

        let entityTagger = NLTagger(tagSchemes: [.nameType])
        entityTagger.string = normalized
        entityTagger.enumerateTags(
            in: normalized.startIndex..<normalized.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, tokenRange in
            guard tag != nil else { return true }
            let token = String(normalized[tokenRange])
            if token.count < 4 || stopWords.contains(token.lowercased()) { return true }
            counts[token, default: 0] += 2
            return true
        }

        for tag in existingTags where !tag.isEmpty {
            let lowered = tag.lowercased()
            if lowered.count >= 4 && !stopWords.contains(lowered) {
                counts[lowered, default: 0] += 3
            }
        }

        let ranked = counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .map(\.key)
        return sanitizeKeywords(ranked)
    }

    private func sanitizeKeywords(_ keywords: [String]) -> [String] {
        let stopWords: Set<String> = [
            "the", "a", "an", "and", "or", "to", "of", "in", "on", "for", "with", "at", "from",
            "is", "are", "was", "were", "it", "this", "that", "my", "our", "their", "your",
            "i", "we", "you", "he", "she", "they", "me", "us", "them", "his", "her", "its",
            "very", "really", "just", "also", "there", "here", "then", "than", "into", "over"
        ]

        var unique: [String] = []
        var seen = Set<String>()

        for keyword in keywords {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = trimmed.lowercased()
            if lowered.count < 4 || stopWords.contains(lowered) { continue }
            if seen.insert(lowered).inserted {
                unique.append(trimmed.capitalized)
            }
            if unique.count == 3 { break }
        }

        return unique
    }
}
