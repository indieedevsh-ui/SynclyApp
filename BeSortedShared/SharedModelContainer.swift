//
//  SharedModelContainer.swift
//  BeSortedShared
//

import Foundation
import SwiftData

/// Uczciwy status ostatniej próby utworzenia kontenera CloudKit.
/// Zamiast cichego fallbacku UI pokazuje, że iCloud nie jest aktywny.
struct CloudKitContainerStatus: Sendable {
    /// Czy w ogóle próbowano utworzyć kontener CloudKit (konto Apple + brak trybu lokalnego).
    var attempted = false
    /// Czy kontener faktycznie działa na CloudKit (projekty synchroniczne przez iCloud).
    var isUsingCloudKit = false
    /// Czy CloudKit się nie udał i spadliśmy na lokalny store.
    var isFallbackToLocal = false
    /// Surowe info o błędzie (do przetłumaczenia w warstwie UI, tam gdzie importowany jest CloudKit).
    var errorText: String?

    static let pristine = CloudKitContainerStatus()
}

enum SharedModelContainer {
    /// Identyfikator kontenera CloudKit (musi zgadzać się z entitlements).
    static let cloudKitContainerID = "iCloud.jujug.Syncly"

    // MARK: - Stan CloudKit (thread-safe, tylko do odczytu przez UI)

    private final class CloudKitStatusBox: @unchecked Sendable {
        let lock = NSLock()
        var status = CloudKitContainerStatus.pristine
    }

    private static let cloudKitStatusBox = CloudKitStatusBox()

    /// Zrzut statusu ostatniej próby budowy kontenera CloudKit.
    static var cloudKitStatusSnapshot: CloudKitContainerStatus {
        cloudKitStatusBox.lock.lock()
        defer { cloudKitStatusBox.lock.unlock() }
        return cloudKitStatusBox.status
    }

    private static func reportCloudKitStatus(_ status: CloudKitContainerStatus) {
        cloudKitStatusBox.lock.lock()
        cloudKitStatusBox.status = status
        cloudKitStatusBox.lock.unlock()
    }

    /// Klucze UserDefaults współdzielone z SynclyCloudAccount (iOS).
    private enum AccountKeys {
        static let completed = "syncly.icloudGate.completed"
        static let localOnly = "syncly.icloudGate.localOnly"
        static let appleUserID = "syncly.icloudGate.appleUserID"
        /// Ostatni znany `CKAccountStatus == .available` — bez tego `ModelContainer`
        /// z CloudKit przy starcie wywołuje systemowe „Sign in to Apple Account”
        /// w kółko (nawet gdy Sign in with Apple w aplikacji już przeszło).
        static let iCloudAvailable = "syncly.icloudGate.iCloudAvailable"
    }

    /// CloudKit tylko gdy: SIWA zalogowane, nie tryb lokalny, **i** iCloud
    /// faktycznie dostępny na urządzeniu. Samo SIWA nie wystarczy — bez konta
    /// iCloud / Media & Purchases kontener CloudKit przy każdym starcie pyta
    /// o Apple Account.
    static var shouldUseCloudKit: Bool {
        #if os(watchOS)
        return false
        #else
        let signedIn = UserDefaults.standard.bool(forKey: AccountKeys.completed)
            && UserDefaults.standard.string(forKey: AccountKeys.appleUserID) != nil
        let localOnly = UserDefaults.standard.bool(forKey: AccountKeys.localOnly)
        let iCloudAvailable = UserDefaults.standard.bool(forKey: AccountKeys.iCloudAvailable)
        return signedIn && !localOnly && iCloudAvailable
        #endif
    }

    static func make() -> ModelContainer {
        let schema = modelSchema

        #if os(watchOS)
        return makeLocal(schema: schema)
        #else
        if shouldUseCloudKit {
            return makeCloudKit(schema: schema)
        }
        return makeLocal(schema: schema, storeName: "besorted-v12-local.store")
        #endif
    }

    /// Wspólny schemat danych — musi być identyczny dla lokalnego i CloudKit store'a.
    static let modelSchema = Schema([
        Project.self,
        ProjectTask.self,
        ProjectBug.self,
        ProjectContextFile.self,
        ProjectFutureNote.self
    ])

