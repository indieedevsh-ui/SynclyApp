//
//  GameProjectCore.swift
//  BeSortedShared
//

import Foundation

enum GameGenre: String, CaseIterable, Identifiable {
    case adventure
    case horror
    case psychological
    case pastoral
    case strategic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adventure: "Przygodowa"
        case .horror: "Horror"
        case .psychological: "Psychologiczna"
        case .pastoral: "Sielankowa"
        case .strategic: "Strategiczna"
        }
    }
}

enum GameStructure: String, CaseIterable, Identifiable {
    case open
    case linear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: "Otwarta"
        case .linear: "Liniowa"
        }
    }
}
