import Foundation

/// Turns on-device Vision OCR lines into the same text input as typing.
/// Original images are discarded by the caller; this adapter never sees them.
nonisolated enum ImageOCRCaptureAdapter {
    static func input(fromOCRLines lines: [String]) -> AgentInput {
        let text = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
        return .ocrText(text)
    }
}
