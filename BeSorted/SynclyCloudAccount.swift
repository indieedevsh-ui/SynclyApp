//
//  SynclyCloudAccount.swift
//  BeSorted
//
//  Sign in with Apple + status konta iCloud (CloudKit) — sync projektów między urządzeniami.
//

import AuthenticationServices
import CloudKit
import Foundation
import Observation
import UIKit

extension Notification.Name {
    /// ModelContainer trzeba przebudować (CloudKit ↔ lokalny).
    static let synclyStorageModeDidChange = Notification.Name("syncly.storageModeDidChange")
}

@MainActor
@Observable
final class SynclyCloudAccount {
    static let shared = SynclyCloudAccount()

    enum Keys {
        static let completed = "syncly.icloudGate.completed"
        static let skipped = "syncly.icloudGate.skipped"
        static let localOnly = "syncly.icloudGate.localOnly"
        static let appleUserID = "syncly.icloudGate.appleUserID"
        static let displayName = "syncly.icloudGate.displayName"
        static let decided = "syncly.icloudGate.decided"
        /// Cache `CKAccountStatus == .available` — SharedModelContainer czyta ten
        /// klucz synchronicznie, żeby nie otwierać CloudKit bez konta iCloud.
        static let iCloudAvailable = "syncly.icloudGate.iCloudAvailable"
    }

    /// Użytkownik już raz podjął decyzję (zalogował się albo pominął) — bramka
    /// nie wraca nawet po wylogowaniu i kolejnym uruchomieniu aplikacji.
    private var didDecideAboutSignIn: Bool {
        if isSignedIn || didSkipSignIn { return true }
        return UserDefaults.standard.bool(forKey: Keys.decided)
    }

    /// Pierwsze uruchomienie: brak logowania i braku decyzji → pokaż okienko
    /// logowania albo „Pomiń”. Po decyzji bramka nie wraca — logowanie jest
    /// wtedy wyłącznie w Ustawieniach (kafelek „Konto Apple”).
    var needsSignInGate: Bool {
        !isSignedIn && !didDecideAboutSignIn
    }

    var isSignedIn: Bool {
        UserDefaults.standard.bool(forKey: Keys.completed)
            && UserDefaults.standard.string(forKey: Keys.appleUserID) != nil
    }

    var didSkipSignIn: Bool {
        UserDefaults.standard.bool(forKey: Keys.skipped)
    }

    /// Zapis tylko lokalny (pominięte logowanie albo brak sesji Apple).
    var usesLocalOnlyStorage: Bool {
        !isSignedIn || UserDefaults.standard.bool(forKey: Keys.localOnly)
    }

    /// Zakupy Smart Assistant wymagają zalogowanego konta Apple.
    var canPurchaseSmartAssistant: Bool {
        isSignedIn
    }

    var appleUserID: String? {
        UserDefaults.standard.string(forKey: Keys.appleUserID)
    }

    var displayName: String? {
        UserDefaults.standard.string(forKey: Keys.displayName)
    }

    var iCloudStatus: CKAccountStatus = .couldNotDetermine
    var statusMessage: String?
    var isRefreshing = false
    /// Inkrementowane przy zmianie sesji — odświeża widoki Observation.
    private(set) var authGeneration = 0

    var isICloudAvailable: Bool {
        iCloudStatus == .available
    }

    /// Czy synchronizacja przez iCloud faktycznie działa — konto Apple + kontener CloudKit wystartował.
    var isCloudSyncActive: Bool {
        !usesLocalOnlyStorage && SharedModelContainer.cloudKitStatusSnapshot.isUsingCloudKit
    }

    private init() {}

    private func noteAuthChange() {
        authGeneration += 1
    }

    func refreshICloudStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let previousAvailable = UserDefaults.standard.bool(forKey: Keys.iCloudAvailable)
        do {
            // `accountStatus()` NIE pokazuje systemowego logowania — w przeciwieństwie
            // do otwarcia prywatnej bazy CloudKit przez ModelContainer.
            let status = try await CKContainer(identifier: SharedModelContainer.cloudKitContainerID)
                .accountStatus()
            iCloudStatus = status
            statusMessage = nil
        } catch {
            iCloudStatus = .couldNotDetermine
            statusMessage = error.localizedDescription
        }

        let nowAvailable = iCloudStatus == .available
        UserDefaults.standard.set(nowAvailable, forKey: Keys.iCloudAvailable)

