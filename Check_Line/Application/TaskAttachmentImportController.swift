import Foundation
import Observation

nonisolated struct TaskIdentity: Equatable, Sendable {
    let key: String
    let entityID: UUID
}

@MainActor
struct TaskAttachmentImportItem: Identifiable {
    enum State { case waiting, reading, added, failed }
    let id: UUID
    var state: State = .waiting
    let read: @MainActor () async throws -> Data
}

/// Photo selection handles live only for the lifetime of the visible task panel.
@MainActor
@Observable
final class TaskAttachmentImportController {
    private enum Owner: Equatable { case task(TaskIdentity), expense(UUID) }
    private(set) var items: [TaskAttachmentImportItem] = []
    private(set) var isReading = false
    private var owner: Owner?
    private var sessionID = UUID()
    @ObservationIgnored private var runTask: Task<Void, Never>?

    var failedCount: Int { items.filter { $0.state == .failed }.count }
    var addedCount: Int { items.filter { $0.state == .added }.count }
    var blocksSubmission: Bool { isReading || failedCount > 0 }

    func start(_ selections: [TaskAttachmentImportItem], workspace: CheckLineWorkspace, expenseID: UUID? = nil) {
        guard !selections.isEmpty else { return }
        cancel(workspace: workspace)
        items = selections
        owner = expenseID.map { .expense($0) } ?? .task(workspace.taskIdentity)
        run(workspace: workspace)
    }

    func retry(workspace: CheckLineWorkspace) {
        guard !isReading, let owner, isValid(owner, workspace: workspace) else { return }
        for index in items.indices where items[index].state == .failed { items[index].state = .waiting }
        run(workspace: workspace)
    }

    func removeFailures(workspace: CheckLineWorkspace) {
        guard !isReading else { return }
        items.removeAll { $0.state == .failed }
        updateSubmission(workspace: workspace)
    }

    func cancel(workspace: CheckLineWorkspace) {
        if case .task = owner { workspace.attachmentImportBlocksSubmission = false }
        runTask?.cancel()
        runTask = nil
        sessionID = UUID()
        isReading = false
        items = []
        owner = nil
    }

    func waitForCompletion() async { await runTask?.value }

    private func run(workspace: CheckLineWorkspace) {
        guard let owner, isValid(owner, workspace: workspace) else { cancel(workspace: workspace); return }
        let session = UUID()
        sessionID = session
        isReading = true
        updateSubmission(workspace: workspace)
        runTask = Task { [weak self] in
            guard let self else { return }
            for index in items.indices where items[index].state == .waiting {
                guard sessionID == session, !Task.isCancelled, isValid(owner, workspace: workspace) else { break }
                let item = items[index]
                items[index].state = .reading
                do {
                    let data = try await item.read()
                    guard sessionID == session, !Task.isCancelled, isValid(owner, workspace: workspace) else { break }
                    switch owner {
                    case .task(let identity): try workspace.addTaskAttachment(data, id: item.id, expectedTask: identity)
                    case .expense(let id): try workspace.attachmentStore.add(imageData: data, to: id, id: item.id)
                    }
                    items[index].state = .added
                } catch {
                    guard sessionID == session, !Task.isCancelled, isValid(owner, workspace: workspace) else { break }
                    items[index].state = .failed
                }
            }
            guard sessionID == session else { return }
            if !isValid(owner, workspace: workspace) { cancel(workspace: workspace); return }
            isReading = false
            updateSubmission(workspace: workspace)
        }
    }

    private func isValid(_ owner: Owner, workspace: CheckLineWorkspace) -> Bool {
        switch owner {
        case .task(let identity): identity == workspace.taskIdentity && workspace.taskDraft.committedEntityID == nil
        case .expense(let id): workspace.ledger.expenses[id] != nil
        }
    }

    private func updateSubmission(workspace: CheckLineWorkspace) {
        if case .task = owner { workspace.attachmentImportBlocksSubmission = blocksSubmission }
    }
}
