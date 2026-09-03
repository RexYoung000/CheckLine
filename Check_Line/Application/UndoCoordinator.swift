import Foundation

nonisolated struct UndoToken: Equatable, Sendable {
    var snapshot: Ledger
}

nonisolated enum UndoCoordinator {
    static func undo(ledger _: Ledger, token: UndoToken) -> Ledger {
        token.snapshot
    }
}
