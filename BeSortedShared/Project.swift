//
//  Project.swift
//  BeSortedShared
//

import Foundation
import SwiftData

@Model
final class Project {
    var syncUUID: UUID = UUID()
    var name: String = ""
    var details: String = ""
    /// Oryginalny opis sprzed zastąpienia streszczeniem AI (pusty = brak kopii zapasowej).
    var originalDetailsBackup: String = ""
    var kindRaw: String = "game"
    var importance: Int = 3
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPriorityHighlighted: Bool = false
    /// Ostatnie wejście w detal projektu (osobno od `updatedAt`).
    var lastOpenedAt: Date = Date(timeIntervalSince1970: 0)
    /// Liczba wejść w detal projektu.
    var openCount: Int = 0

    // Rdzeń projektowy — gra
    var gameMechanics: String = ""
    var gameGameloop: String = ""
    var gamePlayerGoals: String = ""
    var gameWinConditions: String = ""
    /// Surowce `GameGenre` rozdzielone przecinkiem.
    var gameGenresRaw: String = ""
    /// `GameStructure.rawValue` albo puste.
    var gameStructureRaw: String = ""

    // Rdzeń projektowy — opowiadanie
    var storyTheme: String = ""
    var storyTypicalAction: String = ""
    var storyHeroGoal: String = ""
    var storyFinale: String = ""
    /// Surowce `StoryGenre` rozdzielone przecinkiem.
    var storyGenresRaw: String = ""
    /// `StoryNarrationStyle.rawValue` albo puste.
    var storyNarrationRaw: String = ""

    // Rdzeń projektowy — rysunek
    /// Surowce `DrawingTechnique` rozdzielone przecinkiem.
    var drawingTechniquesRaw: String = ""
    var drawingMainMotif: String = ""
    var drawingGoalEmotion: String = ""
    var drawingCompletionDefinition: String = ""
    /// Surowce `DrawingGenre` rozdzielone przecinkiem.
    var drawingGenresRaw: String = ""
    /// `DrawingScale.rawValue` albo puste.
    var drawingScaleRaw: String = ""

    // Rdzeń projektowy — aplikacja
    var appKeyFeatures: String = ""
    var appUserPath: String = ""
    var appMainProblem: String = ""
    /// `AppCategory.rawValue` albo puste.
    var appCategoryRaw: String = ""

