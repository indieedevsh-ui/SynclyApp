//
//  PhoneWatchSync.swift
//  BeSortedShared
//
//  Ekosystem sync:
//  - iPhone = źródło prawdy dla projektów/zadań/błędów (pełny snapshot)
//  - Watch wysyła tylko mutacje: stan zadania + nowy błąd
//  - LWW po updatedAt przy pełnym snapshocie
//

import Foundation
import SwiftData
import WatchConnectivity

struct SyncSnapshot: Codable {
    var projects: [ProjectDTO]
    var tasks: [TaskDTO]
    var bugs: [BugDTO]
    var updatedAt: Date
}

struct ProjectDTO: Codable {
    var syncUUID: UUID
    var name: String
    var details: String
    var kindRaw: String
    var importance: Int
    var createdAt: Date
    var updatedAt: Date
    var isPriorityHighlighted: Bool
    var originalDetailsBackup: String?
    var lastOpenedAt: Date?
    var openCount: Int?

    enum CodingKeys: String, CodingKey {
        case syncUUID, name, details, kindRaw, importance, createdAt, updatedAt, isPriorityHighlighted, originalDetailsBackup
        case lastOpenedAt, openCount
    }

    init(
        syncUUID: UUID,
        name: String,
        details: String,
        kindRaw: String,
        importance: Int,
        createdAt: Date,
        updatedAt: Date,
        isPriorityHighlighted: Bool,
        originalDetailsBackup: String? = nil,
        lastOpenedAt: Date? = nil,
        openCount: Int? = nil
    ) {
        self.syncUUID = syncUUID
        self.name = name
        self.details = details
        self.kindRaw = kindRaw
        self.importance = importance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPriorityHighlighted = isPriorityHighlighted
        self.originalDetailsBackup = originalDetailsBackup
        self.lastOpenedAt = lastOpenedAt
        self.openCount = openCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        syncUUID = try container.decode(UUID.self, forKey: .syncUUID)
        name = try container.decode(String.self, forKey: .name)
        details = try container.decode(String.self, forKey: .details)
        kindRaw = try container.decode(String.self, forKey: .kindRaw)
        importance = try container.decode(Int.self, forKey: .importance)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isPriorityHighlighted = try container.decode(Bool.self, forKey: .isPriorityHighlighted)
        originalDetailsBackup = try container.decodeIfPresent(String.self, forKey: .originalDetailsBackup)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        openCount = try container.decodeIfPresent(Int.self, forKey: .openCount)
    }
}

struct TaskDTO: Codable {
    var syncUUID: UUID
    var projectUUID: UUID
    var name: String
    var details: String
    var kindRaw: String
    var importance: Int
    var createdAt: Date
    var updatedAt: Date
    var isInCurrentPlan: Bool
    var planQueuedAt: Date?
    var isCompleted: Bool
}

struct BugDTO: Codable {
    var syncUUID: UUID
    var projectUUID: UUID
    var title: String
    var details: String
    var severity: Int
    var createdAt: Date
    var updatedAt: Date
    var relatedTaskName: String
}

enum SyncPayloadKey {
    static let type = "type"
    static let source = "source"
    static let sourcePhone = "phone"
    static let sourceWatch = "watch"

    static let typeFullSnapshot = "fullSnapshot"
    static let typeTaskMutation = "taskMutation"
    static let typeBugUpsert = "bugUpsert"
    static let typeTaskDeleted = "taskDeleted"
    static let typeProjectDeleted = "projectDeleted"

    static let snapshot = "snapshot"
    static let task = "task"
    static let bug = "bug"
    static let uuid = "uuid"
}

