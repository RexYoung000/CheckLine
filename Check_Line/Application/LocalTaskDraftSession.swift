import Foundation
import Observation

/// A separate local scope for wish tasks; it never replaces the Agent's active draft.
@MainActor
@Observable
final class LocalTaskDraftSession {
    var draft: TaskDraft { didSet { if !isLoading && !loadFailed { save() } } }
    private(set) var loadFailed = false
    private(set) var saveFailed = false
    private let store: TaskDraftStore
    private let empty: TaskDraft
    @ObservationIgnored private var isLoading = true

    init(store: TaskDraftStore, kind: String, currency: String, wishID: UUID? = nil) {
        self.store = store
        let initial = TaskDraft(kind: kind, contextWishID: wishID, currency: currency)
        empty = initial
        draft = initial
        restore()
    }

    var canSubmit: Bool { !loadFailed && !saveFailed }

    func retry() {
        if loadFailed { restore() }
        else { save() }
    }

    func clear() throws {
        try store.remove(draft.key)
        isLoading = true
        var fresh = empty
        fresh.entityID = UUID()
        fresh.newPeriodID = UUID()
        draft = fresh
        isLoading = false
        loadFailed = false
        saveFailed = false
    }

    private func restore() {
        isLoading = true
        defer { isLoading = false }
        do {
            draft = try store.load(empty.key) ?? empty
            loadFailed = false; saveFailed = false
        } catch { loadFailed = true; saveFailed = true }
    }

    private func save() {
        do { try store.save(draft); saveFailed = false }
        catch { saveFailed = true }
    }
}
