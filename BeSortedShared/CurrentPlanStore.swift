//
//  CurrentPlanStore.swift
//  BeSortedShared
//

import Foundation
import SwiftData

enum CurrentPlanStore {
    static let minActiveTasksLimit = 1
    static let maxActiveTasksLimit = 10
    static let defaultMaxActiveTasks = 7

    private static let maxActiveTasksKey = "besorted.currentPlan.maxActiveTasks"

    /// Limit aktywnych zadań w Aktualnym Planie (1…10).
    static var maxActiveTasks: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: maxActiveTasksKey) as? Int
            let value = stored ?? defaultMaxActiveTasks
            return clampedMax(value)
        }
        set {
            UserDefaults.standard.set(clampedMax(newValue), forKey: maxActiveTasksKey)
        }
    }

    static func clampedMax(_ value: Int) -> Int {
        min(maxActiveTasksLimit, max(minActiveTasksLimit, value))
    }

    static func activePlanCount(in context: ModelContext) -> Int {
        activePlanTasks(in: context).count
    }

    static func freeSlots(in context: ModelContext) -> Int {
        max(0, maxActiveTasks - activePlanCount(in: context))
    }

    static func activePlanTasks(in context: ModelContext) -> [ProjectTask] {
        let descriptor = FetchDescriptor<ProjectTask>(
            predicate: #Predicate { task in
                task.isInCurrentPlan && !task.isCompleted
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func prioritize(_ task: ProjectTask, in context: ModelContext) {
        guard !task.isCompleted else { return }
        if task.isInCurrentPlan { return }

        if activePlanCount(in: context) < maxActiveTasks {
            task.isInCurrentPlan = true
            task.planQueuedAt = nil
        } else if task.planQueuedAt == nil {
            task.planQueuedAt = Date()
        }

        task.touch()
        persistAndSync(context, mutatedTask: task)
    }

    static func complete(_ task: ProjectTask, in context: ModelContext) {
        task.isCompleted = true
        task.isInCurrentPlan = false
        task.planQueuedAt = nil
        task.touch()
        promoteQueuedTasks(in: context)
        persistAndSync(context, mutatedTask: task)
    }

    static func removeFromPlan(_ task: ProjectTask, in context: ModelContext) {
        task.isInCurrentPlan = false
        task.planQueuedAt = nil
        task.touch()
        promoteQueuedTasks(in: context)
        persistAndSync(context, mutatedTask: task)
    }

    static func promoteQueuedTasks(in context: ModelContext) {
        var freeSlots = maxActiveTasks - activePlanCount(in: context)
        guard freeSlots > 0 else { return }

        let descriptor = FetchDescriptor<ProjectTask>(
            predicate: #Predicate { task in
                !task.isCompleted && !task.isInCurrentPlan && task.planQueuedAt != nil
            },
            sortBy: [SortDescriptor(\.planQueuedAt, order: .forward)]
        )

        let queued = (try? context.fetch(descriptor)) ?? []
        for task in queued {
            guard freeSlots > 0 else { break }
            task.isInCurrentPlan = true
            task.planQueuedAt = nil
            task.touch()
            freeSlots -= 1
        }
    }

    static func nextBugTitle(for project: Project) -> String {
        "Błąd \(project.bugList.count + 1)"
    }

    static func persistAndSync(_ context: ModelContext, mutatedTask: ProjectTask? = nil, mutatedBug: ProjectBug? = nil) {
        try? context.save()
        Task { @MainActor in
            #if os(watchOS)
            if let mutatedTask {
                PhoneWatchSyncService.shared.pushTaskMutation(mutatedTask)
            }
            if let mutatedBug {
                PhoneWatchSyncService.shared.pushBugUpsert(mutatedBug)
            }
            // Pełny snapshot jako zabezpieczenie spójności.
            PhoneWatchSyncService.shared.pushSnapshotNow()
            #else
            PhoneWatchSyncService.shared.pushSnapshotNow()
            #endif
        }
    }
}
