//
//  BeSortedApp.swift
//  BeSorted
//
//  Created by Michał Wołtosz on 11/09/2026.
//

import SwiftUI
import SwiftData

@main
struct BeSortedApp: App {
    @State private var sharedModelContainer: ModelContainer
    @State private var appearance = AppAppearance()
    @State private var smartChrome = SmartChrome()
    @State private var showSplash = true
    @State private var showAccountGate = SynclyCloudAccount.shared.needsSignInGate
    @State private var lastStorageSignature: String?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = SharedModelContainer.make()
        _sharedModelContainer = State(initialValue: container)
        // Sygnatura = czy CloudKit MA być użyty (SIWA + iCloud available).
        // Nie bierzemy snapshotu po `make()` — inaczej po odświeżeniu iCloud
        // signature zostawała „cloud-unavailable” i kontener się nie przebudowywał.
        _lastStorageSignature = State(
            initialValue: SharedModelContainer.shouldUseCloudKit ? "cloud" : "local"
        )
        PhoneWatchSyncService.shared.start(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(appearance)
                    .environment(smartChrome)
                    .opacity(showSplash || showAccountGate ? 0 : 1)
                    .allowsHitTesting(!showSplash && !showAccountGate)

                if showAccountGate && !showSplash {
                    // Pierwsze uruchomienie: okienko logowania albo „Pomiń”.
                    // Decyzja zapisuje się na stałe, więc bramka nie wraca przy
                    // kolejnych wejściach — logowanie jest też w Ustawieniach.
                    SynclyAccountGateView { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            showAccountGate = false
                        }
                    }
                    .environment(appearance)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.96))
                                .combined(with: .offset(y: 18)),
                            removal: .opacity.combined(with: .scale(scale: 1.02))
                        )
                    )
                    .zIndex(40)
                }

                if showSplash {
                    SynclySplashView {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                            showSplash = false
                        }
                    }
                    .environment(appearance)
                    .transition(.opacity)
                    .zIndex(50)
                }
            }
            .preferredColorScheme(appearance.preferredScheme)
            .onAppear {
                PhoneWatchSyncService.shared.pushSnapshotNow()
                Task {
                    await SynclyCloudAccount.shared.validateExistingCredential()
                    // Najpierw status iCloud (bez UI) — dopiero to może przełączyć
                    // magazyn na CloudKit. Otwarcie CloudKit bez konta iCloud
                    // pokazywało „Sign in to Apple Account” przy każdym starcie.
                    await SynclyCloudAccount.shared.refreshICloudStatus()
                    // Bramka tylko przy pierwszym wejściu. Po SIWA / „Pomiń”
                    // `decided` blokuje powrót — nie otwieramy jej ponownie.
                    if SynclyCloudAccount.shared.needsSignInGate, !showSplash, !showAccountGate {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                            showAccountGate = true
                        }
                    }
                    // Migracja lokalnych projektów do CloudKit musi próbować przy
                    // KAŻDYM starcie. Wcześniej działała wyłącznie przy logowaniu,
                    // więc jedno nieudane logowanie zostawiało projekty na dysku
                    // na stałe — w sklepie, którego aplikacja już nie otwiera.
                    await runPostSignInSyncIfNeeded(container: sharedModelContainer)

                    // StoreKit: jedna cicha rekonsyliacja. Agresywny retry /
                    // AppStore.sync() przy starcie wywoływał systemowe logowanie
                    // Apple Account w kółko. Pełny sync zostaje przy „Przywróć zakupy”.
                    await SmartAssistantStore.shared.syncEntitlementsFromStoreKitQuietly()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .synclyStorageModeDidChange)) { _ in
                rebuildModelContainerIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                // Powrót do aplikacji: ciche odświeżenie (bez AppStore.sync).
                guard phase == .active else { return }
                Task { @MainActor in
                    await SmartAssistantStore.shared.syncEntitlementsFromStoreKitQuietly()
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func rebuildModelContainerIfNeeded() {
        // Zmiana trybu magazynu przychodzi jako `.synclyStorageModeDidChange`
        // z `completeSignIn` / `signOut`. Straik pilnuje, żeby na jednym pliku
        // CloudKit nie powstał drugi `ModelContainer` (dwie stosy SwiftData +
        // CloudKit na jednym SQLite) — a to wyzwalalo błąd otwarcia kontenera,
        // na który `SharedModelContainer.makeLocal` odpowiadał skasowaniem danych.
        let signature = storageSignature
        guard signature != lastStorageSignature else { return }
        lastStorageSignature = signature

        let container = SharedModelContainer.make()
        sharedModelContainer = container
        PhoneWatchSyncService.shared.start(container: container)
        PhoneWatchSyncService.shared.pushSnapshotNow()
        Task {
            await runPostSignInSyncIfNeeded(container: container)
        }
    }

    /// Jednoznaczna sygnatura trybu magazynu — zmiana wymaga nowego kontenera.
    private var storageSignature: String {
        SharedModelContainer.shouldUseCloudKit ? "cloud" : "local"
    }

    /// Po zalogowaniu / przebudowie kontenera: jednorazowa migracja lokalnych
    /// projektów do CloudKit. Migracja wymaga konta, więc — w przeciwieństwie do
    /// synchronizacji uprawnień StoreKit — tylko tutaj pilnujemy logowania.
    @MainActor
    private func runPostSignInSyncIfNeeded(container: ModelContainer) async {
        let account = SynclyCloudAccount.shared
        guard account.isSignedIn, account.isCloudSyncActive else { return }
        guard let userID = account.appleUserID else { return }

        _ = await SynclyCloudMigration.migrateLocalProjectsToCloud(
            userID: userID,
            cloudContainer: container
        )
    }
}
