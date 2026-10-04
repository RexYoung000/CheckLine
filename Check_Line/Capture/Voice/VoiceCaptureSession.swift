import Foundation

nonisolated enum VoiceCaptureIssue: Equatable, Sendable {
    case microphoneDenied
    case speechDenied
    case speechRestricted
    case onDeviceUnavailable
    case recognitionUnavailable
    case audioUnavailable
    case noSpeech
    case interrupted
    case recognitionFailed

    var localizationKey: String {
        switch self {
        case .microphoneDenied: "voice.capture.microphoneDenied"
        case .speechDenied: "voice.capture.speechDenied"
        case .speechRestricted: "voice.capture.speechRestricted"
        case .onDeviceUnavailable: "voice.capture.onDeviceUnavailable"
        case .recognitionUnavailable: "voice.capture.recognitionUnavailable"
        case .audioUnavailable: "voice.capture.audioUnavailable"
        case .noSpeech: "voice.capture.noSpeech"
        case .interrupted: "voice.capture.interrupted"
        case .recognitionFailed: "voice.capture.failed"
        }
    }

    var canOpenSettings: Bool {
        self == .microphoneDenied || self == .speechDenied
    }
}

nonisolated enum VoiceCapturePhase: Equatable, Sendable {
    case idle
    case requestingPermission
    case listening
    case finishing
    case finished
    case failed(VoiceCaptureIssue)
}

/// Keeps a single utterance separate from the existing typed draft. The session
/// ID invalidates permission and transcription callbacks after cancel/restart.
nonisolated struct VoiceCaptureSession: Sendable {
    private(set) var phase: VoiceCapturePhase = .idle
    private(set) var id: UUID?
    private(set) var initialText = ""
    private(set) var transcription = ""

    var isActive: Bool { id != nil }

    var draftText: String {
        guard !transcription.isEmpty else { return initialText }
        guard !initialText.isEmpty else { return transcription }
        let separator = initialText.last?.isWhitespace == true ? "" : " "
        return initialText + separator + transcription
    }

    @discardableResult
    mutating func begin(initialText: String) -> UUID {
        let newID = UUID()
        id = newID
        self.initialText = initialText
        transcription = ""
        phase = .requestingPermission
        return newID
    }

    func accepts(_ candidate: UUID) -> Bool { id == candidate }

    @discardableResult
    mutating func beginListening(id: UUID) -> Bool {
        guard accepts(id), phase == .requestingPermission else { return false }
        phase = .listening
        return true
    }

    @discardableResult
    mutating func receive(_ text: String, id: UUID) -> Bool {
        guard accepts(id), phase == .listening || phase == .finishing else { return false }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != transcription else { return false }
        transcription = text
        return true
    }

    @discardableResult
    mutating func beginFinishing(id: UUID) -> Bool {
        guard accepts(id), phase == .listening else { return false }
        phase = .finishing
        return true
    }

    @discardableResult
    mutating func finish(id: UUID) -> Bool {
        guard accepts(id) else { return false }
        phase = transcription.isEmpty ? .failed(.noSpeech) : .finished
        self.id = nil
        return true
    }

    @discardableResult
    mutating func fail(_ issue: VoiceCaptureIssue, id: UUID) -> Bool {
        guard accepts(id) else { return false }
        phase = .failed(issue)
        self.id = nil
        return true
    }

    /// Only an explicit cancel restores the pre-recording draft.
    @discardableResult
    mutating func cancel() -> Bool {
        guard isActive else { return false }
        id = nil
        transcription = ""
        phase = .idle
        return true
    }
}
