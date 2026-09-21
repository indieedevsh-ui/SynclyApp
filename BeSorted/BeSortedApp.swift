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

    init() {
        let container = SharedModelContainer.make()
        _sharedModelContainer = State(initialValue: container)
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
                    SynclyAccountGateView { signedIn in
                        if signedIn {
                            rebuildModelContainerIfNeeded()
                        }
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
                    await SynclyCloudAccount.shared.refreshICloudStatus()
                    if SynclyCloudAccount.shared.needsSignInGate {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                            showAccountGate = true
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .synclyStorageModeDidChange)) { _ in
                rebuildModelContainerIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .synclyDidSignOut)) { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    showAccountGate = true
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func rebuildModelContainerIfNeeded() {
        let container = SharedModelContainer.make()
        sharedModelContainer = container
        PhoneWatchSyncService.shared.start(container: container)
        PhoneWatchSyncService.shared.pushSnapshotNow()
        Task {
            await runPostSignInSyncIfNeeded(container: container)
        }
    }

    /// Po zalogowaniu / przebudowie kontenera: jednorazowa migracja lokalnych
    /// projektów do CloudKit oraz uzupełnienie uprawnień StoreKit z Apple ID.
    @MainActor
    private func runPostSignInSyncIfNeeded(container: ModelContainer) async {
        let account = SynclyCloudAccount.shared
        guard account.isSignedIn, account.isCloudSyncActive else { return }
        guard let userID = account.appleUserID else { return }

        _ = await SynclyCloudMigration.migrateLocalProjectsToCloud(
            userID: userID,
            cloudContainer: container
        )
        await SmartAssistantStore.shared.syncEntitlementsFromStoreKit(replaceLocal: false)
    }
}
