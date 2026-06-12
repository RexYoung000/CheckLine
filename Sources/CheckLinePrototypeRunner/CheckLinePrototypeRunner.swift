import SwiftUI

#if canImport(CheckLinePrototype)
import CheckLinePrototype
#endif

@main
struct CheckLinePrototypeRunner: App {
    var body: some Scene {
        WindowGroup {
            CheckLinePrototypeView()
        }
    }
}
