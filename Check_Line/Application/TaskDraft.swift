import Foundation

/// User-authored task fields. No balances, impact quotes or conversation archive.
nonisolated struct TaskDraft: Codable, Equatable, Sendable {
    var kind: String = "record"
    var contextBudgetID: UUID?
    var contextPeriodID: UUID?
    var entityID = UUID()
    var newPeriodID = UUID()
    var committedEntityID: UUID?
    var mode = "form"
    var text = ""
    // Optional so drafts saved before conversational entry remain readable.
    var agentRequestText: String? = nil
    var pendingAgentField: String? = nil
    var name = ""
    var amount = ""
    var currency = "CNY"
    var repeating = true
    var merchant = ""
    var note = ""
    var occurredAt = Date()
    var attributionID = "unbudgeted"
    var explicitAttribution = false
    var formTouched = false
    var fieldsTouched = false
    var attachments: [TaskAttachment] = []

    var key: String { [kind, contextBudgetID?.uuidString ?? "global", contextPeriodID?.uuidString ?? "global"].joined(separator: "_") }
    var hasInput: Bool { fieldsTouched || !text.isEmpty || agentRequestText?.isEmpty == false || !name.isEmpty || !amount.isEmpty || !merchant.isEmpty || !note.isEmpty || !attachments.isEmpty || committedEntityID != nil }

    /// Only explicit parser fields replace user input; defaults never replace a chosen date.
    mutating func apply(_ candidate: AgentIntentCandidate) {
        if let value = candidate.amount { amount = value }
        if let value = candidate.currencyCode { currency = value }
        if let value = candidate.name { name = value }
        if let value = candidate.merchant { merchant = value }
        if let value = candidate.note { note = value }
        if let value = candidate.cycleType { repeating = value == "repeating" }
        if let value = candidate.periodID { attributionID = value; explicitAttribution = true }
        if let value = candidate.occurredAt, let date = ISO8601DateFormatter().date(from: value) { occurredAt = date }
    }
}

nonisolated struct TaskAttachment: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var data: Data
}

@MainActor
final class TaskDraftStore {
    private struct Envelope: Codable { var version = 2; var draft: TaskDraft }
    private struct Scope: Codable {
        var kind: String
        var budgetID: UUID?
        var periodID: UUID?
        var draft: TaskDraft { TaskDraft(kind: kind, contextBudgetID: budgetID, contextPeriodID: periodID) }
    }
    private let root: URL?
    private var memory: [String: TaskDraft] = [:]
    private var memoryScope: Scope?

    init(root: URL? = nil, inMemory: Bool = false) {
        self.root = inMemory ? nil : root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TaskDrafts", isDirectory: true)
    }

    func load(_ key: String) throws -> TaskDraft? {
        guard let root else { return memory[key] }
        let file = root.appendingPathComponent(key).appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: file))
        guard [1, 2].contains(envelope.version), envelope.draft.key == key else { throw CocoaError(.coderReadCorrupt) }
        var draft = envelope.draft
        if envelope.version == 2 {
            for index in draft.attachments.indices {
                draft.attachments[index].data = try Data(contentsOf: attachmentFile(root: root, key: key, id: draft.attachments[index].id))
            }
        }
        return draft
    }

    func save(_ draft: TaskDraft) throws {
        guard draft.hasInput else { try remove(draft.key); return }
        guard var root else {
            memory[draft.key] = draft
            if ["budget", "record"].contains(draft.kind) { memoryScope = Scope(kind: draft.kind, budgetID: draft.contextBudgetID, periodID: draft.contextPeriodID) }
            return
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        var metadata = draft
        let images = root.appendingPathComponent(draft.key, isDirectory: true)
        if !draft.attachments.isEmpty { try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true) }
        for index in metadata.attachments.indices {
            let attachment = draft.attachments[index]
            let file = attachmentFile(root: root, key: draft.key, id: attachment.id)
            if !FileManager.default.fileExists(atPath: file.path) {
                try attachment.data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
            // Field edits rewrite only the small metadata file, never the image bytes.
            metadata.attachments[index].data = Data()
        }
        try JSONEncoder().encode(Envelope(draft: metadata)).write(to: root.appendingPathComponent(draft.key).appendingPathExtension("json"), options: [.atomic, .completeFileProtectionUnlessOpen])
        let retained = Set(draft.attachments.map { $0.id.uuidString })
        for file in (try? FileManager.default.contentsOfDirectory(at: images, includingPropertiesForKeys: nil)) ?? [] {
            if !retained.contains(file.deletingPathExtension().lastPathComponent) { try FileManager.default.removeItem(at: file) }
        }
        if ["budget", "record"].contains(draft.kind) {
            let scope = Scope(kind: draft.kind, budgetID: draft.contextBudgetID, periodID: draft.contextPeriodID)
            try JSONEncoder().encode(scope).write(to: root.appendingPathComponent("recent-task.json"), options: [.atomic, .completeFileProtectionUnlessOpen])
        }
    }

    func remove(_ key: String) throws {
        guard let root else { memory[key] = nil; if memoryScope?.draft.key == key { memoryScope = nil }; return }
        let file = root.appendingPathComponent(key).appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        let images = root.appendingPathComponent(key, isDirectory: true)
        if FileManager.default.fileExists(atPath: images.path) { try FileManager.default.removeItem(at: images) }
        if (try? recentScope()?.key) == key { try clearRecentScope() }
    }

    func recentScope() throws -> TaskDraft? {
        guard let root else { return memoryScope?.draft }
        let file = root.appendingPathComponent("recent-task.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let scope = try JSONDecoder().decode(Scope.self, from: Data(contentsOf: file))
        guard ["budget", "record"].contains(scope.kind) else { throw CocoaError(.coderReadCorrupt) }
        return scope.draft
    }

    func clearRecentScope() throws {
        guard let root else { memoryScope = nil; return }
        let file = root.appendingPathComponent("recent-task.json")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    private func attachmentFile(root: URL, key: String, id: UUID) -> URL {
        root.appendingPathComponent(key, isDirectory: true).appendingPathComponent(id.uuidString).appendingPathExtension("jpg")
    }
}
