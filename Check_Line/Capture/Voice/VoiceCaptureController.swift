import AVFoundation
import Foundation
import Observation
import Speech
import UIKit

/// User-initiated, on-device transcription. It returns editable text only;
/// sending the text and committing a ledger action remain separate user actions.
@MainActor
@Observable
final class VoiceCaptureController {
    private var session = VoiceCaptureSession()
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var audioSink: VoiceAudioBufferSink?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var hasInputTap = false
    @ObservationIgnored private var hasAudioSession = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var silenceTimeout: Task<Void, Never>?
    @ObservationIgnored private var recordingTimeout: Task<Void, Never>?
    @ObservationIgnored private var finishingTimeout: Task<Void, Never>?
    @ObservationIgnored private var onTextChange: (@MainActor (String) -> Void)?

    var phase: VoiceCapturePhase { session.phase }
    var isActive: Bool { session.isActive }
    var isListening: Bool { phase == .listening }
    var draftText: String { session.draftText }
    var needsPermissionExplanation: Bool {
        AVAudioApplication.shared.recordPermission == .undetermined
            || SFSpeechRecognizer.authorizationStatus() == .notDetermined
    }
    var canOpenSettings: Bool {
        if case .failed(let issue) = phase { return issue.canOpenSettings }
        return false
    }
    var statusKey: String? {
        switch phase {
        case .idle, .finished: nil
        case .requestingPermission: "voice.capture.requestingPermission"
        case .listening: "voice.capture.listening"
        case .finishing: "voice.capture.finishing"
        case .failed(let issue): issue.localizationKey
        }
    }

    /// Call only after a deliberate microphone action and the first-use purpose
    /// explanation. An unsupported language never falls back to cloud recognition.
    func start(
        initialText: String,
        locale: Locale = .current,
        onTextChange: @escaping @MainActor (String) -> Void
    ) async {
        guard !isActive else { return }
        cleanup()
        self.onTextChange = onTextChange
        let id = session.begin(initialText: initialText)
        installInterruptionObservers(id: id)

        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.supportsOnDeviceRecognition else {
            fail(.onDeviceUnavailable, id: id)
            return
        }
        self.recognizer = recognizer

        let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        guard isCurrent(id) else { return }
        guard microphoneAllowed else {
            fail(.microphoneDenied, id: id)
            return
        }

        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        guard isCurrent(id) else { return }
        switch speechPermission {
        case .authorized: break
        case .restricted:
            fail(.speechRestricted, id: id)
            return
        case .denied, .notDetermined:
            fail(.speechDenied, id: id)
            return
        @unknown default:
            fail(.speechDenied, id: id)
            return
        }

        // Recheck after the permission prompts, which can remain onscreen while
        // the device's locale/assets/availability change.
        guard recognizer.supportsOnDeviceRecognition else {
            fail(.onDeviceUnavailable, id: id)
            return
        }
        guard recognizer.isAvailable else {
            fail(.recognitionUnavailable, id: id)
            return
        }
        do {
            try beginRecording(recognizer: recognizer, id: id)
        } catch {
            // Never expose NSError contents: frameworks may include input data.
            fail(.audioUnavailable, id: id)
        }
    }

