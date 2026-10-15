//
//  SynclyCloudMigration.swift
//  BeSorted
//
//  Jednorazowa migracja lokalnych projektów do kontenera CloudKit po zalogowaniu
//  kontem Apple (iCloud). Kopiuje wszystkie dane projektu wraz z relacjami,
//  pomijając wpisy, które już istnieją w chmurze (deduplikacja po `syncUUID`).
//

import Foundation
import SwiftData

/// Kopiuje lokalne projekty (store offline) do kontenera CloudKit.
@MainActor
enum SynclyCloudMigration {
    /// Nazwy lokalnych store'ów do przeniesienia (główny + starsza wersja).
    private static let localStoreCandidates = [
        "besorted-v12-local.store",
        "besorted-v12.store",
    ]

    private static func migrationKey(userID: String) -> String {
        "syncly.cloudMigration.didMigrate.\(userID)"
    }

    static func hasMigrated(userID: String) -> Bool {
        UserDefaults.standard.bool(forKey: migrationKey(userID: userID))
    }

    /// Migruje lokalne projekty do CloudKit, jeśli jeszcze nie zrobiono tego dla tego konta.
    /// - Returns: liczba skopiowanych projektów; `nil`, gdy nic nie należało robić.
    static func migrateLocalProjectsToCloud(
        userID: String,
        cloudContainer: ModelContainer
    ) async -> Int? {
        guard !hasMigrated(userID: userID) else { return nil }

        // Migruj tylko, gdy CloudKit faktycznie wystartował (inaczej edytowalibyśmy
        // ten sam plik, na którym działa fallback — i tak nie ma czego syncować).
        guard SharedModelContainer.cloudKitStatusSnapshot.isUsingCloudKit else { return nil }

        var existingCloudUUIDs = Set(
            (try? cloudContainer.mainContext.fetch(FetchDescriptor<Project>()))?.map(\.syncUUID) ?? []
        )
        var copied = 0
        /// Ilość store'ów, których nie dało się otworzyć (plik zajęty przez
        /// poprzedni kontener, uszkodzony SQLite). To NIE jest „brak danych”.
        var unreadableStores = 0

        for storeName in localStoreCandidates {
            let url = SharedModelContainer.localStoreURL(storeName: storeName)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            let config = ModelConfiguration(schema: SharedModelContainer.modelSchema, url: url)
            let localContainer: ModelContainer
            do {
                localContainer = try ModelContainer(
                    for: SharedModelContainer.modelSchema,
                    configurations: [config]
                )
            } catch {
                unreadableStores += 1
                continue
            }

            let localContext = localContainer.mainContext
            localContext.autosaveEnabled = false
            let projects = (try? localContext.fetch(FetchDescriptor<Project>())) ?? []
            guard !projects.isEmpty else { continue }

            for project in projects {
                guard !existingCloudUUIDs.contains(project.syncUUID) else { continue }
                let copy = makeCloudCopy(of: project)
                cloudContainer.mainContext.insert(copy)
                existingCloudUUIDs.insert(project.syncUUID)
                copied += 1
            }
        }

        guard copied > 0 else {
            // Nie oznaczaj migracji jako zrobionej, jeśli któreś store'y były
            // nieczytelne — wtedy projekty zostałyby na dysku na zawsze, w sklepie,
            // którego aplikacja już nie otwiera. Niech migracja spróbuje jeszcze raz
            // przy kolejnym uruchomieniu.
            guard unreadableStores == 0 else { return nil }
            UserDefaults.standard.set(true, forKey: migrationKey(userID: userID))
            return nil
        }

        do {
            try cloudContainer.mainContext.save()
        } catch {
            // CloudKit może nie zdążyć wystartować mirrora w tle — nie blokuj.
            return copied
        }
        UserDefaults.standard.set(true, forKey: migrationKey(userID: userID))
        return copied
    }

    // MARK: - Kopiowanie

