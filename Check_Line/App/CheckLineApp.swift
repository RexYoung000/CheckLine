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

    init() {
        if DesignPreviewData.isEnabled {
            do {
                container = try CheckLinePersistence.makeContainer(inMemory: true)
                try DesignPreviewData.populate(container.mainContext)
            } catch {
                preconditionFailure("Unable to create the isolated design preview.")
            }
        } else {
            container = CheckLinePersistence.makeAppContainer()
        }
    }

    var body: some Scene {
        WindowGroup {
            CheckLineRootView()
        }
        .modelContainer(container)
    }
}
