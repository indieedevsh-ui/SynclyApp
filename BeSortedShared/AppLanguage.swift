//
//  AppLanguage.swift
//  BeSortedShared
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case polish
    case english

    var id: String { rawValue }

    nonisolated static let userDefaultsKey = "besorted.language"

    /// Aktualny język UI (synchronizowany z ustawieniami aplikacji).
    /// `nonisolated`: enum jest typem wartości, a `UserDefaults` jest thread-safe —
    /// nie ma tu stanu współdzielonego, więc izolacja aktora tylko przeszkadza
    /// czytelnikom spoza main actora (błąd w Swift 6).
    nonisolated static var stored: AppLanguage {
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

    nonisolated var isEnglish: Bool { self == .english }
}
