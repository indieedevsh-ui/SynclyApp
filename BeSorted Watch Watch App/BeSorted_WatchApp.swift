//
//  BeSorted_WatchApp.swift
//  BeSorted Watch Watch App
//
//  Created by Michał Wołtosz on 11/09/2026.
//

import SwiftUI
import SwiftData

@main
struct BeSorted_Watch_Watch_AppApp: App {
    private let sharedModelContainer: ModelContainer

    init() {
        let container = SharedModelContainer.make()
        self.sharedModelContainer = container
        PhoneWatchSyncService.shared.start(container: container)
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .onAppear {
                    PhoneWatchSyncService.shared.pushSnapshotNow()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
