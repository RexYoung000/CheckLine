import Foundation

/// Turns on-device speech transcription into the same text input as typing.
/// Original audio is discarded by the caller; this adapter never sees it.
nonisolated enum SpeechCaptureAdapter {
    static func input(fromTranscription transcription: String) -> AgentInput {
        .speechTranscription(transcription.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
