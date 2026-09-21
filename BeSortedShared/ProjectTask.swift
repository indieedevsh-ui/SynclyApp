//
//  ProjectTask.swift
//  BeSortedShared
//

import Foundation
import SwiftData

enum TaskKind: String, CaseIterable, Identifiable {
    case mechanics
    case materials
    case fix
    case other
    case sketch
    case polish
    case element
    case character
    case scene
    case schoolTask
    case learning

    var id: String { rawValue }

    var title: String {
        switch (AppLanguage.stored, self) {
        case (.polish, .mechanics): "Mechanika"
        case (.english, .mechanics): "Mechanics"
        case (.polish, .materials): "Materiały"
        case (.english, .materials): "Materials"
        case (.polish, .fix): "Poprawka"
        case (.english, .fix): "Fix"
        case (.polish, .other): "Inne"
        case (.english, .other): "Other"
        case (.polish, .sketch): "Szkic"
        case (.english, .sketch): "Sketch"
        case (.polish, .polish): "Dopracowanie"
        case (.english, .polish): "Polish"
        case (.polish, .element): "Element"
        case (.english, .element): "Element"
        case (.polish, .character): "Postać"
        case (.english, .character): "Character"
        case (.polish, .scene): "Scena"
        case (.english, .scene): "Scene"
        case (.polish, .schoolTask): "Zadanie"
        case (.english, .schoolTask): "Assignment"
        case (.polish, .learning): "Nauka"
        case (.english, .learning): "Learning"
        }
    }

    var systemImage: String {
        switch self {
        case .mechanics: "gearshape.2.fill"
        case .materials: "cube.fill"
        case .fix: "wrench.and.screwdriver.fill"
        case .other: "ellipsis.circle.fill"
        case .sketch: "pencil.tip"
        case .polish: "paintbrush.pointed.fill"
        case .element: "square.on.circle"
        case .character: "person.fill"
        case .scene: "text.book.closed.fill"
        case .schoolTask: "doc.text.fill"
        case .learning: "book.fill"
        }
    }

    static func kinds(for projectKind: ProjectKind) -> [TaskKind] {
        switch projectKind {
        case .game:
            [.mechanics, .materials, .fix, .other]
        case .drawing:
            [.sketch, .polish, .element, .other]
        case .story:
            [.character, .scene, .fix, .other]
        case .app:
            [.fix, .polish, .materials, .other]
        case .school:
            [.schoolTask, .learning, .fix, .other]
        }
    }
}

@Model
final class ProjectTask {
    var syncUUID: UUID = UUID()
    var name: String = ""
    var details: String = ""
    var kindRaw: String = "other"
    var importance: Int = 3
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isInCurrentPlan: Bool = false
    var planQueuedAt: Date?
    var isCompleted: Bool = false

    var project: Project?

    init(
        name: String,
        details: String,
        kind: TaskKind,
        importance: Int,
        project: Project,
        createdAt: Date = Date()
    ) {
        self.syncUUID = UUID()
        self.name = name
        self.details = details
        self.kindRaw = kind.rawValue
        self.importance = importance
        self.createdAt = createdAt
        self.updatedAt = Date()
        self.project = project
        self.isInCurrentPlan = false
        self.planQueuedAt = nil
        self.isCompleted = false
    }

    var kind: TaskKind {
        TaskKind(rawValue: kindRaw) ?? .other
    }

    func touch() {
        updatedAt = Date()
    }
}