    /// iPhone / iPad — SwiftData + prywatna baza CloudKit (sync między urządzeniami).
    private static func makeCloudKit(schema: Schema) -> ModelContainer {
        let cloudConfig = ModelConfiguration(
            "SynclyCloudKit",
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            reportCloudKitStatus(CloudKitContainerStatus(
                attempted: true,
                isUsingCloudKit: true,
                isFallbackToLocal: false,
                errorText: nil
            ))
            return container
        } catch {
            // Awaryjnie lokalny store (np. brak konta iCloud / nieutworzony kontener w portalu) —
            // app ma się uruchomić, ale klient widzi UCIWĄ informację, że sync nie działa.
            reportCloudKitStatus(CloudKitContainerStatus(
                attempted: true,
                isUsingCloudKit: false,
                isFallbackToLocal: true,
                errorText: error.localizedDescription
            ))
            return makeLocal(schema: schema, storeName: "besorted-v12-local.store")
        }
    }

    /// Pełna ścieżka lokalnego store'a SwiftData (do migracji lokalnych projektów → CloudKit).
    static func localStoreURL(storeName: String) -> URL {
        let storeDirectory = applicationSupportDirectory()
            .appendingPathComponent("BeSortedStores", isDirectory: true)
        return storeDirectory.appendingPathComponent(storeName)
    }

    private static func makeLocal(
        schema: Schema,
        storeName: String = "besorted-v12.store"
    ) -> ModelContainer {
        let storeDirectory = applicationSupportDirectory()
            .appendingPathComponent("BeSortedStores", isDirectory: true)
        let storeURL = localStoreURL(storeName: storeName)

        try? FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )

        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Uszkodzony lub zablokowany store. NIGDY nie kasujemy całego katalogu
            // `BeSortedStores` — obok leży `besorted-v12.store`, z którego migracja
            // do CloudKit (`SynclyCloudMigration`) czyta projekty użytkownika.
            // Odsuwamy wyłącznie pliki tego jednego store'a, żeby odblokować start.
            quarantineStoreFiles(at: storeURL, in: storeDirectory)

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [memory])
                } catch {
                    // Ostatnia deska ratunku: w pamięci RAM nie ma nic do utraty.
                    reportCloudKitStatus(CloudKitContainerStatus(
                        attempted: true,
                        isUsingCloudKit: false,
                        isFallbackToLocal: true,
                        errorText: error.localizedDescription
                    ))
                    fatalError("Could not create ModelContainer: \(error)")
                }
            }
        }
    }

    /// Przenosi pliki jednego store'a (`.store`, `-wal`, `-shm`) do podkatalogu
    /// `Uszkodzone`, zamiast je kasować. Dzięki temu dane da się odzyskać ręcznie,
    /// a katalog pozostaje nietknięty dla pozostałych store'ów.
    private static func quarantineStoreFiles(at storeURL: URL, in storeDirectory: URL) {
        let manager = FileManager.default
        let directory = storeURL.deletingLastPathComponent()

        // Pliki towarzyszące SQLite leżą OBOK store'a i mają dopisek `-wal`/`-shm`
        // dopisany do pełnej nazwy: `besorted-v12.store-wal`, nie `….store.store-wal`.
        let sidecars = ["-wal", "-shm"].map { suffix in
            directory.appendingPathComponent(storeURL.lastPathComponent + suffix)
        }
        let candidates = [storeURL] + sidecars

        let existing = candidates.filter { manager.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return }

        let quarantineDirectory = storeDirectory
            .appendingPathComponent("Uszkodzone", isDirectory: true)
            .appendingPathComponent(stamp(), isDirectory: true)
        try? manager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)

        for file in existing {
            let target = quarantineDirectory.appendingPathComponent(file.lastPathComponent)
            do {
                try manager.moveItem(at: file, to: target)
            } catch {
                // Nie udało się przenieść (np. brak miejsca) — kasujemy tylko ten
                // konkretny plik, nigdy całego katalogu.
                try? manager.removeItem(at: file)
            }
        }
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private static func applicationSupportDirectory() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        if let url = urls.first {
            return url
        }
        return FileManager.default.temporaryDirectory
    }
}
