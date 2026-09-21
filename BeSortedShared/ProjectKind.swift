//
//  ProjectKind.swift
//  BeSortedShared
//

import Foundation

enum ProjectKind: String, CaseIterable, Identifiable {
    case game
    case story
    case drawing
    case app
    case school

    var id: String { rawValue }

    var title: String {
        switch (AppLanguage.stored, self) {
        case (.polish, .game): "Gra"
        case (.english, .game): "Game"
        case (.polish, .story): "Opowiadanie"
        case (.english, .story): "Story"
        case (.polish, .drawing): "Rysunek"
        case (.english, .drawing): "Drawing"
        case (.polish, .app): "Aplikacja"
        case (.english, .app): "App"
        case (.polish, .school): "Szkoła"
        case (.english, .school): "School"
        }
    }

    var systemImage: String {
        switch self {
        case .game: "gamecontroller.fill"
        case .story: "book.fill"
        case .drawing: "paintbrush.pointed.fill"
        case .app: "app.fill"
        case .school: "graduationcap.fill"
        }
    }
}
