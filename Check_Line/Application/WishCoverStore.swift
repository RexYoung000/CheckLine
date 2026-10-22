import Foundation
import Observation
import UIKit
import ImageIO

nonisolated struct WishCover: Codable, Equatable, Sendable {
    enum Layout: String, Codable, CaseIterable { case symbol, inset, fill }
    var symbol = "headphones"
    var layout: Layout = .symbol
    var imageData: Data?
}

@MainActor @Observable
final class WishCoverStore {
    private(set) var revision = 0
    @ObservationIgnored private var cache: [UUID: WishCover] = [:]
    private let root: URL?

    init(root: URL? = nil, inMemory: Bool = false) {
        self.root = inMemory ? nil : root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WishCovers", isDirectory: true)
    }

    func cover(for id: UUID, fallback: String? = nil) -> WishCover {
        _ = revision
        if let value = cache[id] { return value }
        if let root, let data = try? Data(contentsOf: root.appendingPathComponent(id.uuidString).appendingPathExtension("json")),
           let cover = try? JSONDecoder().decode(WishCover.self, from: data) { cache[id] = cover; return cover }
        return WishCover(symbol: fallback ?? "heart")
    }

    func hasCover(for id: UUID) -> Bool {
        if cache[id] != nil { return true }
        guard let root else { return false }
        return FileManager.default.fileExists(atPath: root.appendingPathComponent(id.uuidString).appendingPathExtension("json").path)
    }

    func save(_ cover: WishCover, for id: UUID) throws {
        if var root {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try root.setResourceValues(values)
            let url = root.appendingPathComponent(id.uuidString).appendingPathExtension("json")
            try JSONEncoder().encode(cover).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        cache[id] = cover
        revision += 1
    }

    func remove(_ id: UUID) throws {
        if let root {
            let url = root.appendingPathComponent(id.uuidString).appendingPathExtension("json")
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
        cache.removeValue(forKey: id); revision += 1
    }

    nonisolated static func thumbnail(_ data: Data) throws -> Data {
        guard data.count <= 40_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1200,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary), let output = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.82) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return output
    }

    static let symbols = ["headphones", "ticket", "airplane", "book", "figure.run", "gamecontroller", "camera", "cup.and.saucer", "tent", "gift", "bicycle", "laptopcomputer", "guitars", "paintpalette", "bed.double", "fork.knife", "tree", "sun.max", "bag", "watch.analog", "pawprint", "music.note", "sparkles", "heart"]
}