@MainActor
final class PhoneWatchSyncService: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSyncService()

    private var container: ModelContainer?
    private var isApplyingRemote = false
    private var pushWorkItem: DispatchWorkItem?

    #if os(iOS)
    private let localSource = SyncPayloadKey.sourcePhone
    #else
    private let localSource = SyncPayloadKey.sourceWatch
    #endif

    func start(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.pushFullSnapshot()
        }
    }

    /// Wywołuj po każdej lokalnej zmianie.
    func pushSnapshotNow() {
        pushWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pushAfterLocalChange()
        }
        pushWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func pushAfterLocalChange() {
        guard !isApplyingRemote else { return }

        #if os(iOS)
        // iPhone zawsze wysyła pełny stan katalogu + planu.
        pushFullSnapshot()
        #else
        // Watch: pełny snapshot też (żeby iPhone dostał plan/błędy),
        // ale iPhone NIE kasuje rekordów na podstawie Watcha.
        pushFullSnapshot(watchMode: true)
        #endif
    }

    private func pushFullSnapshot(watchMode: Bool = false) {
        guard let container else { return }
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else { return }

        do {
            let context = container.mainContext
            try? context.save()
            let snapshot = try buildSnapshot(from: context)
            let data = try JSONEncoder().encode(snapshot)

            var payload: [String: Any] = [
                SyncPayloadKey.type: SyncPayloadKey.typeFullSnapshot,
                SyncPayloadKey.source: localSource,
                SyncPayloadKey.snapshot: data
            ]

            deliver(payload, via: session)
        } catch {
            // best-effort
        }
    }

    /// Watch → iPhone: natychmiastowa mutacja jednego zadania.
    func pushTaskMutation(_ task: ProjectTask) {
        guard let projectUUID = task.project?.syncUUID else {
            pushSnapshotNow()
            return
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let dto = TaskDTO(
            syncUUID: task.syncUUID,
            projectUUID: projectUUID,
            name: task.name,
            details: task.details,
            kindRaw: task.kindRaw,
            importance: task.importance,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            isInCurrentPlan: task.isInCurrentPlan,
            planQueuedAt: task.planQueuedAt,
            isCompleted: task.isCompleted
        )

        guard let data = try? JSONEncoder().encode(dto) else { return }
        let payload: [String: Any] = [
            SyncPayloadKey.type: SyncPayloadKey.typeTaskMutation,
            SyncPayloadKey.source: localSource,
            SyncPayloadKey.task: data
        ]
        deliver(payload, via: session)
    }

    func pushBugUpsert(_ bug: ProjectBug) {
        guard let projectUUID = bug.project?.syncUUID else {
            pushSnapshotNow()
            return
        }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let dto = BugDTO(
            syncUUID: bug.syncUUID,
            projectUUID: projectUUID,
            title: bug.title,
            details: bug.details,
            severity: bug.severity,
            createdAt: bug.createdAt,
            updatedAt: bug.updatedAt,
            relatedTaskName: bug.relatedTaskName
        )
        guard let data = try? JSONEncoder().encode(dto) else { return }
        let payload: [String: Any] = [
            SyncPayloadKey.type: SyncPayloadKey.typeBugUpsert,
            SyncPayloadKey.source: localSource,
            SyncPayloadKey.bug: data
        ]
        deliver(payload, via: session)
    }

    func pushTaskDeleted(syncUUID: UUID) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = [
            SyncPayloadKey.type: SyncPayloadKey.typeTaskDeleted,
            SyncPayloadKey.source: localSource,
            SyncPayloadKey.uuid: syncUUID.uuidString
        ]
        deliver(payload, via: session)
        // Dodatkowo pełny snapshot dla spójności katalogu.
        pushSnapshotNow()
    }

    func pushProjectDeleted(syncUUID: UUID) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = [
            SyncPayloadKey.type: SyncPayloadKey.typeProjectDeleted,
            SyncPayloadKey.source: localSource,
            SyncPayloadKey.uuid: syncUUID.uuidString
        ]
        deliver(payload, via: session)
        pushSnapshotNow()
    }

    private func deliver(_ payload: [String: Any], via session: WCSession) {
        // Najnowszy kontekst (nadpisuje poprzedni).
        try? session.updateApplicationContext(payload)

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { _ in
                session.transferUserInfo(payload)
            })
        } else {
            // Gdy counterpart nie jest aktywny — kolejka, ale tylko dla małych mutacji.
            // Dla fullSnapshot wolimy applicationContext (już ustawiony).
            if let type = payload[SyncPayloadKey.type] as? String,
               type != SyncPayloadKey.typeFullSnapshot {
                session.transferUserInfo(payload)
            }
        }
    }

    private func buildSnapshot(from context: ModelContext) throws -> SyncSnapshot {
        let projects = try context.fetch(FetchDescriptor<Project>())
        let tasks = try context.fetch(FetchDescriptor<ProjectTask>())
        let bugs = try context.fetch(FetchDescriptor<ProjectBug>())

        let maxEntityDate = [
            projects.map(\.updatedAt).max(),
            tasks.map(\.updatedAt).max(),
            bugs.map(\.updatedAt).max()
        ].compactMap { $0 }.max() ?? Date()

        return SyncSnapshot(
            projects: projects.map {
                ProjectDTO(
                    syncUUID: $0.syncUUID,
                    name: $0.name,
                    details: $0.details,
                    kindRaw: $0.kindRaw,
                    importance: $0.importance,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    isPriorityHighlighted: $0.isPriorityHighlighted,
                    originalDetailsBackup: $0.originalDetailsBackup.isEmpty ? nil : $0.originalDetailsBackup,
                    lastOpenedAt: $0.lastOpenedAt.timeIntervalSince1970 > 0 ? $0.lastOpenedAt : nil,
                    openCount: $0.openCount
                )
            },
            tasks: tasks.compactMap { task in
                guard let projectUUID = task.project?.syncUUID else { return nil }
                return TaskDTO(
                    syncUUID: task.syncUUID,
                    projectUUID: projectUUID,
                    name: task.name,
                    details: task.details,
                    kindRaw: task.kindRaw,
                    importance: task.importance,
                    createdAt: task.createdAt,
                    updatedAt: task.updatedAt,
                    isInCurrentPlan: task.isInCurrentPlan,
                    planQueuedAt: task.planQueuedAt,
                    isCompleted: task.isCompleted
                )
            },
            bugs: bugs.compactMap { bug in
                guard let projectUUID = bug.project?.syncUUID else { return nil }
                return BugDTO(
                    syncUUID: bug.syncUUID,
                    projectUUID: projectUUID,
                    title: bug.title,
                    details: bug.details,
                    severity: bug.severity,
                    createdAt: bug.createdAt,
                    updatedAt: bug.updatedAt,
                    relatedTaskName: bug.relatedTaskName
                )
            },
            updatedAt: max(maxEntityDate, Date())
        )
    }

    private func applyFullSnapshot(_ snapshot: SyncSnapshot, fromPhone: Bool) {
        guard let container else { return }

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let context = container.mainContext

        do {
            let existingProjects = try context.fetch(FetchDescriptor<Project>())
            let existingTasks = try context.fetch(FetchDescriptor<ProjectTask>())
            let existingBugs = try context.fetch(FetchDescriptor<ProjectBug>())

            var projectsByUUID: [UUID: Project] = [:]
            for project in existingProjects { projectsByUUID[project.syncUUID] = project }
            var tasksByUUID: [UUID: ProjectTask] = [:]
            for task in existingTasks { tasksByUUID[task.syncUUID] = task }
            var bugsByUUID: [UUID: ProjectBug] = [:]
            for bug in existingBugs { bugsByUUID[bug.syncUUID] = bug }

            let incomingProjectIDs = Set(snapshot.projects.map(\.syncUUID))
            let incomingTaskIDs = Set(snapshot.tasks.map(\.syncUUID))
            let incomingBugIDs = Set(snapshot.bugs.map(\.syncUUID))

            for dto in snapshot.projects {
                if let project = projectsByUUID[dto.syncUUID] {
                    guard dto.updatedAt >= project.updatedAt else { continue }
                    applyProject(dto, to: project)
                } else {
                    let project = Project(
                        name: dto.name,
                        details: dto.details,
                        kind: ProjectKind(rawValue: dto.kindRaw) ?? .game,
                        importance: dto.importance,
                        createdAt: dto.createdAt
                    )
                    project.syncUUID = dto.syncUUID
                    applyProject(dto, to: project)
                    context.insert(project)
                    projectsByUUID[dto.syncUUID] = project
                }
            }

            for dto in snapshot.tasks {
                guard let project = projectsByUUID[dto.projectUUID] else { continue }
                if let task = tasksByUUID[dto.syncUUID] {
                    guard dto.updatedAt >= task.updatedAt else { continue }
                    applyTask(dto, to: task, project: project)
                } else {
                    let task = ProjectTask(
                        name: dto.name,
                        details: dto.details,
                        kind: TaskKind(rawValue: dto.kindRaw) ?? .other,
                        importance: dto.importance,
                        project: project,
                        createdAt: dto.createdAt
                    )
                    task.syncUUID = dto.syncUUID
                    applyTask(dto, to: task, project: project)
                    context.insert(task)
                    tasksByUUID[dto.syncUUID] = task
                }
            }

            for dto in snapshot.bugs {
                guard let project = projectsByUUID[dto.projectUUID] else { continue }
                if let bug = bugsByUUID[dto.syncUUID] {
                    guard dto.updatedAt >= bug.updatedAt else { continue }
                    applyBug(dto, to: bug, project: project)
                } else {
                    let bug = ProjectBug(
                        title: dto.title,
                        details: dto.details,
                        severity: dto.severity,
                        project: project,
                        relatedTaskName: dto.relatedTaskName,
                        createdAt: dto.createdAt
                    )
                    bug.syncUUID = dto.syncUUID
                    applyBug(dto, to: bug, project: project)
                    context.insert(bug)
                    bugsByUUID[dto.syncUUID] = bug
                }
            }

            // Kasowanie tylko ze snapshotu iPhone'a (źródło prawdy katalogu).
            if fromPhone {
                for bug in existingBugs where !incomingBugIDs.contains(bug.syncUUID) {
                    if bug.updatedAt <= snapshot.updatedAt { context.delete(bug) }
                }
                for task in existingTasks where !incomingTaskIDs.contains(task.syncUUID) {
                    if task.updatedAt <= snapshot.updatedAt { context.delete(task) }
                }
                for project in existingProjects where !incomingProjectIDs.contains(project.syncUUID) {
                    if project.updatedAt <= snapshot.updatedAt { context.delete(project) }
                }
            }

            try context.save()
        } catch {
            // best-effort
        }
    }

    private func applyProject(_ dto: ProjectDTO, to project: Project) {
        project.name = dto.name
        project.details = dto.details
        project.kindRaw = dto.kindRaw
        project.importance = dto.importance
        project.createdAt = dto.createdAt
        project.updatedAt = dto.updatedAt
        project.isPriorityHighlighted = dto.isPriorityHighlighted
        if let backup = dto.originalDetailsBackup {
            project.originalDetailsBackup = backup
        }
        if let lastOpenedAt = dto.lastOpenedAt {
            project.lastOpenedAt = lastOpenedAt
        }
        if let openCount = dto.openCount {
            project.openCount = openCount
        }
    }

    private func applyTask(_ dto: TaskDTO, to task: ProjectTask, project: Project) {
        task.name = dto.name
        task.details = dto.details
        task.kindRaw = dto.kindRaw
        task.importance = dto.importance
        task.createdAt = dto.createdAt
        task.updatedAt = dto.updatedAt
        task.isInCurrentPlan = dto.isInCurrentPlan
        task.planQueuedAt = dto.planQueuedAt
        task.isCompleted = dto.isCompleted
        task.project = project
    }

    private func applyBug(_ dto: BugDTO, to bug: ProjectBug, project: Project) {
        bug.title = dto.title
        bug.details = dto.details
        bug.severity = dto.severity
        bug.createdAt = dto.createdAt
        bug.updatedAt = dto.updatedAt
        bug.relatedTaskName = dto.relatedTaskName
        bug.project = project
    }

    private func applyTaskMutation(_ dto: TaskDTO) {
        guard let container else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let context = container.mainContext
        do {
            let tasks = try context.fetch(FetchDescriptor<ProjectTask>())
            if let task = tasks.first(where: { $0.syncUUID == dto.syncUUID }) {
                if dto.updatedAt >= task.updatedAt {
                    let projects = try context.fetch(FetchDescriptor<Project>())
                    let project = projects.first(where: { $0.syncUUID == dto.projectUUID }) ?? task.project
                    if let project {
                        applyTask(dto, to: task, project: project)
                        try context.save()
                    }
                }
            } else {
                // Brak lokalnego zadania — dociągnij pełny stan z counterpartu nie jest możliwy;
                // poczekaj na fullSnapshot. Na iPhonie zwykle zadanie już istnieje.
            }
        } catch {}
    }

    private func applyBugUpsert(_ dto: BugDTO) {
        guard let container else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let context = container.mainContext
        do {
            let projects = try context.fetch(FetchDescriptor<Project>())
            guard let project = projects.first(where: { $0.syncUUID == dto.projectUUID }) else { return }

            let bugs = try context.fetch(FetchDescriptor<ProjectBug>())
            if let bug = bugs.first(where: { $0.syncUUID == dto.syncUUID }) {
                if dto.updatedAt >= bug.updatedAt {
                    applyBug(dto, to: bug, project: project)
                }
            } else {
                let bug = ProjectBug(
                    title: dto.title,
                    details: dto.details,
                    severity: dto.severity,
                    project: project,
                    relatedTaskName: dto.relatedTaskName,
                    createdAt: dto.createdAt
                )
                bug.syncUUID = dto.syncUUID
                bug.updatedAt = dto.updatedAt
                context.insert(bug)
            }
            try context.save()
        } catch {}
    }

    private func applyTaskDeleted(_ uuid: UUID) {
        guard let container else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let context = container.mainContext
        do {
            let tasks = try context.fetch(FetchDescriptor<ProjectTask>())
            if let task = tasks.first(where: { $0.syncUUID == uuid }) {
                context.delete(task)
                try context.save()
            }
        } catch {}
    }

    private func applyProjectDeleted(_ uuid: UUID) {
        guard let container else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let context = container.mainContext
        do {
            let projects = try context.fetch(FetchDescriptor<Project>())
            if let project = projects.first(where: { $0.syncUUID == uuid }) {
                context.delete(project)
                try context.save()
            }
        } catch {}
    }

    private func handleIncomingPayload(_ payload: [String: Any]) {
        let source = payload[SyncPayloadKey.source] as? String
        if source == localSource { return }

        guard let type = payload[SyncPayloadKey.type] as? String else { return }

        switch type {
        case SyncPayloadKey.typeFullSnapshot:
            guard let data = payload[SyncPayloadKey.snapshot] as? Data,
                  let snapshot = try? JSONDecoder().decode(SyncSnapshot.self, from: data)
            else { return }
            applyFullSnapshot(snapshot, fromPhone: source == SyncPayloadKey.sourcePhone)

        case SyncPayloadKey.typeTaskMutation:
            guard let data = payload[SyncPayloadKey.task] as? Data,
                  let dto = try? JSONDecoder().decode(TaskDTO.self, from: data)
            else { return }
            applyTaskMutation(dto)

        case SyncPayloadKey.typeBugUpsert:
            guard let data = payload[SyncPayloadKey.bug] as? Data,
                  let dto = try? JSONDecoder().decode(BugDTO.self, from: data)
            else { return }
            applyBugUpsert(dto)

        case SyncPayloadKey.typeTaskDeleted:
            guard let raw = payload[SyncPayloadKey.uuid] as? String,
                  let uuid = UUID(uuidString: raw)
            else { return }
            applyTaskDeleted(uuid)

        case SyncPayloadKey.typeProjectDeleted:
            guard let raw = payload[SyncPayloadKey.uuid] as? String,
                  let uuid = UUID(uuidString: raw)
            else { return }
            applyProjectDeleted(uuid)

        default:
            break
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                self.handleIncomingPayload(context)
            }
            #if os(iOS)
            self.pushFullSnapshot()
            #endif
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleIncomingPayload(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handleIncomingPayload(userInfo)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.handleIncomingPayload(applicationContext)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.pushFullSnapshot()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            if session.isReachable {
                self.pushFullSnapshot()
            }
        }
    }
    #endif
}