    // Rdzeń projektowy — szkoła
    /// `SchoolProjectForm.rawValue` albo puste.
    var schoolFormRaw: String = ""
    /// `SchoolImplementationMode.rawValue` albo puste.
    var schoolImplementationRaw: String = ""
    var schoolSubject: String = ""
    var schoolProjectGoal: String = ""
    var schoolMainContent: String = ""
    var schoolCompletionCriteria: String = ""

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask]?

    @Relationship(deleteRule: .cascade, inverse: \ProjectBug.project)
    var bugs: [ProjectBug]?

    @Relationship(deleteRule: .cascade, inverse: \ProjectContextFile.project)
    var contextFiles: [ProjectContextFile]?

    @Relationship(deleteRule: .cascade, inverse: \ProjectFutureNote.project)
    var futureNotes: [ProjectFutureNote]?

    init(
        name: String,
        details: String,
        kind: ProjectKind,
        importance: Int,
        createdAt: Date = Date()
    ) {
        self.syncUUID = UUID()
        self.name = name
        self.details = details
        self.originalDetailsBackup = ""
        self.kindRaw = kind.rawValue
        self.importance = importance
        self.createdAt = createdAt
        self.updatedAt = Date()
        self.isPriorityHighlighted = false
        self.lastOpenedAt = Date(timeIntervalSince1970: 0)
        self.openCount = 0
        self.gameMechanics = ""
        self.gameGameloop = ""
        self.gamePlayerGoals = ""
        self.gameWinConditions = ""
        self.gameGenresRaw = ""
        self.gameStructureRaw = ""
        self.storyTheme = ""
        self.storyTypicalAction = ""
        self.storyHeroGoal = ""
        self.storyFinale = ""
        self.storyGenresRaw = ""
        self.storyNarrationRaw = ""
        self.drawingTechniquesRaw = ""
        self.drawingMainMotif = ""
        self.drawingGoalEmotion = ""
        self.drawingCompletionDefinition = ""
        self.drawingGenresRaw = ""
        self.drawingScaleRaw = ""
        self.appKeyFeatures = ""
        self.appUserPath = ""
        self.appMainProblem = ""
        self.appCategoryRaw = ""
        self.schoolFormRaw = ""
        self.schoolImplementationRaw = ""
        self.schoolSubject = ""
        self.schoolProjectGoal = ""
        self.schoolMainContent = ""
        self.schoolCompletionCriteria = ""
        self.tasks = []
        self.bugs = []
        self.contextFiles = []
        self.futureNotes = []
    }

    var kind: ProjectKind {
        ProjectKind(rawValue: kindRaw) ?? .game
    }

    var taskList: [ProjectTask] {
        tasks ?? []
    }

    var bugList: [ProjectBug] {
        bugs ?? []
    }

    var contextFileList: [ProjectContextFile] {
        (contextFiles ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var futureNoteList: [ProjectFutureNote] {
        (futureNotes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var hasOriginalDetailsBackup: Bool {
        !originalDetailsBackup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var gameGenres: Set<GameGenre> {
        get {
            Set(
                gameGenresRaw
                    .split(separator: ",")
                    .compactMap { GameGenre(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        set {
            gameGenresRaw = GameGenre.allCases
                .filter { newValue.contains($0) }
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    var gameStructure: GameStructure? {
        get { GameStructure(rawValue: gameStructureRaw) }
        set { gameStructureRaw = newValue?.rawValue ?? "" }
    }

    var storyGenres: Set<StoryGenre> {
        get {
            Set(
                storyGenresRaw
                    .split(separator: ",")
                    .compactMap { StoryGenre(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        set {
            storyGenresRaw = StoryGenre.allCases
                .filter { newValue.contains($0) }
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    var storyNarration: StoryNarrationStyle? {
        get { StoryNarrationStyle(rawValue: storyNarrationRaw) }
        set { storyNarrationRaw = newValue?.rawValue ?? "" }
    }

    var drawingTechniques: Set<DrawingTechnique> {
        get {
            Set(
                drawingTechniquesRaw
                    .split(separator: ",")
                    .compactMap { DrawingTechnique(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        set {
            drawingTechniquesRaw = DrawingTechnique.allCases
                .filter { newValue.contains($0) }
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    var drawingGenres: Set<DrawingGenre> {
        get {
            Set(
                drawingGenresRaw
                    .split(separator: ",")
                    .compactMap { DrawingGenre(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            )
        }
        set {
            drawingGenresRaw = DrawingGenre.allCases
                .filter { newValue.contains($0) }
                .map(\.rawValue)
                .joined(separator: ",")
        }
    }

    var drawingScale: DrawingScale? {
        get { DrawingScale(rawValue: drawingScaleRaw) }
        set { drawingScaleRaw = newValue?.rawValue ?? "" }
    }

    var hasGameCoreContent: Bool {
        !gameMechanics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !gameGameloop.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !gamePlayerGoals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !gameWinConditions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !gameGenres.isEmpty
            || gameStructure != nil
    }

    var hasStoryCoreContent: Bool {
        !storyTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !storyTypicalAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !storyHeroGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !storyFinale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !storyGenres.isEmpty
            || storyNarration != nil
    }

    var hasDrawingCoreContent: Bool {
        !drawingTechniques.isEmpty
            || !drawingMainMotif.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !drawingGoalEmotion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !drawingCompletionDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !drawingGenres.isEmpty
            || drawingScale != nil
    }

    var appCategory: AppCategory? {
        get { AppCategory(rawValue: appCategoryRaw) }
        set { appCategoryRaw = newValue?.rawValue ?? "" }
    }

    var hasAppCoreContent: Bool {
        !appKeyFeatures.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !appUserPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !appMainProblem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || appCategory != nil
    }

    var schoolForm: SchoolProjectForm? {
        get { SchoolProjectForm(rawValue: schoolFormRaw) }
        set { schoolFormRaw = newValue?.rawValue ?? "" }
    }

    var schoolImplementation: SchoolImplementationMode? {
        get { SchoolImplementationMode(rawValue: schoolImplementationRaw) }
        set { schoolImplementationRaw = newValue?.rawValue ?? "" }
    }

    var hasSchoolCoreContent: Bool {
        schoolForm != nil
            || schoolImplementation != nil
            || !schoolSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !schoolProjectGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !schoolMainContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !schoolCompletionCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Typy z dedykowanym Rdzeniem Projektowym.
    var supportsProjectCore: Bool {
        kind == .game || kind == .story || kind == .drawing || kind == .app || kind == .school
    }

    var hasProjectCoreContent: Bool {
        switch kind {
        case .game: hasGameCoreContent
        case .story: hasStoryCoreContent
        case .drawing: hasDrawingCoreContent
        case .app: hasAppCoreContent
        case .school: hasSchoolCoreContent
        }
    }

    /// Nazwa / etykieta bez treści (np. „.”, „…”, „a”, „test”).
    static func isMeaninglessLabel(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if Set(trimmed).count == 1 { return true }

        let alnum = trimmed.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        if alnum.count < 2 { return true }

        let folded = String(alnum)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let placeholders: Set<String> = [
            "test", "asdf", "xxx", "xyz", "qwer", "projekt", "project", "nowy", "new", "tmp", "temp"
        ]
        return placeholders.contains(folded)
    }

    /// Opis z realną treścią (nie kropka / krótki bełkot).
    var hasMeaningfulDescription: Bool {
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !Self.isMeaninglessLabel(trimmed) else { return false }
        let alnumCount = trimmed.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count
        return alnumCount >= 12
    }

    var hasMeaningfulName: Bool {
        !Self.isMeaninglessLabel(name)
    }

    /// Zadania / błędy / notatki / pliki z realną treścią.
    var hasMeaningfulWorkArtifacts: Bool {
        let hasTask = taskList.contains {
            !Self.isMeaninglessLabel($0.name)
                || $0.details.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
        }
        let hasBug = bugList.contains { !Self.isMeaninglessLabel($0.title) }
        let hasNote = futureNoteList.contains {
            $0.text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12
        }
        let hasFile = !contextFileList.isEmpty
        return hasTask || hasBug || hasNote || hasFile
    }

    /// Czy da się interpretować PLAN projektu (opis lub rdzeń) — bez strzelania z pustki.
    var canInterpretProjectPlan: Bool {
        if hasMeaningfulDescription { return true }
        if supportsProjectCore && hasProjectCoreContent { return true }
        return false
    }

    /// „Zaproponuj zadania”: tylko gdy AI zna detale projektu (opis LUB niepusty rdzeń).
    var canProposeProjectWorkTasks: Bool { canInterpretProjectPlan }

    var proposeTasksInsufficientMessageShort: String {
        let english = AppLanguage.stored.isEnglish
        if supportsProjectCore {
            return english
                ? "Not enough project details — add a concrete description or fill Project Core before proposing tasks."
                : "Za mało detali projektu — uzupełnij konkretny opis albo Rdzeń Projektowy, zanim zaproponuję zadania."
        }
        return english
            ? "Not enough project details — add a concrete description before proposing tasks."
            : "Za mało detali projektu — uzupełnij konkretny opis, zanim zaproponuję zadania."
    }

    /// Markdown: za mało danych, bez halucynacji.
    var insufficientProjectPlanMessageMarkdown: String {
        let english = AppLanguage.stored.isEnglish
        let coreHintEN: String = {
            switch kind {
            case .game:
                return "- Filled **Project Core** (mechanics, loop, goals…)\n"
            case .story:
                return "- Filled **Project Core** (theme, typical action, hero goal, finale…)\n"
            case .drawing:
                return "- Filled **Project Core** (technique, motif, goal/emotion, completion…)\n"
            case .app:
                return "- Filled **Project Core** (key features, user path, main problem…)\n"
            case .school:
                return "- Filled **Project Core** (form, goal, main content, subject, work mode…)\n"
            }
        }()
        let coreHintPL: String = {
            switch kind {
            case .game:
                return "- Wypełniony **Rdzeń Projektowy** (mechaniki, pętla, cele…)\n"
            case .story:
                return "- Wypełniony **Rdzeń Projektowy** (motyw, typowa akcja, cel bohatera, finał…)\n"
            case .drawing:
                return "- Wypełniony **Rdzeń Projektowy** (technika, motyw, cel/emocja, definicja ukończenia…)\n"
            case .app:
                return "- Wypełniony **Rdzeń Projektowy** (kluczowe funkcjonalności, ścieżka użytkownika, główny problem…)\n"
            case .school:
                return "- Wypełniony **Rdzeń Projektowy** (forma, cel, główna zawartość, przedmiot, sposób realizacji…)\n"
            }
        }()
        let coreMention = supportsProjectCore
        if english {
            return """
            ## Not enough information
            I don’t have enough real project data to interpret the plan safely \
            (vague/empty name, description, and\(coreMention ? " project core" : "")).

            ## What to add
            - A clear **project name**
            - A concrete **description** of what you’re building
            \(coreHintEN)\
            - Optionally: tasks, bugs, future notes, or context files

            I won’t invent a random plan from empty fields.
            """
        }
        return """
        ## Za mało informacji
        Nie mam wystarczająco konkretnych danych, żeby bezpiecznie zinterpretować plan projektu \
        (niejasna/pusta nazwa, opis\(coreMention ? " i rdzeń" : "")).

        ## Co uzupełnić
        - Jasną **nazwę projektu**
        - Konkretny **opis**, nad czym pracujesz
        \(coreHintPL)\
        - Opcjonalnie: zadania, błędy, notatki przyszłości lub pliki kontekstowe

        Nie będę strzelał losową odpowiedzią z pustych pól.
        """
    }

    var insufficientProjectPlanMessageShort: String {
        let english = AppLanguage.stored.isEnglish
        return english
            ? "Not enough project information — add a clear description\(supportsProjectCore ? " and Project Core" : "") before using this AI action."
            : "Za mało informacji o projekcie — uzupełnij konkretny opis\(supportsProjectCore ? " i Rdzeń Projektowy" : ""), zanim użyjesz tej akcji AI."
    }

    /// Opis + (dla gry/opowiadania) rdzeń — wymagane przed „Oceń projekt”.
    var meetsEvaluateProjectBasics: Bool {
        guard hasMeaningfulDescription else { return false }
        if supportsProjectCore {
            return hasProjectCoreContent
        }
        return true
    }

    /// Komunikat braków (PL/EN) — bez zależności od L10n z targetu aplikacji.
    var evaluateProjectBasicsMissingMessage: String {
        let english = AppLanguage.stored.isEnglish
        let hasDetails = hasMeaningfulDescription
        let needsCore = supportsProjectCore && !hasProjectCoreContent
        switch (hasDetails, needsCore) {
        case (false, true):
            return english
                ? "To evaluate the project, fill in a concrete description and Project Core."
                : "Aby ocenić projekt, uzupełnij konkretny opis i Rdzeń Projektowy."
        case (false, false):
            return english
                ? "To evaluate the project, fill in a concrete project description (not just “.” or a blank)."
                : "Aby ocenić projekt, uzupełnij konkretny opis projektu (nie tylko „.” ani pustkę)."
        case (true, true):
            return english
                ? "To evaluate the project, fill in the Project Core."
                : "Aby ocenić projekt, uzupełnij Rdzeń Projektowy."
        case (true, false):
            return ""
        }
    }

    func touch() {
        updatedAt = Date()
    }

    /// Wejście w projekt — osobna metryka aktywności (nie zmienia `updatedAt`).
    func recordOpen() {
        lastOpenedAt = Date()
        openCount = max(0, openCount) + 1
    }
}
