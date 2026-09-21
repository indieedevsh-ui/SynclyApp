//
//  AppLanguage.swift
//  BeSortedShared
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case polish
    case english

    var id: String { rawValue }

    static let userDefaultsKey = "besorted.language"

    /// Aktualny język UI (synchronizowany z ustawieniami aplikacji).
    static var stored: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? AppLanguage.polish.rawValue
            return AppLanguage(rawValue: raw) ?? .polish
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }

    var settingsTitle: String {
        switch self {
        case .polish: "Polski"
        case .english: "English"
        }
    }

    var isEnglish: Bool { self == .english }
}