    private static func makeCloudCopy(of project: Project) -> Project {
        let copy = Project(
            name: project.name,
            details: project.details,
            kind: project.kind,
            importance: project.importance,
            createdAt: project.createdAt
        )
        copy.syncUUID = project.syncUUID
        copy.originalDetailsBackup = project.originalDetailsBackup
        copy.updatedAt = project.updatedAt
        copy.isPriorityHighlighted = project.isPriorityHighlighted
        copy.lastOpenedAt = project.lastOpenedAt
        copy.openCount = project.openCount

        copy.gameMechanics = project.gameMechanics
        copy.gameGameloop = project.gameGameloop
        copy.gamePlayerGoals = project.gamePlayerGoals
        copy.gameWinConditions = project.gameWinConditions
        copy.gameGenresRaw = project.gameGenresRaw
        copy.gameStructureRaw = project.gameStructureRaw

        copy.storyTheme = project.storyTheme
        copy.storyTypicalAction = project.storyTypicalAction
        copy.storyHeroGoal = project.storyHeroGoal
        copy.storyFinale = project.storyFinale
        copy.storyGenresRaw = project.storyGenresRaw
        copy.storyNarrationRaw = project.storyNarrationRaw

        copy.drawingTechniquesRaw = project.drawingTechniquesRaw
        copy.drawingMainMotif = project.drawingMainMotif
        copy.drawingGoalEmotion = project.drawingGoalEmotion
        copy.drawingCompletionDefinition = project.drawingCompletionDefinition
        copy.drawingGenresRaw = project.drawingGenresRaw
        copy.drawingScaleRaw = project.drawingScaleRaw

        copy.appKeyFeatures = project.appKeyFeatures
        copy.appUserPath = project.appUserPath
        copy.appMainProblem = project.appMainProblem
        copy.appCategoryRaw = project.appCategoryRaw

        copy.schoolFormRaw = project.schoolFormRaw
        copy.schoolImplementationRaw = project.schoolImplementationRaw
        copy.schoolSubject = project.schoolSubject
        copy.schoolProjectGoal = project.schoolProjectGoal
        copy.schoolMainContent = project.schoolMainContent
        copy.schoolCompletionCriteria = project.schoolCompletionCriteria

        for task in project.taskList {
            let taskCopy = ProjectTask(
                name: task.name,
                details: task.details,
                kind: task.kind,
                importance: task.importance,
                project: copy,
                createdAt: task.createdAt
            )
            taskCopy.syncUUID = task.syncUUID
            taskCopy.updatedAt = task.updatedAt
            taskCopy.isInCurrentPlan = task.isInCurrentPlan
            taskCopy.planQueuedAt = task.planQueuedAt
            taskCopy.isCompleted = task.isCompleted
            copy.tasks?.append(taskCopy)
        }

        for bug in project.bugList {
            let bugCopy = ProjectBug(
                title: bug.title,
                details: bug.details,
                severity: bug.severity,
                project: copy,
                relatedTaskName: bug.relatedTaskName,
                createdAt: bug.createdAt
            )
            bugCopy.syncUUID = bug.syncUUID
            bugCopy.updatedAt = bug.updatedAt
            copy.bugs?.append(bugCopy)
        }

        for file in project.contextFileList {
            let fileCopy = ProjectContextFile(
                fileName: file.fileName,
                contentText: file.contentText,
                byteSize: file.byteSize,
                project: copy,
                createdAt: file.createdAt
            )
            fileCopy.syncUUID = file.syncUUID
            fileCopy.updatedAt = file.updatedAt
            copy.contextFiles?.append(fileCopy)
        }

        for note in project.futureNoteList {
            let noteCopy = ProjectFutureNote(
                text: note.text,
                project: copy,
                createdAt: note.createdAt
            )
            noteCopy.syncUUID = note.syncUUID
            noteCopy.updatedAt = note.updatedAt
            copy.futureNotes?.append(noteCopy)
        }

        return copy
    }
}