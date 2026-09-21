//
//  StoryProjectCore.swift
//  BeSortedShared
//

import Foundation

/// Gatunki opowiadania — jak gry, ale Strategiczna → Brutalna + Bajka.
enum StoryGenre: String, CaseIterable, Identifiable {
    case adventure
    case horror
    case psychological
    case pastoral
    case brutal
    case fairyTale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adventure: "Przygodowa"
        case .horror: "Horror"
        case .psychological: "Psychologiczna"
        case .pastoral: "Sielankowa"
        case .brutal: "Brutalna"
        case .fairyTale: "Bajka"
        }
    }
}

/// Sposób opowiadania (jednokrotny wybór).
enum StoryNarrationStyle: String, CaseIterable, Identifiable {
    case heroPerspective
    case narrator
    case chaotic
    case linear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heroPerspective: "Z perspektywy bohatera"
        case .narrator: "Narrator"
        case .chaotic: "Chaotyczna"
        case .linear: "Liniowa"
        }
    }
}