        // Przełącz magazyn dopiero gdy iCloud faktycznie jest (albo gdy znika) —
        // nigdy na samym SIWA, bo to odpalało „Sign in to Apple Account” przy starcie.
        let wantsCloud = isSignedIn && !UserDefaults.standard.bool(forKey: Keys.localOnly)
        if wantsCloud, previousAvailable != nowAvailable {
            NotificationCenter.default.post(name: .synclyStorageModeDidChange, object: nil)
        }
    }

    func completeSignIn(userID: String, fullName: PersonNameComponents?) {
        UserDefaults.standard.set(userID, forKey: Keys.appleUserID)
        if let fullName {
            let formatter = PersonNameComponentsFormatter()
            let name = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                UserDefaults.standard.set(name, forKey: Keys.displayName)
            }
        }
        UserDefaults.standard.set(true, forKey: Keys.completed)
        UserDefaults.standard.set(false, forKey: Keys.skipped)
        UserDefaults.standard.set(false, forKey: Keys.localOnly)
        UserDefaults.standard.set(true, forKey: Keys.decided)
        noteAuthChange()

        // NIE przebudowujemy kontenera tutaj. CloudKit włączamy dopiero po
        // `refreshICloudStatus()`, gdy status == .available — inaczej start
        // aplikacji pyta o Apple Account przy każdym uruchomieniu.
    }

    /// Pomiń logowanie — tylko lokalny zapis, zakupy Smart Assistant zablokowane.
    func skipSignIn() {
        let wasCloud = SharedModelContainer.shouldUseCloudKit
        UserDefaults.standard.set(true, forKey: Keys.skipped)
        UserDefaults.standard.set(true, forKey: Keys.localOnly)
        UserDefaults.standard.set(false, forKey: Keys.completed)
        UserDefaults.standard.set(true, forKey: Keys.decided)
        // Nie usuwamy appleUserID jeśli kiedyś było — ale po skip nie ma sesji.
        UserDefaults.standard.removeObject(forKey: Keys.appleUserID)
        UserDefaults.standard.removeObject(forKey: Keys.displayName)
        noteAuthChange()
        if wasCloud {
            NotificationCenter.default.post(name: .synclyStorageModeDidChange, object: nil)
        }
    }

    /// Wylogowanie — czyści sesję. Aplikacja działa dalej z zapisem lokalnym,
    /// a ponowne logowanie jest w Ustawieniach (kafelek „Konto Apple”).
    /// Bramka logowania NIE wraca: decyzja o wejściu do aplikacji już zapadła.
    func signOut() {
        let wasCloud = SharedModelContainer.shouldUseCloudKit

        UserDefaults.standard.set(false, forKey: Keys.completed)
        UserDefaults.standard.set(false, forKey: Keys.skipped)
        UserDefaults.standard.set(true, forKey: Keys.localOnly)
        UserDefaults.standard.set(true, forKey: Keys.decided)
        UserDefaults.standard.removeObject(forKey: Keys.appleUserID)
        UserDefaults.standard.removeObject(forKey: Keys.displayName)
        noteAuthChange()

        if wasCloud {
            NotificationCenter.default.post(name: .synclyStorageModeDidChange, object: nil)
        }
    }

    /// Ponowne sprawdzenie credentiali Sign in with Apple (po reinstalacji / nowym urządzeniu).
    func validateExistingCredential() async {
        guard let userID = appleUserID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userID)
            switch state {
            case .authorized:
                break
            case .revoked, .notFound:
                let wasCloud = !usesLocalOnlyStorage
                UserDefaults.standard.set(false, forKey: Keys.completed)
                UserDefaults.standard.removeObject(forKey: Keys.appleUserID)
                UserDefaults.standard.set(true, forKey: Keys.localOnly)
                // Sesja istniała, więc decyzja o wejściu już zapadła — cofnięcie
                // uwierzytelnienia przez Apple nie może odtworzyć bramki.
                UserDefaults.standard.set(true, forKey: Keys.decided)
                noteAuthChange()
                if wasCloud {
                    NotificationCenter.default.post(name: .synclyStorageModeDidChange, object: nil)
                }
            default:
                break
            }
        } catch {
            // Brak sieci / błąd — nie wylogowuj lokalnie.
        }
    }

    func openSystemSettingsForICloud() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    var iCloudStatusLabel: String {
        if usesLocalOnlyStorage && !isSignedIn {
            return "Zapis lokalny — projekty nie synchronizują się przez iCloud.".l10n
        }

        // Uczciwa informacja, gdy CloudKit nie wystartował: konto jest, ale sync nie działa.
        let cloud = SharedModelContainer.cloudKitStatusSnapshot
        if !usesLocalOnlyStorage && isSignedIn && cloud.attempted && cloud.isFallbackToLocal {
            if iCloudStatus == .available {
                return "iCloud jest dostępny, ale synchronizacja projektów jest wyłączona — dane są tylko na tym urządzeniu (skonfiguruj kontener CloudKit).".l10n
            }
            return "CloudKit niedostępny — projekty są zapisywane tylko na tym urządzeniu.".l10n
        }

        switch iCloudStatus {
        case .available:
            return "iCloud gotowy — projekty synchronizują się między urządzeniami.".l10n
        case .noAccount:
            return "Brak konta iCloud na tym urządzeniu. Zaloguj się w Ustawieniach → Apple ID.".l10n
        case .restricted:
            return "iCloud jest ograniczony na tym urządzeniu.".l10n
        case .couldNotDetermine:
            return "Nie udało się sprawdzić statusu iCloud. Sprawdź sieć i spróbuj ponownie.".l10n
        case .temporarilyUnavailable:
            return "iCloud chwilowo niedostępny. Spróbuj ponownie za chwilę.".l10n
        @unknown default:
            return "Nieznany status iCloud.".l10n
        }
    }

    var smartAssistantPurchaseBlockedMessage: String {
        "Zaloguj się kontem Apple, aby kupić Smart Assistant.".l10n
    }
}
