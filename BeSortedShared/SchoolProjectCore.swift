//
//  SchoolProjectCore.swift
//  BeSortedShared
//

import Foundation

/// Forma szkolnego projektu (jak ma wyglądać oddanie).
enum SchoolProjectForm: String, CaseIterable, Identifiable {
    case presentation
    case experiment
    case performance
    case speech

    var id: String { rawValue }

    var title: String {
        switch self {
        case .presentation: "Prezentacja"
        case .experiment: "Eksperyment"
        case .performance: "Przedstawienie"
        case .speech: "Przemowa"
        }
    }
}

/// Sposób realizacji szkolnego projektu (grupowo / indywidualnie).
enum SchoolImplementationMode: String, CaseIterable, Identifiable {
    case group
    case individual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .group: "Grupowy"
        case .individual: "Indywidualny"
        }
    }
}