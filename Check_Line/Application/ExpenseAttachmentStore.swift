import Foundation
import ImageIO
import UIKit

struct ExpenseAttachment: Identifiable, Equatable {
    let id: UUID
    let url: URL
}

enum ExpenseAttachmentError: Error, Equatable {
    case unreadableImage
    case limitReached
}

/// Kept outside SwiftData so a ledger save never rewrites image bytes.
@MainActor
final class ExpenseAttachmentStore {
    private let root: URL
    private let fileManager: FileManager
    static let maximumPerExpense = 5

    init(root: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.root = root ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExpenseAttachments", isDirectory: true)
    }

    func attachments(for expenseID: UUID) -> [ExpenseAttachment] {
        let directory = root.appendingPathComponent(expenseID.uuidString, isDirectory: true)
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
        return files.compactMap { url in
            guard url.pathExtension == "jpg", let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { return nil }
            return ExpenseAttachment(id: id, url: url)
        }.sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
    }

    @discardableResult
    func add(imageData: Data, to expenseID: UUID) throws -> ExpenseAttachment {
        guard attachments(for: expenseID).count < Self.maximumPerExpense else { throw ExpenseAttachmentError.limitReached }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400
              ] as CFDictionary) else { throw ExpenseAttachmentError.unreadableImage }
        let image = UIImage(cgImage: thumbnail)
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let sanitized = renderer.jpegData(withCompressionQuality: 0.88) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        var directory = root.appendingPathComponent(expenseID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let id = UUID()
        let destination = directory.appendingPathComponent(id.uuidString).appendingPathExtension("jpg")
        try sanitized.write(to: destination, options: .atomic)
        return ExpenseAttachment(id: id, url: destination)
    }

    func remove(_ attachmentID: UUID, from expenseID: UUID) throws {
        let url = root.appendingPathComponent(expenseID.uuidString, isDirectory: true)
            .appendingPathComponent(attachmentID.uuidString).appendingPathExtension("jpg")
        try fileManager.removeItem(at: url)
    }

    func removeAll(for expenseID: UUID) throws {
        let directory = root.appendingPathComponent(expenseID.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) { try fileManager.removeItem(at: directory) }
    }

    func removeOrphans(keeping expenseIDs: Set<UUID>) throws {
        guard fileManager.fileExists(atPath: root.path) else { return }
        for directory in try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            guard let id = UUID(uuidString: directory.lastPathComponent), !expenseIDs.contains(id) else { continue }
            try fileManager.removeItem(at: directory)
        }
    }
}
