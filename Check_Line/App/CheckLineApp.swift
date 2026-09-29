//
//  CheckLineApp.swift
//  CheckLine
//
//  Created by Rex Young on 2026/7/19.
//

import SwiftData
import SwiftUI

@main
struct CheckLineApp: App {
    private let container: ModelContainer
    private let storageUnavailable: Bool

    init() {
        if DesignPreviewData.isEnabled {
            do {
                container = try CheckLinePersistence.makeContainer(inMemory: true)
                try DesignPreviewData.populate(container.mainContext)
                storageUnavailable = false
            } catch {
                preconditionFailure("Unable to create the isolated design preview.")
            }
        } else {
            do {
                container = try CheckLinePersistence.makeAppContainer()
                storageUnavailable = false
            } catch {
                guard let temporary = try? CheckLinePersistence.makeContainer(inMemory: true) else {
                    preconditionFailure("CheckLine local ledger container is unavailable.")
                }
                container = temporary
                storageUnavailable = true
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if storageUnavailable {
                StorageUnavailableView()
            } else {
                CheckLineRootView()
            }
        }
        .modelContainer(container)
    }
}

struct StorageUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "storage.unavailable.title"),
            systemImage: "externaldrive.badge.exclamationmark",
            description: Text(String(localized: "storage.unavailable.message"))
        )
    }
}
