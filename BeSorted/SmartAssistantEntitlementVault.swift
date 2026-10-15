//
//  SmartAssistantEntitlementVault.swift
//  BeSorted
//
//  Lustrzany zapis uprawnień zakupowych w Keychain.
//
//  Dlaczego to istnieje — gwarancja „zakupy nie giną":
//
//  `UserDefaults` i każdy lokalny plik znikają w momencie, gdy użytkownik
//  usunie aplikację (lub wyczyści jej dane). Keychain natomiast NIE jest
//  czyszczony przy odinstalacji — przeżywa ją, o ile:
//    • bundle ID i zespół (Team ID) się nie zmienią,
//    • użytkownik nie zrobi „Wymaż wszystkie treści i ustawienia”,
//    • urządzenie nie zostanie zresetowane do ustawień fabrycznych.
//
//  Dlatego źródłem prawdy pozostaje App Store (`Transaction.currentEntitlements`),
//  a ten plik jest jedynie szybkim lustrem, które pozwala pokazać zakupy
//  natychmiast po instalacji — także bez sieci i zanim StoreKit zdąży
//  odpowiedzieć. Lustro nigdy nie przyznaje uprawnień: zapisujemy wyłącznie
//  to, co potwierdził podpisany JWS ze StoreKit.
//
//  Celowo NIE synchronizujemy tego do iCloud Keychain (`ThisDeviceOnly`):
//    • chcemy, by drugie urządzenie dostało uprawnienia ze swojego App Store,
//      a nie z kopii lokalnej,
//    • `ThisDeviceOnly` nie tworzy dodatkowej kopii w chmurze.
//

import Foundation
import Security

/// Trwały (Keychain) zapis uprawnień Smart Assistant.
enum SmartAssistantEntitlementVault {
    private enum Key {
        static let service = "com.michaelproduct.syncly.smartAssistant.entitlements"
        static let ownedTiers = "ownedTiers"
        static let activeTier = "activeTier"
        /// Oryginalne productID potwierdzone przez App Store — do diagnostyki
        /// i przyszłego „Przywróć zakupy” bez aktywnej sesji sieciowej.
        static let productIDs = "productIDs"
    }

    // MARK: - Odczyt

    /// Zbiory odblokowanych tierów zapisane poza `UserDefaults`.
    static func ownedTiers() -> Set<String> {
        Set(readStringArray(Key.ownedTiers) ?? [])
    }

    /// Aktywny tier zapisany poza `UserDefaults`.
    static func activeTier() -> SmartAssistantTier? {
        guard let raw = readString(Key.activeTier) else { return nil }
        return SmartAssistantTier(rawValue: raw)
    }

    /// Product ID ostatnio potwierdzone przez App Store.
    static func productIDs() -> Set<String> {
        Set(readStringArray(Key.productIDs) ?? [])
    }

    /// Czy w Keychain jest jakikolwiek zapis uprawnień.
    static var hasCachedEntitlements: Bool {
        !ownedTiers().isEmpty || activeTier() != nil
    }

    // MARK: - Zapis

    static func save(ownedTiers: Set<String>, activeTier: SmartAssistantTier?) {
        let owned = Array(ownedTiers).sorted()
        if owned.isEmpty {
            remove(Key.ownedTiers)
        } else {
            write(owned, Key.ownedTiers)
        }

        if let activeTier {
            write(activeTier.rawValue, Key.activeTier)
        } else {
            remove(Key.activeTier)
        }
    }

    /// Zapisuje product ID potwierdzone przez App Store (niezależnie od tieru).
    static func remember(productIDs: Set<String>) {
        guard !productIDs.isEmpty else { return }
        write(Array(productIDs).sorted(), Key.productIDs)
    }

    // MARK: - Prywatne (Security framework)

    private static func readString(_ account: String) -> String? {
        readData(account).flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func readStringArray(_ account: String) -> [String]? {
        guard let raw = readData(account) else { return nil }
        return try? JSONDecoder().decode([String].self, from: raw)
    }

    private static func readData(_ account: String) -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func write(_ value: String, _ account: String) {
        write(Data(value.utf8), account)
    }

    private static func write(_ value: [String], _ account: String) {
        guard let encoded = try? JSONEncoder().encode(value) else { return }
        write(encoded, account)
    }

    private static func write(_ data: Data, _ account: String) {
        let query = baseQuery(account)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Przetrwa usunięcie aplikacji, ale tylko do odblokowania urządzenia.
            // Nie `WhenUnlocked`, bo entitlement sync startuje z splashu.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        switch SecItemUpdate(query as CFDictionary, attributes as CFDictionary) {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = query
            insert.merge(attributes) { current, _ in current }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            if addStatus != errSecSuccess {
                #if DEBUG
                print("[StoreKit] Keychain: SecItemAdd \(account) = \(addStatus) — lustro uprawnień nie zostało zapisane.")
                #endif
            }
        default:
            // Każdy inny błąd (brak Keychaina, brak uprawnień) też musi próbować
            // `insert` — wcześniej pomijaliśmy go, przez co lustro po cichu nigdy
            // nie powstawało, a na nim opierała się ochrona zakupów po reinstalacji.
            var insert = query
            insert.merge(attributes) { current, _ in current }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            #if DEBUG
            if addStatus == errSecDuplicateItem {
                SecItemDelete(query as CFDictionary)
                _ = SecItemAdd(insert as CFDictionary, nil)
            } else {
                print("[StoreKit] Keychain: zapis \(account) nieudany (\(addStatus)).")
            }
            #endif
        }
    }

    private static func remove(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Key.service,
            kSecAttrAccount as String: account
            // Bez kSecAttrAccessGroup — domyślna grupa = bundle ID aplikacji.
        ]
    }
}
