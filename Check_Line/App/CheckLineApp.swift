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
        container = CheckLinePersistence.makeAppContainer()
    }

    var body: some Scene {
        WindowGroup {
            CheckLineHomeView()
        }
        .modelContainer(container)
    }
}