    /// Stops the microphone immediately, allowing a short final transcription.
    /// A timeout still retains all text already delivered to the draft.
    func finish() {
        guard let id = session.id else { return }
        if phase == .requestingPermission {
            cancel()
            return
        }
        guard session.beginFinishing(id: id) else { return }
        stopAudioInput()
        silenceTimeout?.cancel()
        recordingTimeout?.cancel()
        request?.endAudio()
        recognitionTask?.finish()
        finishingTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            self?.complete(id: id)
        }
    }

    /// Explicit cancellation restores the exact input present before recording.
    func cancel() {
        guard session.cancel() else { return }
        let text = session.draftText
        let callback = onTextChange
        cleanup()
        callback?(text)
    }

    /// Use for backgrounding, closing the panel, changing tasks, or audio loss.
    /// Already transcribed words stay editable; recognition never auto-resumes.
    func stopForInterruption() {
        guard let id = session.id else { return }
        fail(.interrupted, id: id)
    }

    private func isCurrent(_ id: UUID) -> Bool {
        guard session.accepts(id) else { return false }
        if Task.isCancelled {
            cancel()
            return false
        }
        return true
    }

    private func beginRecording(recognizer: SFSpeechRecognizer, id: UUID) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)
        hasAudioSession = true

        let engine = AVAudioEngine()
        audioEngine = engine
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            fail(.audioUnavailable, id: id)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.request = request
        let sink = VoiceAudioBufferSink(request: request)
        audioSink = sink
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { @Sendable buffer, _ in
            sink.append(buffer)
        }
        hasInputTap = true
        engine.prepare()
        try engine.start()
        guard session.beginListening(id: id) else {
            cleanup()
            return
        }
        installAudioConfigurationObserver(engine: engine, id: id)
        recognitionTask = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            let issue = error.map(Self.issue(for:))
            Task { @MainActor [weak self] in
                guard let self, self.session.accepts(id) else { return }
                if let text, self.session.receive(text, id: id) {
                    self.silenceTimeout?.cancel()
                    self.onTextChange?(self.session.draftText)
                }
                if isFinal {
                    self.complete(id: id)
                } else if let issue {
                    self.fail(issue, id: id)
                }
            }
        }
        silenceTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard let self, self.session.accepts(id), self.session.transcription.isEmpty else { return }
            self.fail(.noSpeech, id: id)
        }
        recordingTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(55)) } catch { return }
            guard let self, self.session.accepts(id) else { return }
            self.finish()
        }
    }

    private func complete(id: UUID) {
        guard session.finish(id: id) else { return }
        cleanup()
    }

    private func fail(_ issue: VoiceCaptureIssue, id: UUID) {
        guard session.fail(issue, id: id) else { return }
        cleanup()
    }

    private func installInterruptionObservers(id: UUID) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: nil
        ) { [weak self] notification in
            guard notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in
                guard self?.session.accepts(id) == true else { return }
                self?.stopForInterruption()
            }
        })
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.session.accepts(id) == true else { return }
                self?.stopForInterruption()
            }
        })
    }

    private func installAudioConfigurationObserver(engine: AVAudioEngine, id: UUID) {
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.session.accepts(id), self.isListening else { return }
                self.stopForInterruption()
            }
        })
    }

    private func stopAudioInput() {
        // The tap owns only this lock-protected sink, never MainActor state.
        audioSink?.stop()
        audioEngine?.stop()
        if hasInputTap {
            audioEngine?.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        if hasAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            hasAudioSession = false
        }
    }

    private func cleanup() {
        silenceTimeout?.cancel()
        recordingTimeout?.cancel()
        finishingTimeout?.cancel()
        silenceTimeout = nil
        recordingTimeout = nil
        finishingTimeout = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        stopAudioInput()
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        recognizer = nil
        audioEngine = nil
        audioSink = nil
        onTextChange = nil
    }

    isolated deinit { cleanup() }

    private nonisolated static func issue(for error: any Error) -> VoiceCaptureIssue {
        let error = error as NSError
        return switch (error.domain, error.code) {
        case ("kAFAssistantErrorDomain", 1110): .noSpeech
        case ("kLSRErrorDomain", 102): .onDeviceUnavailable
        case ("kAFAssistantErrorDomain", 1107): .interrupted
        case ("kAFAssistantErrorDomain", 1700): .speechDenied
        default: .recognitionFailed
        }
    }
}

/// AVAudioEngine invokes its tap outside MainActor. A lock keeps the request
/// alive only while recording, and serializes appending against teardown.
private nonisolated final class VoiceAudioBufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    init(request: SFSpeechAudioBufferRecognitionRequest) { self.request = request }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        request?.append(buffer)
    }

    func stop() {
        lock.lock()
        request = nil
        lock.unlock()
    }
}
