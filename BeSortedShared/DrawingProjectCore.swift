//
//  DrawingProjectCore.swift
//  BeSortedShared
//

import Foundation

/// Technika / narzędzia (wielokrotny wybór).
enum DrawingTechnique: String, CaseIterable, Identifiable {
    case pencilSketch
    case watercolor
    case lineart
    case digitalPainting
    case pastels

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pencilSketch: "Szkic ołówkiem"
        case .watercolor: "Akwarele"
        case .lineart: "Lineart"
        case .digitalPainting: "Digital painting"
        case .pastels: "Pastele"
        }
    }
}

/// Gatunek rysunku (wielokrotny wybór).
enum DrawingGenre: String, CaseIterable, Identifiable {
    case mangaAnime
    case realism
    case cartoon
    case comic
    case conceptArt
    case minimalism

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mangaAnime: "Manga/Anime"
        case .realism: "Realizm"
        case .cartoon: "Kreskówka"
        case .comic: "Komiksowy"
        case .conceptArt: "Koncept Art"
        case .minimalism: "Minimalizm"
        }
    }
}

/// Skala i przestrzeń (jednokrotny wybór).
enum DrawingScale: String, CaseIterable, Identifiable {
    case singleFocus
    case largeScene

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleFocus: "Jedna postać / proste tło"
        case .largeScene: "Rozbudowana scena"
        }
    }

    var detail: String {
        switch self {
        case .singleFocus:
            "Skupienie na jednej postaci lub elemencie na prostym tle"
        case .largeScene:
            "Wielka, detaliczna scena z wieloma postaciami / elementami"
        }
    }
}
