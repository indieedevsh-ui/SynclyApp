//
//  SmartAssistantStandardIntel.swift
//  BeSorted
//
//  Silnik Smart Assistant (iPhone 14 · 6 GB): Foundation Models niedostępne na tym sprzęcie.
//  Najlepszy wariant = ultra-mocna heurystyka + NaturalLanguage (rzeczowniki / frazy),
//  bez „słabego AI” generatywnego i bez udawania hybryda FM.
//

import Foundation
import NaturalLanguage

enum SmartAssistantStandardIntel {
    /// Lematyzowane tokeny (głównie rzeczowniki), bez zaimków / spójników.
    static func keyLemmas(from text: String, limit: Int = 16) -> [String] {
        actionableThemes(from: text, limit: limit, allowSingleToken: true)
    }

    /// Tematy nadające się do nazw zadań: preferuj 2-wyrazowe frazy rzeczownikowe, potem mocne rzeczowniki.
    /// Odfiltrowuje śmieci typu „której”, „jako”, „grywaly”.
    static func actionableThemes(
        from text: String,
        limit: Int = 6,
        allowSingleToken: Bool = true
    ) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return [] }

        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = trimmed
        if let lang = NLLanguageRecognizer.dominantLanguage(for: trimmed) {
            tagger.setLanguage(lang, range: trimmed.startIndex..<trimmed.endIndex)
        }

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        var tokens: [(raw: String, lemma: String, isNoun: Bool)] = []

        tagger.enumerateTags(
            in: trimmed.startIndex..<trimmed.endIndex,
            unit: .word,
            scheme: .lemma,
            options: options
        ) { tag, range in
            let raw = String(trimmed[range])
            let lemma = normalize(tag?.rawValue ?? raw)
            guard lemma.count >= 4, !stopwords.contains(lemma), !lemma.allSatisfy(\.isNumber) else {
                return true
            }

            let classTag = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0
            let isNoun = classTag == .noun
                || classTag == .personalName
                || classTag == .placeName
                || classTag == .organizationName
            // Zaimki / przyimki / spójniki / partykuły — zawsze odrzuć.
            if classTag == .pronoun
                || classTag == .determiner
                || classTag == .preposition
                || classTag == .conjunction
                || classTag == .particle
                || classTag == .classifier
            {
                return true
            }
            // Bez klasy: trzymaj tylko wyglądające na treść (nie końcówki fleksyjne zaimków).
            if classTag == nil || classTag == .otherWord {
                guard isLikelyContentToken(lemma) else { return true }
            } else if classTag == .verb || classTag == .adverb || classTag == .adjective {
                // Czasowniki/przysłówki/przymiotniki solo rzadko dają sensowną nazwę zadania.
                guard isNoun else { return true }
            }

            tokens.append((raw: raw, lemma: lemma, isNoun: isNoun || isLikelyContentToken(lemma)))
            return true
        }

        var seen = Set<String>()
        var themes: [String] = []

        // 1) Bigramy rzeczownikowe → „walka wręcz”, nie pojedyncze „której”.
        if tokens.count >= 2 {
            for i in 0..<(tokens.count - 1) {
                let a = tokens[i]
                let b = tokens[i + 1]
                guard a.isNoun || b.isNoun else { continue }
                guard isLikelyContentToken(a.lemma), isLikelyContentToken(b.lemma) else { continue }
                let phrase = normalizeDisplay("\(a.raw) \(b.raw)")
                let key = normalize(phrase)
                guard key.count >= 7, seen.insert(key).inserted else { continue }
                themes.append(phrase)
                if themes.count >= limit { return themes }
            }
        }

        guard allowSingleToken else { return themes }

        // 2) Mocne pojedyncze rzeczowniki (≥5 znaków).
        for token in tokens where token.isNoun || isLikelyContentToken(token.lemma) {
            guard token.lemma.count >= 5 else { continue }
            guard isLikelyContentToken(token.lemma) else { continue }
            let display = normalizeDisplay(token.raw)
            let key = normalize(display)
            guard seen.insert(key).inserted else { continue }
            themes.append(display)
            if themes.count >= limit { break }
        }

        if themes.isEmpty {
            return trimmed
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 5 && isLikelyContentToken($0) }
                .prefix(limit)
                .map { normalizeDisplay($0) }
        }
        return themes
    }

    /// Nakładanie tematów opisu na nazwę/opis zadania — im wyżej, tym bliżej sensu projektu.
    static func topicalOverlapScore(projectText: String, candidate: String) -> Int {
        let themes = Set(keyLemmas(from: projectText, limit: 20).map(normalize))
        guard !themes.isEmpty else { return 0 }
        let hay = Set(keyLemmas(from: candidate, limit: 24).map(normalize))
        return themes.intersection(hay).count
    }

    /// Waga zadania do planu: gwiazdki + świeżość + dopasowanie tematyczne do projektu.
    static func planTaskScore(task: ProjectTask, project: Project) -> Double {
        let topical = Double(
            topicalOverlapScore(
                projectText: project.details
                    + " " + project.gameMechanics
                    + " " + project.gameGameloop
                    + " " + project.storyTheme
                    + " " + project.storyTypicalAction
                    + " " + project.storyHeroGoal
                    + " " + project.storyFinale
                    + " " + project.drawingMainMotif
                    + " " + project.drawingGoalEmotion
                    + " " + project.drawingCompletionDefinition
                    + " " + project.appKeyFeatures
                    + " " + project.appUserPath
                    + " " + project.appMainProblem
                    + " " + project.schoolProjectGoal
                    + " " + project.schoolMainContent
                    + " " + project.schoolSubject
                    + " " + project.schoolCompletionCriteria,
                candidate: task.name + " " + task.details
            )
        )
        let stars = Double(task.importance)
        let ageDays = max(0, Date().timeIntervalSince(task.updatedAt) / 86_400)
        let freshness = max(0, 1.35 - min(ageDays, 40) / 40)
        let inPlanPenalty = task.isInCurrentPlan ? -2.0 : 0
        return stars * 1.15 + topical * 0.85 + freshness + inPlanPenalty
    }

    /// Czy token nadaje się do wstawienia w nazwę zadania (nie zaimek / śmieć fleksyjny).
    static func isLikelyContentToken(_ lemma: String) -> Bool {
        let t = normalize(lemma)
        guard t.count >= 4 else { return false }
        if stopwords.contains(t) { return false }
        if weakThemeTokens.contains(t) { return false }
        // Odrzuć typowe końcówki zaimków względnych PL bez pełnej formy w stopwords.
        if t.hasPrefix("ktor") || t.hasPrefix("któ") { return false }
        if t.hasPrefix("jak") && t.count <= 5 { return false }
        return true
    }

    /// Czysta normalizacja tekstu — bez stanu i bez I/O, więc `nonisolated`.
    /// Bez tego `Set.map(normalize)` przekazuje main-actor-isolowaną funkcję do
    /// nieizolowanego closure (błąd w Swift 6).
    nonisolated static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func normalizeDisplay(_ text: String) -> String {
        let parts = text
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return text }
        let head = first.prefix(1).uppercased() + first.dropFirst().lowercased()
        let tail = parts.dropFirst().map { $0.lowercased() }
        return ([head] + tail).joined(separator: " ")
    }

    private static let weakThemeTokens: Set<String> = [
        "ktorej", "ktorym", "ktorych", "ktorzy", "ktorymi", "ktora", "ktory", "ktore",
        "tej", "tym", "tych", "tego", "tymi", "tamtej", "tamtych",
        "swoj", "swoja", "swoje", "swoich", "swoim",
        "moze", "musi", "beda", "bedzie", "bylo", "była", "byly",
        "sobie", "siebie", "niego", "niej", "nich", "nimi",
        "grywaly", "grywalny", "grywalne", "playable", "beat", "slice",
        "projekt", "project", "opis", "description", "zadanie", "task",
        "rzecz", "thing", "stuff", "other", "inne", "czesc", "część"
    ]

    private static let stopwords: Set<String> = [
        "this", "that", "with", "from", "have", "will", "project", "about", "which",
        "their", "there", "would", "could", "should", "into", "your", "than", "then",
        "projekt", "ktory", "ktora", "ktore", "ktorej", "ktorym", "ktorych",
        "oraz", "jest", "bedzie", "moze", "bardzo", "mozna", "przez", "jako",
        "tego", "tych", "tylko", "takze", "beda", "byc", "sie", "nie", "tak",
        "juz", "przy", "nad", "pod", "bez", "the", "and", "for", "are", "was",
        "were", "been", "being", "also", "when", "where", "what", "while",
        "after", "before", "between", "under", "over", "more", "most", "some",
        "such", "than", "then", "them", "they", "this", "those", "these",
        "aby", "albo", "jednak", "wiec", "więc", "poniewaz", "ponieważ",
        "gdzie", "kiedy", "jezeli", "jeżeli", "jesli", "jeśli", "zeby", "żeby",
        "nawet", "jeszcze", "bardziej", "mniej", "kazdy", "każdy", "kazda", "każda"
    ]
}
