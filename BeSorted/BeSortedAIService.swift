//
//  BeSortedAIService.swift
//  BeSorted
//

import Foundation
import FoundationModels
import SwiftData

@MainActor
enum BeSortedAIService {
    enum ServiceError: LocalizedError {
        case unavailable(String)
        case emptyQuestion

        var errorDescription: String? {
            switch self {
            case .unavailable(let message): message
            case .emptyQuestion: "Puste pytanie."
            }
        }
    }

    static func availabilityMessage() -> String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "To urządzenie nie obsługuje Apple Intelligence.".l10n
            case .appleIntelligenceNotEnabled:
                return "Włącz Apple Intelligence w Ustawieniach, żeby korzystać z AI.".l10n
            case .modelNotReady:
                return "Model AI jeszcze się przygotowuje. Spróbuj za chwilę.".l10n
            @unknown default:
                return "AI jest teraz niedostępne.".l10n
            }
        }
    }

    /// Aktywny Smart Assistant + uprawnienie do umiejętności.
    private static func requireSkill(_ skill: SmartAssistantSkill) throws {
        let store = SmartAssistantStore.shared
        guard store.hasActiveAssistant else {
            throw ServiceError.unavailable("Aktywuj Smart Assistant w Ustawieniach.".l10n)
        }
        guard store.supports(skill) else {
            throw ServiceError.unavailable(store.blockedMessage(for: skill))
        }
    }

    /// Foundation Models tylko dla Pro.
    private static func requireFoundationModel(for skill: SmartAssistantSkill) throws {
        try requireSkill(skill)
        guard SmartAssistantStore.shared.activeTier == .pro else { return }
        if let message = availabilityMessage() {
            throw ServiceError.unavailable(message)
        }
    }

    static func buildContextSnapshot(from modelContext: ModelContext) -> String {
        let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
        let tasks = (try? modelContext.fetch(FetchDescriptor<ProjectTask>())) ?? []
        let bugs = (try? modelContext.fetch(FetchDescriptor<ProjectBug>())) ?? []

        let activePlan = tasks.filter { $0.isInCurrentPlan && !$0.isCompleted }
        let queued = tasks.filter { $0.planQueuedAt != nil && !$0.isInCurrentPlan && !$0.isCompleted }
        let openTasks = tasks.filter { !$0.isCompleted }
        let completedTasks = tasks.filter(\.isCompleted)

        var lines: [String] = []
        lines.append("Liczba projektów: \(projects.count)")
        lines.append("Liczba wszystkich zadań: \(tasks.count)")
        lines.append("Liczba otwartych zadań: \(openTasks.count)")
        lines.append("Liczba ukończonych zadań: \(completedTasks.count)")
        lines.append("Liczba zadań w Aktualnym Planie: \(activePlan.count)")
        lines.append("Liczba zadań w kolejce do planu: \(queued.count)")
        lines.append("Liczba błędów: \(bugs.count)")

        if projects.isEmpty {
            lines.append("Brak projektów.")
        } else {
            lines.append("Projekty:")
            for project in projects.sorted(by: { $0.createdAt > $1.createdAt }) {
                let projectTasks = project.taskList
                let open = projectTasks.filter { !$0.isCompleted }
                let projectBugs = project.bugList
                lines.append(
                    "- „\(project.name)” | typ: \(project.kind.title) | gwiazdki: \(project.importance)/5 | priorytet: \(project.isPriorityHighlighted ? "tak" : "nie") | otwarte zadania: \(open.count) | błędy: \(projectBugs.count)"
                )
                if !project.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append("  opis: \(project.details)")
                }
                for task in open.sorted(by: { $0.createdAt > $1.createdAt }) {
                    var flags: [String] = []
                    if task.isInCurrentPlan { flags.append("w aktualnym planie") }
                    if task.planQueuedAt != nil { flags.append("w kolejce") }
                    let flagText = flags.isEmpty ? "" : " [\(flags.joined(separator: ", "))]"
                    lines.append(
                        "  • zadanie „\(task.name)” (\(task.kind.title), \(task.importance)/5)\(flagText)"
                    )
                }
                for bug in projectBugs.sorted(by: { $0.createdAt > $1.createdAt }) {
                    lines.append(
                        "  • błąd „\(bug.title)” (ważność \(bug.severity)/5, związane z: \(bug.relatedTaskName))"
                    )
                }
            }
        }

        if !activePlan.isEmpty {
            lines.append("Aktualny Plan:")
            for task in activePlan.sorted(by: { $0.createdAt < $1.createdAt }) {
                let projectName = task.project?.name ?? "?"
                lines.append("- „\(task.name)” z projektu „\(projectName)”")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func contextFilesSnippet(for project: Project, maxCharacters: Int = 24_000) -> String {
        let files = project.contextFileList
        guard !files.isEmpty else { return "(brak plików kontekstowych)" }

        var remaining = maxCharacters
        var chunks: [String] = []
        for file in files {
            guard remaining > 80 else {
                chunks.append("[…pominięto kolejne pliki z limitu kontekstu…]")
                break
            }
            let header = "--- plik: \(file.fileName) ---\n"
            let bodyBudget = max(0, remaining - header.count)
            let body: String
            if file.contentText.count > bodyBudget {
                body = String(file.contentText.prefix(bodyBudget)) + "\n[…przycięto…]"
            } else {
                body = file.contentText
            }
            let chunk = header + body
            chunks.append(chunk)
            remaining -= chunk.count + 2
        }
        return chunks.joined(separator: "\n\n")
    }

    /// Fragment promptu z rdzeniem gry / opowiadania. Każde uzupełnione pole trafia do AI.
    static func gameCoreSnippet(for project: Project) -> String {
        switch project.kind {
        case .game:
            return gameCoreSnippetGame(for: project)
        case .story:
            return storyCoreSnippet(for: project)
        case .drawing:
            return drawingCoreSnippet(for: project)
        case .app:
            return appCoreSnippet(for: project)
        case .school:
            return schoolCoreSnippet(for: project)
        }
    }

    private static func gameCoreSnippetGame(for project: Project) -> String {
        let mechanics = project.gameMechanics.trimmingCharacters(in: .whitespacesAndNewlines)
        let gameloop = project.gameGameloop.trimmingCharacters(in: .whitespacesAndNewlines)
        let goals = project.gamePlayerGoals.trimmingCharacters(in: .whitespacesAndNewlines)
        let win = project.gameWinConditions.trimmingCharacters(in: .whitespacesAndNewlines)
        let genres = GameGenre.allCases
            .filter { project.gameGenres.contains($0) }
            .map(\.title)
        let structure = project.gameStructure?.title

        let hasAny = !mechanics.isEmpty
            || !gameloop.isEmpty
            || !goals.isEmpty
            || !win.isEmpty
            || !genres.isEmpty
            || structure != nil

        guard hasAny else {
            return """

            Rdzeń projektowy (gra): (pusty — nieuzupełniony)
            """
        }

        func line(_ title: String, _ value: String) -> String {
            "\(title): \(value.isEmpty ? "(brak — nieuzupełnione)" : value)"
        }

        return """

        Rdzeń projektowy (gra) — źródło prawdy o założeniach gry.
        Uwzględnij KAŻDY wypełniony element poniżej, nawet jeśli pozostałe są puste
        (np. sama struktura „Otwarta” oznacza świat otwarty i ma wpływać na odpowiedź razem z innymi danymi).
        \(line("Główne mechaniki", mechanics))
        \(line("Gameloop", gameloop))
        \(line("Cele gracza", goals))
        \(line("Warunki zakończenia / wygranej", win))
        \(line("Gatunki", genres.isEmpty ? "" : genres.joined(separator: ", ")))
        \(line("Struktura", structure ?? ""))
        """
    }

    private static func storyCoreSnippet(for project: Project) -> String {
        let theme = project.storyTheme.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = project.storyTypicalAction.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = project.storyHeroGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let finale = project.storyFinale.trimmingCharacters(in: .whitespacesAndNewlines)
        let genres = StoryGenre.allCases
            .filter { project.storyGenres.contains($0) }
            .map(\.title)
        let narration = project.storyNarration?.title

        let hasAny = !theme.isEmpty
            || !action.isEmpty
            || !goal.isEmpty
            || !finale.isEmpty
            || !genres.isEmpty
            || narration != nil

        guard hasAny else {
            return """

            Rdzeń projektowy (opowiadanie): (pusty — nieuzupełniony)
            """
        }

        func line(_ title: String, _ value: String) -> String {
            "\(title): \(value.isEmpty ? "(brak — nieuzupełnione)" : value)"
        }

        return """

        Rdzeń projektowy (opowiadanie) — źródło prawdy o założeniach historii.
        Uwzględnij KAŻDY wypełniony element poniżej, nawet jeśli pozostałe są puste.
        \(line("Motyw przewodni", theme))
        \(line("Typowa akcja", action))
        \(line("Cel bohatera", goal))
        \(line("Finał", finale))
        \(line("Gatunki", genres.isEmpty ? "" : genres.joined(separator: ", ")))
        \(line("Sposób opowiadania", narration ?? ""))
        """
    }

    private static func drawingCoreSnippet(for project: Project) -> String {
        let techniques = DrawingTechnique.allCases
            .filter { project.drawingTechniques.contains($0) }
            .map(\.title)
        let motif = project.drawingMainMotif.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = project.drawingGoalEmotion.trimmingCharacters(in: .whitespacesAndNewlines)
        let completion = project.drawingCompletionDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
        let genres = DrawingGenre.allCases
            .filter { project.drawingGenres.contains($0) }
            .map(\.title)
        let scale = project.drawingScale.map { "\($0.title) — \($0.detail)" } ?? ""

        let hasAny = !techniques.isEmpty
            || !motif.isEmpty
            || !goal.isEmpty
            || !completion.isEmpty
            || !genres.isEmpty
            || project.drawingScale != nil

        guard hasAny else {
            return """

            Rdzeń projektowy (rysunek): (pusty — nieuzupełniony)
            """
        }

        func line(_ title: String, _ value: String) -> String {
            "\(title): \(value.isEmpty ? "(brak — nieuzupełnione)" : value)"
        }

        return """

        Rdzeń projektowy (rysunek) — źródło prawdy o założeniach ilustracji.
        Uwzględnij KAŻDY wypełniony element poniżej, nawet jeśli pozostałe są puste.
        \(line("Technika i narzędzia", techniques.isEmpty ? "" : techniques.joined(separator: ", ")))
        \(line("Główny motyw", motif))
        \(line("Cel i emocja", goal))
        \(line("Definicja ukończenia", completion))
        \(line("Gatunki", genres.isEmpty ? "" : genres.joined(separator: ", ")))
        \(line("Skala i przestrzeń", scale))
        """
    }

    private static func appCoreSnippet(for project: Project) -> String {
        let features = project.appKeyFeatures.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = project.appUserPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let problem = project.appMainProblem.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = project.appCategory?.title

        let hasAny = !features.isEmpty
            || !path.isEmpty
            || !problem.isEmpty
            || category != nil

        guard hasAny else {
            return """

            Rdzeń projektowy (aplikacja): (pusty — nieuzupełniony)
            """
        }

        func line(_ title: String, _ value: String) -> String {
            "\(title): \(value.isEmpty ? "(brak — nieuzupełnione)" : value)"
        }

        return """

        Rdzeń projektowy (aplikacja) — źródło prawdy o założeniach produktu.
        Uwzględnij KAŻDY wypełniony element poniżej, nawet jeśli pozostałe są puste.
        \(line("Kluczowe funkcjonalności", features))
        \(line("Ścieżka użytkownika", path))
        \(line("Główny problem", problem))
        \(line("Kategoria aplikacji", category ?? ""))
        """
    }

    private static func schoolCoreSnippet(for project: Project) -> String {
        let form = project.schoolForm?.title
        let goal = project.schoolProjectGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = project.schoolMainContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = project.schoolSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let implementation = project.schoolImplementation?.title
        let criteria = project.schoolCompletionCriteria.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasAny = form != nil
            || !goal.isEmpty
            || !content.isEmpty
            || !subject.isEmpty
            || implementation != nil
            || !criteria.isEmpty

        guard hasAny else {
            return """

            Rdzeń projektowy (szkoła): (pusty — nieuzupełniony)
            """
        }

        func line(_ title: String, _ value: String) -> String {
            "\(title): \(value.isEmpty ? "(brak — nieuzupełnione)" : value)"
        }

        return """

        Rdzeń projektowy (szkoła) — źródło prawdy o założeniach pracy szkolnej.
        Uwzględnij KAŻDY wypełniony element poniżej, nawet jeśli pozostałe są puste.
        \(line("Forma projektu", form ?? ""))
        \(line("Cel projektu", goal))
        \(line("Główna zawartość", content))
        \(line("Przedmiot szkolny", subject))
        \(line("Sposób realizacji", implementation ?? ""))
        \(line("Kryterium końcowe", criteria))
        """
    }

    private static let gameCoreUsageHint = """
    Jeśli w danych jest „Rdzeń projektowy”, traktuj każdy wypełniony element jako obowiązujący kontekst
    (dla gry: mechaniki, gameloop, cele, warunki wygranej, gatunki, strukturę;
    dla opowiadania: motyw przewodni, typową akcję, cel bohatera, finał, gatunki, sposób opowiadania;
    dla rysunku: technikę/narzędzia, główny motyw, cel i emocję, definicję ukończenia, gatunki, skalę i przestrzeń;
    dla aplikacji: kluczowe funkcjonalności, ścieżkę użytkownika, główny problem, kategorię aplikacji;
    dla szkoły: formę projektu, cel, główną zawartość, przedmiot, sposób realizacji, kryterium końcowe).
    Nawet pojedyncza informacja musi być uwzględniona wraz z resztą danych projektu.
    """

    static func answer(question: String, contextSnapshot: String) async throws -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.emptyQuestion }

        try requireFoundationModel(for: .freeformChat)

        let instructions = """
        Jesteś lokalnym asystentem aplikacji BeSorted (organizacja projektów, zadań, planu i błędów).
        Odpowiadasz po polsku, krótko i naturalnie, jak w luźnej rozmowie.
        Rozumiesz pytania napisane potocznie, nawet jednym hasłem (np. „ile jest projektów”).
        Nie używaj sztywnych regułek stylu, oficjalnych formułek ani długich wstępów.
        Opieraj się wyłącznie na podanym stanie danych użytkownika.
        Jeśli czegoś nie ma w danych, powiedz wprost że nie wiesz.
        Jeśli pytanie dotyczy sensu / planu projektu, a w danych widać puste lub placeholderowe opisy (np. „.”),
        powiedz że masz za mało informacji — nie zgaduj.
        Nie wymyślaj projektów ani zadań.
        Formatuj odpowiedź w Markdown gdy jest dłuższa niż 2 zdania:
        używaj ## nagłówków, pustych linii między akapitami, list „- ” oraz **pogrubień**.

        Stan aplikacji:
        \(contextSnapshot)
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: trimmed)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Generable
    struct ProjectInsight {
        @Guide(description: "Markdown z dokładnie dwoma sekcjami ## Czym jest ten projekt oraz ## Podstawy (rdzeń). Krótkie akapity, listy „- ”, **pogrubienia**. Bez zadań i błędów.")
        var summarizedDescription: String
    }

    /// Streszczenie: czym jest projekt + podstawy/rdzeń. Timeout + lokalny fallback.
    static func summarizeProject(_ project: Project) async throws -> String {
        try requireFoundationModel(for: .summarizeProject)

        guard project.canInterpretProjectPlan else {
            return project.insufficientProjectPlanMessageMarkdown
        }

        // Snapshot stringów PRZED await — po zawieszeniu sesji AI relacje SwiftData bywają puste.
        let promptDetails = projectSummarizePromptPayload(for: project)
        let localFallback = makeLocalProjectSummary(for: project)

        do {
            let insight = try await withTimeout(seconds: 55) {
                try await summarizeProjectWithFoundationModel(details: promptDetails)
            }
            let text = insight.summarizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? localFallback : text
        } catch {
            return localFallback
        }
    }

    private static func summarizeProjectWithFoundationModel(details: String) async throws -> ProjectInsight {
        let english = AppLanguage.stored.isEnglish
        let instructions = english
            ? """
            You are the Syncly assistant. Explain what this project IS and its core basics only.
            \(gameCoreUsageHint)
            The UI already shows name, type and rating — do NOT repeat those as a card.
            Use this exact Markdown structure (keep the headings, blank line between sections):
            ## What this project is
            1–2 short paragraphs: purpose, subject, what the user is building. No task lists, no bug lists.
            ## Project basics (core)
            Summarize the project core / key assumptions. For games, distill filled core fields \
            (mechanics, gameloop, goals, win conditions, genres, structure). For other types, \
            distill fundamentals from the description. Use short paragraphs and “- ” bullets.
            Do not invent facts. Do not cover open tasks, completed work, or bugs.
            If the description and core are empty or only placeholders (e.g. “.”), respond ONLY with:
            ## Not enough information
            plus a short list of what the user should fill in — do not guess the project.
            Respond in English. Prefer **bold** for key terms.
            """
            : """
            Jesteś asystentem Syncly. Opisz wyłącznie CZYM JEST ten projekt oraz jego podstawy (rdzeń).
            \(gameCoreUsageHint)
            Nazwa, typ i ocena są już w UI — NIE powtarzaj ich jako karty.
            Użyj dokładnie tej struktury Markdown (zachowaj nagłówki, pusta linia między sekcjami):
            ## Czym jest ten projekt
            1–2 krótkie akapity: cel, temat, nad czym pracuje użytkownik. Bez list zadań i błędów.
            ## Podstawy (rdzeń projektowy)
            Streść rdzeń / kluczowe założenia. Dla gier: wypełnione pola rdzenia \
            (mechaniki, gameloop, cele, warunki wygranej, gatunki, struktura). Dla innych typów: \
            fundamenty z opisu. Krótkie akapity i listy „- ”.
            Nie wymyślaj faktów. Nie opisuj otwartych zadań, postępu ani błędów.
            Jeśli opis i rdzeń są puste albo to same placeholdery (np. „.”), odpowiedz TYLKO:
            ## Za mało informacji
            oraz krótką listą, co uzupełnić — bez zgadywania projektu.
            Odpowiadaj po polsku. Preferuj **pogrubienia** przy kluczowych pojęciach.
            """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: english
                ? "Summarize what this project is and its core basics:\n\(details)"
                : "Streść, czym jest ten projekt i jakie są jego podstawy (rdzeń):\n\(details)",
            generating: ProjectInsight.self
        )
        return response.content
    }

    /// Payload pod streszczenie: opis + rdzeń (bez zadań/błędów).
    private static func projectSummarizePromptPayload(for project: Project) -> String {
        let detailsText = project.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let clippedDetails = detailsText.count > 2_200
            ? String(detailsText.prefix(2_200)) + "…"
            : detailsText

        var lines: [String] = []
        lines.append("Nazwa: \(project.name)")
        lines.append("Typ: \(project.kind.title)")
        lines.append("Gwiazdki: \(project.importance)/5")
        lines.append("Opis: \(clippedDetails.isEmpty ? "(brak)" : clippedDetails)")
        let core = gameCoreSnippet(for: project).trimmingCharacters(in: .whitespacesAndNewlines)
        if !core.isEmpty {
            lines.append(core)
        } else if project.kind != .game {
            lines.append("Rdzeń projektowy: (brak osobnego rdzenia — wyprowadź podstawy wyłącznie z opisu)")
        }
        return lines.joined(separator: "\n")
    }

    /// Lokalne, wierne streszczenie z opisu i rdzenia (gdy FM nie zdąży / padnie).
    static func makeLocalProjectSummary(for project: Project) -> String {
        guard project.canInterpretProjectPlan else {
            return project.insufficientProjectPlanMessageMarkdown
        }

        let english = AppLanguage.stored.isEnglish
        let details = project.details.trimmingCharacters(in: .whitespacesAndNewlines)

        let whatHeading = english ? "## What this project is" : "## Czym jest ten projekt"
        let basicsHeading = english ? "## Project basics (core)" : "## Podstawy (rdzeń projektowy)"

        let whatBody: String
        if project.hasMeaningfulDescription {
            let clipped = details.count > 480 ? String(details.prefix(480)) + "…" : details
            whatBody = clipped
        } else {
            whatBody = english
                ? "Description is thin — basics below come from the filled project core."
                : "Opis jest ubogi — poniższe podstawy pochodzą z uzupełnionego rdzenia."
        }

        var basicsLines: [String] = []
        if project.kind == .game {
            func bullet(_ title: String, _ value: String) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let clip = trimmed.count > 160 ? String(trimmed.prefix(160)) + "…" : trimmed
                basicsLines.append("- **\(title):** \(clip)")
            }
            bullet(english ? "Mechanics" : "Mechaniki", project.gameMechanics)
            bullet("Gameloop", project.gameGameloop)
            bullet(english ? "Player goals" : "Cele gracza", project.gamePlayerGoals)
            bullet(english ? "Win conditions" : "Warunki wygranej", project.gameWinConditions)
            let genres = project.gameGenres.sorted { $0.title < $1.title }.map(\.title)
            if !genres.isEmpty {
                basicsLines.append("- **\(english ? "Genres" : "Gatunki"):** \(genres.joined(separator: ", "))")
            }
            if let structure = project.gameStructure?.title {
                basicsLines.append("- **\(english ? "Structure" : "Struktura"):** \(structure)")
            }
        } else if project.kind == .story {
            func bullet(_ title: String, _ value: String) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let clip = trimmed.count > 160 ? String(trimmed.prefix(160)) + "…" : trimmed
                basicsLines.append("- **\(title):** \(clip)")
            }
            bullet(english ? "Central theme" : "Motyw przewodni", project.storyTheme)
            bullet(english ? "Typical action" : "Typowa akcja", project.storyTypicalAction)
            bullet(english ? "Hero’s goal" : "Cel bohatera", project.storyHeroGoal)
            bullet(english ? "Finale" : "Finał", project.storyFinale)
            let genres = project.storyGenres.sorted { $0.title < $1.title }.map(\.title)
            if !genres.isEmpty {
                basicsLines.append("- **\(english ? "Genres" : "Gatunki"):** \(genres.joined(separator: ", "))")
            }
            if let narration = project.storyNarration?.title {
                basicsLines.append("- **\(english ? "Narration" : "Sposób opowiadania"):** \(narration)")
            }
        } else if project.kind == .drawing {
            func bullet(_ title: String, _ value: String) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let clip = trimmed.count > 160 ? String(trimmed.prefix(160)) + "…" : trimmed
                basicsLines.append("- **\(title):** \(clip)")
            }
            let techniques = project.drawingTechniques.sorted { $0.title < $1.title }.map(\.title)
            if !techniques.isEmpty {
                basicsLines.append("- **\(english ? "Technique & tools" : "Technika i narzędzia"):** \(techniques.joined(separator: ", "))")
            }
            bullet(english ? "Main motif" : "Główny motyw", project.drawingMainMotif)
            bullet(english ? "Goal & emotion" : "Cel i emocja", project.drawingGoalEmotion)
            bullet(english ? "Done when" : "Definicja ukończenia", project.drawingCompletionDefinition)
            let genres = project.drawingGenres.sorted { $0.title < $1.title }.map(\.title)
            if !genres.isEmpty {
                basicsLines.append("- **\(english ? "Genres" : "Gatunki"):** \(genres.joined(separator: ", "))")
            }
            if let scale = project.drawingScale {
                basicsLines.append("- **\(english ? "Scale & space" : "Skala i przestrzeń"):** \(scale.title)")
            }
        } else if project.kind == .app {
            func bullet(_ title: String, _ value: String) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let clip = trimmed.count > 160 ? String(trimmed.prefix(160)) + "…" : trimmed
                basicsLines.append("- **\(title):** \(clip)")
            }
            bullet(english ? "Key features" : "Kluczowe funkcjonalności", project.appKeyFeatures)
            bullet(english ? "User path" : "Ścieżka użytkownika", project.appUserPath)
            bullet(english ? "Main problem" : "Główny problem", project.appMainProblem)
            if let category = project.appCategory {
                basicsLines.append("- **\(english ? "App category" : "Kategoria aplikacji"):** \(category.title)")
            }
        } else if project.kind == .school {
            func bullet(_ title: String, _ value: String) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let clip = trimmed.count > 160 ? String(trimmed.prefix(160)) + "…" : trimmed
                basicsLines.append("- **\(title):** \(clip)")
            }
            if let form = project.schoolForm {
                basicsLines.append("- **\(english ? "Form" : "Forma projektu"):** \(form.title)")
            }
            bullet(english ? "Project goal" : "Cel projektu", project.schoolProjectGoal)
            bullet(english ? "Main content" : "Główna zawartość", project.schoolMainContent)
            bullet(english ? "School subject" : "Przedmiot szkolny", project.schoolSubject)
            if let implementation = project.schoolImplementation {
                basicsLines.append("- **\(english ? "Work mode" : "Sposób realizacji"):** \(implementation.title)")
            }
            bullet(english ? "Final criterion" : "Kryterium końcowe", project.schoolCompletionCriteria)
        }

        let basicsBody: String
        if basicsLines.isEmpty {
            basicsBody = english
                ? "No separate core fields — basics come from the description above."
                : "Brak osobnych pól rdzenia — podstawy wynikają z opisu powyżej."
        } else {
            basicsBody = basicsLines.joined(separator: "\n")
        }

        return "\(whatHeading)\n\(whatBody)\n\n\(basicsHeading)\n\(basicsBody)"
    }

    private static func withTimeout<T>(
        seconds: Double,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Komunikat lokalizujemy PRZED grupą zadań: `l10n` jest izolowany do
        // main actora, a ciało `addTask` jest nieizolowane (błąd w Swift 6).
        let timeoutMessage = "AI zbyt długo przygotowywało odpowiedź. Spróbuj ponownie.".l10n

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ServiceError.unavailable(timeoutMessage)
            }
            guard let first = try await group.next() else {
                throw ServiceError.unavailable("AI jest teraz niedostępne.".l10n)
            }
            group.cancelAll()
            return first
        }
    }

    @Generable
    struct DescriptionSummary {
        @Guide(description: "Streszczenie opisu projektu po polsku, zwięzłe 2-5 zdań, naturalne.")
        var summary: String
    }

    @Generable
    struct ProposedTaskItem {
        @Guide(description: "Krótka nazwa: czasownik + konkretny rezultat. BEZ numeracji (zakaz: 1. / 1) / #1 / Zadanie 1)")
        var name: String

        @Guide(description: "1–2 zdania: dlaczego to zadanie jest potrzebne W TYM projekcie. BEZ numeracji listy (zakaz 1. / #1 na początku)")
        var details: String

        @Guide(description: "Jedna z dozwolonych etykiet rodzaju zadania")
        var kindLabel: String

        @Guide(description: "Ważność 1-5 (5 = krytyczne dla postępu tego projektu)")
        var importance: Int
    }

    @Generable
    struct ProposedTasksPayload {
        @Guide(description: "Dokładnie 7 użytecznych, niewchodzących w siebie zadań ściśle pod ten projekt")
        var tasks: [ProposedTaskItem]
    }

    static func summarizeProjectDescription(_ project: Project) async throws -> String {
        try requireSkill(.summarizeDescription)

        guard project.hasMeaningfulDescription else {
            throw ServiceError.unavailable(project.insufficientProjectPlanMessageShort)
        }

        let source = project.details.trimmingCharacters(in: .whitespacesAndNewlines)

        if SmartAssistantStore.shared.activeTier != .pro {
            return try SmartAssistantLocalRuntime.summarizeDescription(from: source)
        }

        if let message = availabilityMessage() {
            throw ServiceError.unavailable(message)
        }

        let english = AppLanguage.stored.isEnglish
        let instructions = english
            ? """
            You are the Syncly assistant. Summarize the project description in English, briefly and naturally.
            You may use context files, but the summary should focus on the description.
            \(gameCoreUsageHint)
            Format the answer in Markdown with a short heading and body, for example:
            ## Summary
            2–5 natural sentences.
            Do not add fluff like “Here is a summary”.
            """
            : """
            Jesteś asystentem Syncly. Streszczasz opis projektu po polsku, krótko i naturalnie.
            Możesz uwzględnić pliki kontekstowe środowiska projektu, ale streszczenie ma dotyczyć głównie opisu.
            \(gameCoreUsageHint)
            Sformatuj odpowiedź w Markdown z krótkim nagłówkiem i treścią, np.:
            ## Streszczenie
            2–5 naturalnych zdań.
            Nie dodawaj wstępów typu „Oto streszczenie”.
            """
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: """
            \(english ? "Project name" : "Nazwa projektu"): \(project.name)
            \(english ? "Type" : "Typ"): \(project.kind.title)
            \(english ? "Description to summarize" : "Opis do streszczenia"):
            \(source)

            \(english ? "Environment context files" : "Pliki kontekstowe środowiska (dokumentacja / materiały kluczowe dla AI)"):
            \(contextFilesSnippet(for: project, maxCharacters: 12_000))
            \(gameCoreSnippet(for: project))
            """,
            generating: DescriptionSummary.self
        )
        return response.content.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func proposeTasks(for project: Project) async throws -> [ProposedTaskDraft] {
        try requireSkill(.proposeTasks)

        let allowedKinds = TaskKind.kinds(for: project.kind)
        let existingNames = project.taskList
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let previousProposals = loadPreviousProposedTaskNames(for: project.syncUUID)
        let avoidNames = Array(Set(existingNames + previousProposals)).sorted()

        guard project.canProposeProjectWorkTasks else {
            throw ServiceError.unavailable(project.proposeTasksInsufficientMessageShort)
        }

        if SmartAssistantStore.shared.activeTier != .pro {
            let quality: SmartAssistantLocalRuntime.ProposeQuality =
                SmartAssistantStore.shared.activeTier == .plus ? .plus : .standard
            let drafts = try SmartAssistantLocalRuntime.proposeTasks(
                for: project,
                avoidNames: avoidNames,
                quality: quality
            )
            rememberProposedTaskNames(drafts.map(\.name), for: project.syncUUID)
            return drafts
        }

        try requireFoundationModel(for: .proposeTasks)

        let english = AppLanguage.stored.isEnglish
        let kindLabels = allowedKinds.map(\.title).joined(separator: ", ")

        let focusHint: String = {
            switch (english, project.kind) {
            case (true, .game):
                return "Focus on playable work for THIS game: mechanics, assets, feel, levels, blockers — based on known facts."
            case (false, .game):
                return "Skup się na pracy NAD TĄ grą: mechaniki, assety, feel, poziomy, blokady — na podstawie znanych faktów."
            case (true, .drawing):
                return "Focus on drawing the piece: composition, hero elements, polish — from what is already known."
            case (false, .drawing):
                return "Skup się na rysowaniu pracy: kompozycja, element wiodący, polish — z tego, co już wiadomo."
            case (true, .story):
                return "Focus on writing/story craft: scenes, characters, stakes — from known story facts."
            case (false, .story):
                return "Skup się na rzemiośle historii: sceny, postacie, stawki — ze znanych faktów fabularnych."
            case (true, .app):
                return "Focus on building the app product: key features, onboarding, core user path, problem fit — from known facts."
            case (false, .app):
                return "Skup się na budowaniu aplikacji: kluczowe funkcjonalności, onboarding, główna ścieżka użytkownika, dopasowanie do problemu — na podstawie znanych faktów."
            case (true, .school):
                return "Focus on doing the schoolwork itself: drills, outline, submission quality — from known assignment facts."
            case (false, .school):
                return "Skup się na wykonaniu pracy szkolnej: ćwiczenia, konspekt, jakość oddania — ze znanych faktów zadania."
            }
        }()

        let avoidBlock: String = {
            guard !avoidNames.isEmpty else {
                return english
                    ? "First proposals for this project — still invent fresh, concrete work."
                    : "To pierwsze propozycje dla tego projektu — i tak wymyśl świeże, konkretne prace."
            }
            let listed = avoidNames.prefix(40).map { "- \($0)" }.joined(separator: "\n")
            return english
                ? """
                DO NOT REPEAT — skip same or near-same names / intent:
                \(listed)
                Invent a different set of 7 (different goals, angle, wording).
                """
                : """
                ZAKAZ POWTÓRZEŃ — nie proponuj zadań o tych samych lub bardzo podobnych nazwach / sensie:
                \(listed)
                Wymyśl kompletnie inną siódemkę (inne cele, inny kąt, inne sformułowania).
                """
        }()

        let openTasks = project.taskList
            .filter { !$0.isCompleted }
            .sorted { $0.importance > $1.importance }
            .prefix(12)
            .map { "- \($0.name) (\($0.importance)/5)" }
            .joined(separator: "\n")
        let openBugs = project.bugList
            .sorted { $0.severity > $1.severity }
            .prefix(8)
            .map { "- \($0.title) (\($0.severity)/5)" }
            .joined(separator: "\n")

        let creativeAngles = english
            ? [
                "unblock the highest risk that stops progress this week",
                "build the smallest foundation without which nothing else works",
                "ship something visible to the end user / audience",
                "raise quality with a focused polish / clarity pass",
                "test a bold variant that could change the direction",
                "structure execution into concrete checkable steps",
                "fill missing content / assets / materials for the product itself",
                "resolve dependencies between project parts"
            ]
            : [
                "odblokuj największe ryzyko, które zatrzymuje postęp w tym tygodniu",
                "zbuduj najmniejszy fundament, bez którego nic dalej nie ruszy",
                "dostarcz coś widocznego dla użytkownika / odbiorcy",
                "podnieś jakość skupionym passem polishu / czytelności",
                "przetestuj śmiały wariant, który może zmienić kierunek",
                "uporządkuj egzekucję w konkretne, sprawdzalne kroki",
                "uzupełnij brakujące treści / assety / materiały samego produktu",
                "rozwiąż zależności między częściami projektu"
            ]
        let angle = creativeAngles.randomElement()!
        let runID = UUID().uuidString.prefix(8)
        let seed = UInt64.random(in: UInt64.min...UInt64.max)

        let instructions = english
            ? """
            You are Syncly’s Smart Assistant Pro (Foundation Model). Propose exactly 7 tasks that ADVANCE THE PROJECT WORK itself.
            \(focusHint)
            You MAY read context files and project core as KNOWLEDGE about what already exists — never propose tasks whose goal is to fill Syncly fields.
            \(gameCoreUsageHint)
            Use only these task kind labels (kindLabel): \(kindLabels).
            Importance 1–5 (5 = critical path).

            HARD BANS (never propose these as tasks):
            - Filling / completing Project Core fields in the app
            - Adding / attaching / importing context files
            - Writing or expanding the project description / brief inside Syncly
            - Meta “organize the Syncly project” chores unrelated to building the product

            QUALITY BAR:
            - Each task = verb + concrete deliverable for the product (game/drawing/story/schoolwork).
            - Details cite known facts from description, filled core, files, bugs, open work.
            - Prefer severe bugs, unfinished foundations, playable/visible progress.
            - Do not invent systems absent from the data.
            - NEVER number tasks in name or details (no "1.", "1)", "#1", "Task 1:" — plain titles only).
            Every call must produce a different list than earlier proposals.
            """
            : """
            Jesteś Smart Assistant Pro w Syncly (Foundation Model). Proponujesz dokładnie 7 zadań, które POSUWAJĄ SAMĄ PRACĘ NAD PROJEKTEM.
            \(focusHint)
            Pliki kontekstowe i rdzeń możesz CZYTAĆ jako wiedzę o tym, co już jest — nigdy nie proponuj zadań, których celem jest uzupełnianie pól w Syncly.
            \(gameCoreUsageHint)
            Używaj wyłącznie tych etykiet rodzaju (kindLabel): \(kindLabels).
            Importance 1–5 (5 = ścieżka krytyczna).

            TWARDE ZAKAZY (nigdy nie proponuj takich zadań):
            - Uzupełnianie / domykanie pól Rdzenia Projektowego w aplikacji
            - Dodawanie / dołączanie / import plików kontekstowych
            - Pisanie lub rozbudowa opisu / briefu projektu w Syncly
            - Meta-porządkowanie Syncly niezwiązane z budowaniem produktu

            POPRZĘCZKA JAKOŚCI:
            - Każde zadanie = czasownik + konkretny rezultat produktu (gra/rysunek/opowiadanie/szkoła).
            - Details odwołują się do znanych faktów z opisu, wypełnionego rdzenia, plików, błędów, otwartych prac.
            - Preferuj poważne błędy, niedokończone fundamenty, grywalny/widoczny postęp.
            - Nie wymyślaj systemów spoza danych.
            - NIGDY nie numeruj zadań w nazwie ani opisie (zakaz „1.”, „1)”, „#1”, „Zadanie 1:” — same zwykłe tytuły).
            Każde wywołanie musi dać INNĄ listę niż wcześniejsze.
            """

        let description = project.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(
            samplingMode: .random(top: 48, seed: seed),
            temperature: 0.72
        )
        let descriptionLine: String = {
            if project.hasMeaningfulDescription {
                return description
            }
            return english
                ? "(description thin — rely on filled project core and other known facts; do NOT invent a new concept)"
                : "(opis ubogi — opieraj się na wypełnionym rdzeniu i innych znanych faktach; NIE wymyślaj nowej koncepcji)"
        }()

        let response = try await session.respond(
            to: """
            \(english ? "Proposal session" : "Sesja propozycji") #\(runID) (seed \(seed)).
            \(english ? "Creative angle this round" : "Kąt kreatywny tej rundy"): \(angle)

            \(english ? "Propose exactly 7 highest-leverage product-work tasks." : "Zaproponuj dokładnie 7 zadań o najwyższej dźwigni nad samym produktem.")
            \(english ? "Name" : "Nazwa"): \(project.name)
            \(english ? "Type" : "Typ"): \(project.kind.title)
            \(english ? "Description" : "Opis"): \(descriptionLine)

            \(english ? "Open tasks (do not duplicate)" : "Otwarte zadania (nie duplikuj)"):
            \(openTasks.isEmpty ? (english ? "(none)" : "(brak)") : openTasks)

            \(english ? "Bugs (prefer addressing high severity)" : "Błędy (preferuj wysoką wagę)"):
            \(openBugs.isEmpty ? (english ? "(none)" : "(brak)") : openBugs)

            \(english ? "Known environment facts (read-only knowledge — do not propose “add context files”)" : "Znane fakty środowiska (wiedza tylko do odczytu — nie proponuj „dodaj pliki kontekstowe”)"):
            \(contextFilesSnippet(for: project, maxCharacters: 18_000))
            \(gameCoreSnippet(for: project))

            \(avoidBlock)
            """,
            generating: ProposedTasksPayload.self,
            options: options
        )

        let drafts = response.content.tasks.prefix(7).compactMap { item -> ProposedTaskDraft? in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let details = item.details.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            if SmartAssistantLocalRuntime.isMetaSynclyChore(name: name, details: details) {
                return nil
            }
            let kind = allowedKinds.first {
                $0.title.localizedCaseInsensitiveCompare(item.kindLabel) == .orderedSame
                    || item.kindLabel.localizedCaseInsensitiveContains($0.title)
                    || $0.rawValue.localizedCaseInsensitiveCompare(item.kindLabel) == .orderedSame
            } ?? allowedKinds.first ?? .other

            return ProposedTaskDraft(
                name: name,
                details: details,
                kind: kind,
                importance: min(max(item.importance, 1), 5)
            )
        }

        let finalDrafts = Array(drafts.prefix(7))
        rememberProposedTaskNames(finalDrafts.map(\.name), for: project.syncUUID)
        return finalDrafts
    }

    private static func previousProposalsKey(for projectID: UUID) -> String {
        "besorted.previousProposedTasks.\(projectID.uuidString)"
    }

    private static func loadPreviousProposedTaskNames(for projectID: UUID) -> [String] {
        UserDefaults.standard.stringArray(forKey: previousProposalsKey(for: projectID)) ?? []
    }

    private static func rememberProposedTaskNames(_ names: [String], for projectID: UUID) {
        let key = previousProposalsKey(for: projectID)
        var merged = loadPreviousProposedTaskNames(for: projectID)
        for name in names where !name.isEmpty {
            if !merged.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                merged.append(name)
            }
        }
        // Trzymaj ostatnie ~40 nazw, żeby uniknąć powtórzeń bez rozdymania promptu.
        if merged.count > 40 {
            merged = Array(merged.suffix(40))
        }
        UserDefaults.standard.set(merged, forKey: key)
    }

    struct PlanFillItem {
        var project: Project
        var existingTask: ProjectTask?
        var draft: ProposedTaskDraft?
    }

    /// Dobiera zadania z projektów priorytetowych do uzupełnienia Aktualnego Planu.
    /// Przy 2 projektach: 4 z ważniejszego + 3 z mniej ważnego (reszta slotów przy większej liczbie projektów
    /// też idzie najpierw do wyższych gwiazdek). Niewykorzystane sloty są oddawane kolejnym projektom.
    static func selectTasksForCurrentPlan(
        priorityProjects: [Project],
        targetCount: Int? = nil
    ) async throws -> [PlanFillItem] {
        let targetCount = targetCount ?? CurrentPlanStore.maxActiveTasks
        try requireSkill(.fillCurrentPlan)

        if SmartAssistantStore.shared.activeTier != .pro {
            return try SmartAssistantLocalRuntime.selectTasksForCurrentPlan(
                priorityProjects: priorityProjects,
                targetCount: targetCount
            )
        }

        if let message = availabilityMessage() {
            throw ServiceError.unavailable(message)
        }

        let projects = priorityProjects.filter(\.isPriorityHighlighted)
        guard !projects.isEmpty else {
            throw ServiceError.unavailable("Najpierw oznacz projekty jako priorytetowe.")
        }

        let orderedProjects = projects.sorted(by: Self.planProjectRank)

        // Snapshot przed jakimkolwiek await — relacje SwiftData bywają puste po zawieszeniu sesji AI.
        let candidateMap: [UUID: (project: Project, tasks: [ProjectTask])] = Dictionary(
            uniqueKeysWithValues: orderedProjects.map { project in
                let tasks = project.taskList
                    .filter { !$0.isCompleted && !$0.isInCurrentPlan && $0.planQueuedAt == nil }
                    .sorted {
                        if $0.importance != $1.importance { return $0.importance > $1.importance }
                        return $0.createdAt < $1.createdAt
                    }
                return (project.syncUUID, (project, tasks))
            }
        )

        guard candidateMap.values.contains(where: { !$0.tasks.isEmpty }) else {
            throw ServiceError.unavailable(
                "Brak istniejących zadań w projektach priorytetowych. Dodaj zadania w projekcie albo użyj „Zaproponuj zadania”."
            )
        }

        var quotas = planQuotas(for: orderedProjects, total: targetCount)
        var selected: [PlanFillItem] = []
        var selectedIDs = Set<PersistentIdentifier>()

        func appendPicked(from project: Project, tasks: [ProjectTask], limit: Int) async {
            guard limit > 0, !tasks.isEmpty else { return }
            let available = tasks.filter { !selectedIDs.contains($0.persistentModelID) }
            guard !available.isEmpty else { return }

            let picked: [ProjectTask]
            do {
                picked = try await pickExistingTasks(
                    from: available,
                    project: project,
                    count: min(limit, available.count)
                )
            } catch {
                // Awaria AI dla jednego projektu nie blokuje pozostałych.
                picked = Array(available.prefix(min(limit, available.count)))
            }

            for task in picked.prefix(limit) {
                let id = task.persistentModelID
                guard !selectedIDs.contains(id) else { continue }
                selectedIDs.insert(id)
                selected.append(PlanFillItem(project: project, existingTask: task, draft: nil))
                if selected.count >= targetCount { return }
            }
        }

        // Runda 1: wypełnij kwoty (ważniejszy projekt pierwszy).
        for project in orderedProjects {
            if selected.count >= targetCount { break }
            let quota = quotas[project.syncUUID, default: 0]
            guard quota > 0, let entry = candidateMap[project.syncUUID] else { continue }
            let before = selected.count
            await appendPicked(from: entry.project, tasks: entry.tasks, limit: quota)
            let used = selected.count - before
            quotas[project.syncUUID] = max(0, quota - used)
        }

        // Runda 2: oddaj niewykorzystane sloty kolejnym projektom (też od najważniejszego).
        var leftover = max(0, targetCount - selected.count)
        if leftover > 0 {
            for project in orderedProjects {
                guard leftover > 0 else { break }
                guard let entry = candidateMap[project.syncUUID] else { continue }
                let before = selected.count
                await appendPicked(from: entry.project, tasks: entry.tasks, limit: leftover)
                let used = selected.count - before
                leftover -= used
            }
        }

        guard !selected.isEmpty else {
            throw ServiceError.unavailable(
                "Brak istniejących zadań w projektach priorytetowych. Dodaj zadania w projekcie albo użyj „Zaproponuj zadania”."
            )
        }

        return Array(selected.prefix(targetCount))
    }

    private static func planProjectRank(_ a: Project, _ b: Project) -> Bool {
        if a.importance != b.importance { return a.importance > b.importance }
        let aDone = a.taskList.filter(\.isCompleted).count
        let bDone = b.taskList.filter(\.isCompleted).count
        if aDone != bDone { return aDone > bDone }
        return a.createdAt < b.createdAt
    }

    /// Podział slotów: baza po równo, reszta (np. 7→3+3+1) idzie do projektów z wyższymi gwiazdkami.
    /// Przy 2 projektach daje 4 ważniejszemu i 3 mniej ważnemu.
    static func planQuotas(for projects: [Project], total: Int) -> [UUID: Int] {
        guard !projects.isEmpty else { return [:] }
        let base = total / projects.count
        var remaining = total % projects.count
        var quotas = Dictionary(uniqueKeysWithValues: projects.map { ($0.syncUUID, base) })

        let ranked = projects.sorted(by: Self.planProjectRank)

        for project in ranked where remaining > 0 {
            quotas[project.syncUUID, default: 0] += 1
            remaining -= 1
        }
        return quotas
    }

    @Generable
    struct PlanTaskPickPayload {
        @Guide(description: "Nazwy istniejących zadań w kolejności od najważniejszego, bez wymyślania nowych")
        var taskNames: [String]
    }

    private static func pickExistingTasks(
        from candidates: [ProjectTask],
        project: Project,
        count: Int
    ) async throws -> [ProjectTask] {
        guard count > 0 else { return [] }
        if candidates.count <= count {
            return Array(candidates.prefix(count))
        }

        let list = candidates.enumerated().map { index, task in
            "\(index + 1). „\(task.name)” | gwiazdki \(task.importance)/5 | \(task.kind.title) | \(task.details)"
        }.joined(separator: "\n")

        let instructions = """
        Jesteś asystentem BeSorted. Wybierasz najważniejsze istniejące zadania do Aktualnego Planu.
        Oceń po opisie projektu, gwiazdkach zadań i sensie priorytetu.
        Zwróć wyłącznie nazwy z podanej listy, bez wymyślania nowych.
        Kolejność: od najważniejszego.
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: """
            Projekt: \(project.name) (gwiazdki projektu \(project.importance)/5)
            Opis projektu: \(project.details.isEmpty ? "(brak)" : project.details)
            Pliki kontekstowe:
            \(contextFilesSnippet(for: project, maxCharacters: 8_000))

            Wybierz dokładnie \(count) najważniejszych zadań z listy:
            \(list)
            """,
            generating: PlanTaskPickPayload.self
        )

        var picked: [ProjectTask] = []
        var remaining = candidates
        for name in response.content.taskNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let matchIndex = remaining.firstIndex(where: {
                $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
                    || $0.name.localizedCaseInsensitiveContains(trimmed)
                    || trimmed.localizedCaseInsensitiveContains($0.name)
            }) else { continue }
            picked.append(remaining.remove(at: matchIndex))
            if picked.count >= count { break }
        }

        if picked.count < count {
            picked.append(contentsOf: remaining.prefix(count - picked.count))
        }
        return Array(picked.prefix(count))
    }

    static func proposeTasks(for project: Project, count: Int) async throws -> [ProposedTaskDraft] {
        let all = try await proposeTasks(for: project)
        if all.count >= count { return Array(all.prefix(count)) }
        return all
    }

    @Generable
    struct TaskBreakdownPayload {
        @Guide(description: "Maksymalnie 7 konkretnych punktów / kroków pomagających wykonać zadanie")
        var points: [String]
    }

    /// Rozbija zadanie na max 7 punktów. Jeśli kontekst wskazuje silnik (Unity/Godot/…), trzyma się go.
    static func breakDownTask(_ task: ProjectTask) async throws -> [String] {
        try requireFoundationModel(for: .breakDownTask)

        guard let project = task.project else {
            throw ServiceError.unavailable("Zadanie nie jest powiązane z projektem.")
        }

        let taskNameOK = !Project.isMeaninglessLabel(task.name)
        let taskDetailsOK = task.details.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
        guard taskNameOK || taskDetailsOK || project.canInterpretProjectPlan else {
            throw ServiceError.unavailable(project.insufficientProjectPlanMessageShort)
        }

        let filesSnippet = contextFilesSnippet(for: project, maxCharacters: 16_000)
        let hasFiles = !project.contextFileList.isEmpty
        let projectDetails = project.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskDetails = task.details.trimmingCharacters(in: .whitespacesAndNewlines)

        let instructions = """
        Jesteś asystentem BeSorted. Rozbijasz zadanie na maksymalnie 7 konkretnych, praktycznych punktów,
        które pomogą użytkownikowi wykonać to zadanie (np. rozbicie mechaniki gry na elementy implementacji).

        Zasady silnika / środowiska:
        - Jeśli w opisie projektu, opisie zadania LUB plikach kontekstowych widać konkretny silnik/narzędzie
          (np. Unity, Godot, Unreal, SwiftUI, Blender) — rozbijaj ściśle pod to środowisko (konkretne API,
          węzły, komponenty, workflow typowe dla niego).
        - Jeśli nie ma żadnych wskazówek o silniku/narzędziach — pisz ogólnie i praktycznie,
          BEZ zgadywania konkretnego silnika.

        Odpowiadaj po polsku. Punkty krótkie, actionable, bez wstępów.
        Nie numeruj punktów (zakaz „1.”, „1)”, „#1” na początku — sam tekst kroku).
        Nie wymyślaj faktów spoza podanego kontekstu.
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: """
            Rozbij to zadanie na maksymalnie 7 punktów pomocy.

            Zadanie: \(task.name)
            Pełny opis zadania: \(taskDetails.isEmpty ? "(brak szczegółowego opisu)" : taskDetails)
            Rodzaj zadania: \(task.kind.title)
            Gwiazdki zadania: \(task.importance)/5

            Projekt: \(project.name) (\(project.kind.title), gwiazdki \(project.importance)/5)
            Opis projektu: \(projectDetails.isEmpty ? "(brak)" : projectDetails)

            Pliki kontekstowe środowiska (\(hasFiles ? "są dostępne" : "brak")):
            \(filesSnippet)
            """,
            generating: TaskBreakdownPayload.self
        )

        return response.content.points
            .map { ProposedTaskDraft.stripTaskNumbering($0) }
            .filter { !$0.isEmpty }
            .prefix(7)
            .map { $0 }
    }

    private static func projectFullSnapshot(for project: Project) -> String {
        let openTasks = project.taskList.filter { !$0.isCompleted }
            .sorted {
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                return $0.createdAt < $1.createdAt
            }
        let doneTasks = project.taskList.filter(\.isCompleted)
            .sorted { $0.updatedAt > $1.updatedAt }
        let bugs = project.bugList.sorted { $0.severity > $1.severity }
        let notes = project.futureNoteList

        var lines: [String] = []
        lines.append("Projekt: \(project.name) | typ: \(project.kind.title) | gwiazdki \(project.importance)/5")
        lines.append("Opis projektu: \(project.details.isEmpty ? "(brak)" : project.details)")
        lines.append("Pliki kontekstowe:\n\(contextFilesSnippet(for: project, maxCharacters: 10_000))")
        let core = gameCoreSnippet(for: project)
        if !core.isEmpty {
            lines.append(core.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        lines.append("Wykonane zadania (\(doneTasks.count)):")
        if doneTasks.isEmpty {
            lines.append("(brak)")
        } else {
            for task in doneTasks.prefix(30) {
                lines.append("- „\(task.name)” (\(task.kind.title), \(task.importance)/5): \(task.details)")
            }
        }

        lines.append("Niedokończone zadania (\(openTasks.count)):")
        if openTasks.isEmpty {
            lines.append("(brak)")
        } else {
            for task in openTasks {
                lines.append("- „\(task.name)” (\(task.kind.title), \(task.importance)/5): \(task.details)")
            }
        }

        lines.append("Błędy (\(bugs.count)):")
        if bugs.isEmpty {
            lines.append("(brak)")
        } else {
            for bug in bugs {
                lines.append("- „\(bug.title)” (ważność \(bug.severity)/5): \(bug.details)")
            }
        }

        lines.append("Notatki przyszłości (\(notes.count)):")
        if notes.isEmpty {
            lines.append("(brak)")
        } else {
            for note in notes {
                lines.append("- \(note.text)")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Snapshot pod „Przypomnij projekt” — bez niedokończonych zadań (żeby nie trafiały do „Przyszłych planów”).
    private static func projectReminderSnapshot(for project: Project) -> String {
        let doneTasks = project.taskList.filter(\.isCompleted)
            .sorted { $0.updatedAt > $1.updatedAt }
        let bugs = project.bugList.sorted { $0.severity > $1.severity }
        let notes = project.futureNoteList.sorted { $0.createdAt > $1.createdAt }

        var lines: [String] = []
        lines.append("Projekt: \(project.name) | typ: \(project.kind.title) | gwiazdki \(project.importance)/5")
        lines.append("Opis projektu: \(project.details.isEmpty ? "(brak)" : project.details)")
        lines.append("Pliki kontekstowe:\n\(contextFilesSnippet(for: project, maxCharacters: 10_000))")
        let core = gameCoreSnippet(for: project)
        if !core.isEmpty {
            lines.append(core.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        lines.append("Wykonane zadania (\(doneTasks.count)) — tylko do sekcji „Co już zostało zrobione” / \"What's already done\":")
        if doneTasks.isEmpty {
            lines.append("(brak)")
        } else {
            for task in doneTasks.prefix(30) {
                lines.append("- „\(task.name)” (\(task.kind.title), \(task.importance)/5): \(task.details)")
            }
        }

        lines.append("Błędy (\(bugs.count)):")
        if bugs.isEmpty {
            lines.append("(brak)")
        } else {
            for bug in bugs {
                lines.append("- „\(bug.title)” (ważność \(bug.severity)/5): \(bug.details)")
            }
        }

        lines.append("Notatki przyszłości (\(notes.count)) — JEDYNE źródło sekcji „Przyszłe plany” / \"Future plans\":")
        if notes.isEmpty {
            lines.append("(brak — napisz w sekcji planów, że nie ma notatek przyszłości)")
        } else {
            for note in notes {
                lines.append("- \(note.text)")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Pełne przypomnienie projektu: opis, wykonane zadania, błędy, plany z notatek.
    static func remindProject(_ project: Project) async throws -> String {
        try requireSkill(.remindProject)

        guard project.canInterpretProjectPlan || project.hasMeaningfulWorkArtifacts else {
            return project.insufficientProjectPlanMessageMarkdown
        }

        if SmartAssistantStore.shared.activeTier != .pro {
            // SA i + — bogatsze lokalne przypomnienie (14 ma 6 GB; FM i tak niedostępne na SA).
            return SmartAssistantLocalRuntime.remindProject(project, rich: true)
        }

        if let message = availabilityMessage() {
            throw ServiceError.unavailable(message)
        }

        let english = AppLanguage.stored.isEnglish
        let instructions = english
            ? """
            You are the Syncly assistant. Write a clear project reminder in English.
            The UI already shows project name, type and rating — do NOT repeat those as a card.
            Use this exact Markdown structure (keep the headings):
            ## Project overview
            Brief summary of the description; weave in project-core assumptions if present.
            If description/core are empty placeholders, say “Not enough information for an overview” — do NOT invent one.
            ## What's already done
            Completed tasks only.
            ## Bugs
            Current bugs.
            ## Future plans
            ONLY from future notes. Summarize each note briefly.
            CRITICAL: Do NOT list unfinished / open tasks in Future plans. Incomplete tasks are not future plans.
            If there are no future notes, say that clearly — do not invent plans from tasks or the description.

            \(gameCoreUsageHint)
            Do not invent facts outside the data. If a section is empty, say so clearly.
            Separate sections with a blank line. Use short paragraphs and “- ” lists instead of one wall of text.
            """
            : """
            Jesteś asystentem Syncly. Przygotowujesz czytelne przypomnienie całego projektu po polsku.
            Nazwa, typ i ocena są już pokazane w UI — NIE powtarzaj ich jako karty.
            Użyj dokładnie tej struktury Markdown (zachowaj nagłówki):
            ## Przegląd projektu
            Streszczenie opisu — wpleć też założenia z rdzenia projektowego, jeśli są.
            Jeśli opis/rdzeń to puste placeholdery, napisz „Za mało informacji do przeglądu” — NIE wymyślaj przeglądu.
            ## Co już zostało zrobione
            Wyłącznie wykonane zadania.
            ## Błędy
            Aktualne błędy projektu.
            ## Przyszłe plany
            WYŁĄCZNIE na podstawie notatek przyszłości — każdą streść krótko.
            KRYTYCZNE: NIE kopiuj i NIE wymieniaj niedokończonych / otwartych zadań w „Przyszłych planach”.
            Niedokończone zadania to nie są przyszłe plany.
            Jeśli nie ma notatek przyszłości, napisz to wprost — nie wymyślaj planów z zadań ani z opisu.

            \(gameCoreUsageHint)
            Nie wymyślaj faktów spoza danych. Jeśli sekcja jest pusta, napisz to wprost.
            Oddzielaj sekcje pustą linią. W treści używaj krótkich akapitów i list „- ” zamiast jednego bloku tekstu.
            """

        let session = LanguageModelSession(instructions: instructions)
        let prompt = english
            ? "Remind me about this project:\n\(projectReminderSnapshot(for: project))"
            : "Przypomnij ten projekt:\n\(projectReminderSnapshot(for: project))"
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Jedno najważniejsze otwarte zadanie (albo jeden kolejny krok, gdy wszystko zrobione).
    static func whatCanIDoNow(for project: Project) async throws -> String {
        try requireSkill(.whatCanIDoNow)

        let openMeaningful = project.taskList.contains {
            !$0.isCompleted && !Project.isMeaninglessLabel($0.name)
        }
        let canAdvise = openMeaningful
            || project.canInterpretProjectPlan
            || project.futureNoteList.contains {
                $0.text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12
            }
        guard canAdvise else {
            return project.insufficientProjectPlanMessageMarkdown
        }

        if SmartAssistantStore.shared.activeTier != .pro {
            return SmartAssistantLocalRuntime.whatCanIDoNow(for: project)
        }

        if let message = availabilityMessage() {
            throw ServiceError.unavailable(message)
        }

        let openTasks = project.taskList.filter { !$0.isCompleted && !Project.isMeaninglessLabel($0.name) }
        let allDone = openTasks.isEmpty
        let english = AppLanguage.stored.isEnglish

        let instructions: String
        if allDone {
            instructions = english
                ? """
                You are the Syncly assistant. All project tasks are completed.
                Propose exactly ONE next practical step based on the project description and future notes.
                If description/notes are empty or placeholders, respond ONLY with ## Not enough information — do not invent a step.
                Respond in English with Markdown:
                ## <short action title>
                1–3 sentences explaining why this is the best next step.
                Do not invent unrelated ideas. Be concrete.
                """
                : """
                Jesteś asystentem Syncly. Wszystkie zadania projektu są wykonane.
                Zaproponuj dokładnie JEDEN praktyczny kolejny krok na podstawie opisu i notatek przyszłości.
                Jeśli opis/notatki są puste lub to placeholdery, odpowiedz TYLKO ## Za mało informacji — nie wymyślaj kroku.
                Odpowiedz po polsku w Markdown:
                ## <krótki tytuł działania>
                1–3 zdania uzasadnienia, dlaczego to najlepszy następny krok.
                Nie wymyślaj rzeczy oderwanych od kontekstu. Bądź konkretny.
                """
        } else {
            instructions = english
                ? """
                You are the Syncly assistant. Pick exactly ONE unfinished task that is most important to do now.
                Decide using: full project context, task importance (stars), and the task's own content/details.
                Respond in English with Markdown:
                ## <exact task name from the list>
                1–3 sentences explaining why this single task matters most right now.
                Do not invent tasks. Do not list multiple tasks.
                """
                : """
                Jesteś asystentem Syncly. Wskaż dokładnie JEDNO niedokończone zadanie, którym warto zająć się teraz.
                Decyzję podejmij na podstawie: pełnego kontekstu projektu, wagi zadania (gwiazdki) oraz treści/opisu samego zadania.
                Odpowiedz po polsku w Markdown:
                ## <dokładna nazwa zadania z listy>
                1–3 zdania uzasadnienia, dlaczego właśnie to jedno zadanie jest teraz najważniejsze.
                Nie wymyślaj zadań spoza listy. Nie wymieniaj wielu zadań.
                """
        }

        let session = LanguageModelSession(instructions: instructions)
        let prompt: String
        if allDone {
            prompt = english
                ? "All tasks are done — what is the single best next step?\n\(projectFullSnapshot(for: project))"
                : "Wszystkie zadania są wykonane — jaki jest jeden najlepszy następny krok?\n\(projectFullSnapshot(for: project))"
        } else {
            prompt = english
                ? "What is the single most important task to do now?\n\(projectFullSnapshot(for: project))"
                : "Jakie jest jedno najważniejsze zadanie do zrobienia teraz?\n\(projectFullSnapshot(for: project))"
        }
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Krytyczna ocena projektu (Pro) lub audyt dziur (+). Wymaga opisu (+ rdzenia dla gry).
    static func evaluateProject(_ project: Project) async throws -> String {
        try requireSkill(.evaluateProject)

        guard project.meetsEvaluateProjectBasics else {
            let message = project.evaluateProjectBasicsMissingMessage
            throw ServiceError.unavailable(
                message.isEmpty
                    ? "Aby ocenić projekt, uzupełnij opis i Rdzeń Projektowy.".l10n
                    : message
            )
        }

        if SmartAssistantStore.shared.activeTier != .pro {
            return SmartAssistantLocalRuntime.evaluateProjectHoles(project)
        }

        if let message = availabilityMessage() {
            throw ServiceError.unavailable(message)
        }

        let snapshot = projectEvaluateSnapshot(for: project)

        let english = AppLanguage.stored.isEnglish
        let kindHint: String = {
            switch project.kind {
            case .game:
                return english
                    ? "This is a GAME — judge mechanics, loop, goals, win conditions and scope bloat."
                    : "To jest GRA — oceniaj mechaniki, loop, cele, warunki wygranej i przeładowanie scope."
            case .story:
                return english
                    ? "This is a STORY — judge theme uniqueness, typical action, hero goal, finale payoff and narration fit."
                    : "To jest OPOWIADANIE — oceniaj unikalność motywu, typową akcję, cel bohatera, wypłatę finału i dopasowanie sposobu opowiadania."
            case .drawing:
                return english
                    ? "This is a DRAWING — judge technique fit, main motif clarity, emotional intent, completion definition and scale ambition."
                    : "To jest RYSUNEK — oceniaj dopasowanie techniki, czytelność głównego motywu, intencję emocjonalną, definicję ukończenia i ambitność skali."
            case .app:
                return english
                    ? "This is an APP — judge key features' distinctiveness, user path clarity, problem fit and unnecessary extras."
                    : "To jest APLIKACJA — oceniaj wyróżniające funkcjonalności, czytelność ścieżki użytkownika, dopasowanie do problemu i zbędne dodatki."
            case .school:
                return english
                    ? "Project type: \(project.kind.title). Judge idea clarity, distinctive elements and unnecessary extras for this type."
                    : "Typ projektu: \(project.kind.title). Oceń klarowność idei, wyróżniki i zbędne dodatki typowe dla tej formy."
            }
        }()

        let instructions = english
            ? """
            You are Syncly’s honest but empathetic project critic (Apple Foundation Models).
            \(gameCoreUsageHint)
            \(kindHint)
            Use ONLY the provided data. Do not invent market facts or claim global uniqueness.
            If description/core are placeholders, refuse with ## Not enough information — do not fabricate a critique.
            Name, type and rating are already in the UI — do not repeat them as a card.

            Write Markdown with EXACTLY this structure (keep headings, blank line between sections):

            ## Opinion on the idea
            2–4 short paragraphs. Sincere and kind. State clearly whether the concept can stay as-is \
            or needs a rebuild. Bold key judgments with **...**.

            ## Standout or cheap copy
            Judge whether the idea and its most important elements stand out from a typical crowd \
            for this genre/type, or feel like a cheap copy. Be specific with evidence from the data.
            If you find extremely similar / cliché elements, add a subsection:
            ### More original directions
            At most 3 bullet ideas for better, more original solutions. Skip this subsection if the idea already feels distinctive.

            ## Unnecessary load
            Based mainly on the project’s goal and purpose, say whether there are too many spare \
            elements / mechanics / events (adapt wording to project type). Short paragraphs or “- ” bullets.

            ## Recommended actions
            Brief priorities: what matters most to change — OR say the project is already strong in its concept \
            and only needs execution. End with a clear next move.

            Separate sections with blank lines. Use **bold** for key phrases. No wall of text.
            """
            : """
            Jesteś szczerym, ale empatycznym krytykiem projektu w Syncly (Apple Foundation Models).
            \(gameCoreUsageHint)
            \(kindHint)
            Korzystaj WYŁĄCZNIE z podanych danych. Nie wymyślaj faktów o rynku ani „pierwszeństwa na świecie”.
            Jeśli opis/rdzeń to placeholdery, odmów przez ## Za mało informacji — nie fabrykuj krytyki.
            Nazwa, typ i ocena są już w UI — nie powtarzaj ich jako karty.

            Napisz Markdown z DOKŁADNIE tą strukturą (zachowaj nagłówki, pusta linia między sekcjami):

            ## Opinia o pomyśle
            2–4 krótkie akapity. Szczerze i życzliwie. Jasno: czy koncepcję można zostawić taką, jaka jest, \
            czy wymaga przebudowy. Kluczowe oceny pogrubiaj **...**.

            ## Wyróżnik czy tania kopia
            Oceń, czy idea i najważniejsze elementy wyróżniają się z typowego tłumu dla tego gatunku/typu, \
            czy brzmią jak tandetna kopia. Opieraj się na dowodach z danych.
            Jeśli znajdziesz skrajnie podobne / oklepane elementy, dodaj podsekcję:
            ### Bardziej oryginalne kierunki
            Maks. 3 punkty „- ” z lepszymi, bardziej oryginalnymi rozwiązaniami. Pomiń tę podsekcję, jeśli pomysł już jest wyróżniający.

            ## Zbędne obciążenie
            Na podstawie przede wszystkim celu i sensu projektu oceń, czy jest za dużo zbędnych elementów / \
            mechanik / wydarzeń (dostosuj język do typu projektu). Krótkie akapity lub listy „- ”.

            ## Zalecane działania
            Krótko: co jest najważniejsze do zmiany — ALBO napisz, że projekt jest już mocny w zamyśle \
            i trzeba go głównie egzekwować. Zakończ jasnym kolejnym ruchem.

            Oddzielaj sekcje pustą linią. Używaj **pogrubień** przy kluczowych frazach. Bez ściany tekstu.
            """

        let session = LanguageModelSession(instructions: instructions)
        let prompt = english
            ? "Critique this project thoroughly:\n\(snapshot)"
            : "Oceń krytycznie ten projekt:\n\(snapshot)"
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func projectEvaluateSnapshot(for project: Project) -> String {
        let openTasks = project.taskList.filter { !$0.isCompleted }
            .sorted {
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                return $0.createdAt < $1.createdAt
            }
        let bugs = project.bugList.sorted { $0.severity > $1.severity }
        let notes = project.futureNoteList

        var lines: [String] = []
        lines.append("Projekt: \(project.name) | typ: \(project.kind.title) | gwiazdki \(project.importance)/5")
        lines.append("Opis:\n\(project.details)")
        let core = gameCoreSnippet(for: project).trimmingCharacters(in: .whitespacesAndNewlines)
        if !core.isEmpty {
            lines.append(core)
        }
        lines.append("Pliki kontekstowe:\n\(contextFilesSnippet(for: project, maxCharacters: 8_000))")

        lines.append("Notatki przyszłości (\(notes.count)):")
        if notes.isEmpty {
            lines.append("(brak)")
        } else {
            for note in notes.prefix(20) {
                let text = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let clip = text.count > 220 ? String(text.prefix(220)) + "…" : text
                lines.append("- \(clip.isEmpty ? "(pusta)" : clip)")
            }
        }

        lines.append("Otwarte zadania (\(openTasks.count)):")
        if openTasks.isEmpty {
            lines.append("(brak)")
        } else {
            for task in openTasks.prefix(18) {
                let detail = task.details.trimmingCharacters(in: .whitespacesAndNewlines)
                let clip = detail.count > 100 ? String(detail.prefix(100)) + "…" : detail
                lines.append("- „\(task.name)” (\(task.importance)/5)\(clip.isEmpty ? "" : ": \(clip)")")
            }
        }

        lines.append("Błędy (\(bugs.count)):")
        if bugs.isEmpty {
            lines.append("(brak)")
        } else {
            for bug in bugs.prefix(12) {
                let detail = bug.details.trimmingCharacters(in: .whitespacesAndNewlines)
                let clip = detail.count > 90 ? String(detail.prefix(90)) + "…" : detail
                lines.append("- „\(bug.title)” (\(bug.severity)/5)\(clip.isEmpty ? "" : ": \(clip)")")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Zapomniany projekt — lokalna analiza (SA / + / Pro).
    static func suggestForgottenProject(from projects: [Project]) throws -> SmartAssistantLocalRuntime.ForgottenProjectSuggestion {
        try requireSkill(.forgottenProject)
        guard SmartAssistantStore.shared.activeTier != nil else {
            throw ServiceError.unavailable("Aktywuj Smart Assistant w Ustawieniach.".l10n)
        }
        guard let suggestion = SmartAssistantLocalRuntime.suggestForgottenProject(from: projects) else {
            throw ServiceError.unavailable(
                "Nie znaleziono zapomnianego projektu do oznaczenia jako priorytetowy.".l10n
            )
        }
        return suggestion
    }
}

struct ProposedTaskDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var details: String
    var kind: TaskKind
    var importance: Int

    init(name: String, details: String, kind: TaskKind, importance: Int) {
        self.id = UUID()
        self.name = Self.stripTaskNumbering(name)
        self.details = Self.stripTaskNumbering(details)
        self.kind = kind
        self.importance = importance
    }

    /// Usuwa numerację typu `1.`, `1)`, `#1`, `Zadanie 1:` z tytułu i każdej linii opisu.
    /// Nie rusza treści w stylu „30 s playable…” / „2D art”.
    static func stripTaskNumbering(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return lines
            .map { stripLeadingTaskNumbering(from: String($0)) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripLeadingTaskNumbering(from line: String) -> String {
        var s = line
        for _ in 0..<4 {
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            guard let peeled = peelOneTaskNumberPrefix(trimmed), peeled != trimmed else {
                return trimmed
            }
            s = peeled
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func peelOneTaskNumberPrefix(_ input: String) -> String? {
        let patterns: [String] = [
            // #1 / #1. / #12)
            #"^#\s*\d{1,2}(?:[\.\)\:\-–—])?\s+"#,
            // 1.  1)  1:  1-  (wymagany separator — nie „30 s” / „2D”)
            #"^\d{1,2}(?:[\.\)\:]|[\-–—])\s+"#,
            // (1) (12)
            #"^\(\d{1,2}\)\s*"#,
            // Zadanie 1: / Task #2 / Krok 3.
            #"^(?:Zadanie|Task|Krok|Step|Punkt|Point)\s*#?\d{1,2}(?:[\.\)\:\-–—])?\s+"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            guard let match = regex.firstMatch(in: input, options: [], range: range),
                  match.range.location == 0,
                  let swiftRange = Range(match.range, in: input)
            else { continue }
            return String(input[swiftRange.upperBound...])
        }
        return nil
    }
}
