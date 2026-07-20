import AVFoundation
import AudioToolbox
import Observation
import Speech

/// Push-to-talk pronunciation check: capture runs while the finger is down,
/// recognition judges the audio, and the phase drives the UI.
///
/// Lifecycle of one attempt:
///  1. `begin` — permissions, then recognizer + request + capture start.
///  2. Partial results stream in while the user speaks; the first transcript
///     containing the target word resolves `.success` immediately.
///  3. `finish` (finger lifted, or the safety timeout) — capture stops, and a
///     short grace window lets the recognizer finish judging the captured
///     audio before we call it `.failure`.
///
/// Every attempt carries a token. All async callbacks compare tokens before
/// touching state, so anything left over from a superseded attempt — late
/// recognizer callbacks, in-flight engine work, scheduled stops — is inert.
@Observable
@MainActor
final class PronunciationService {
    enum Phase: Equatable {
        case idle
        case listening
        case success
        case failure
        case denied
    }

    static let shared = PronunciationService()

    private(set) var phase: Phase = .idle
    private(set) var activeWordID: String?

    private let captureEngine = CaptureEngine()
    // The recognizer must stay strongly referenced for its task's lifetime.
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var attemptToken = 0

    // SIMToolkit ack sounds: a short positive blip and its negative twin.
    // Both respect the silent switch, leaving haptics as the only feedback in
    // silent mode.
    private static let successSound: SystemSoundID = 1054
    private static let failureSound: SystemSoundID = 1053

    private static let listenTimeout: Duration = .seconds(5)
    private static let verdictGrace: Duration = .seconds(0.25)

    private init() {}

    // MARK: - Public API

    /// Starts an attempt at saying `word`. Recognition prefers the on-device
    /// model for the voice's locale; the simulator lacks on-device models, so
    /// it falls back to Apple's server.
    func begin(word: String, wordID: String, localeID: String) {
        cancel()
        let token = attemptToken
        activeWordID = wordID
        phase = .listening

        Task {
            guard await Self.requestPermissions() else {
                if self.attemptToken == token { self.resolve(.denied, token: token) }
                return
            }
            guard self.attemptToken == token else { return }
            do {
                try await self.startRecognition(target: word, localeID: localeID, token: token)
            } catch {
                // No usable mic route or the engine failed to start; there is
                // nothing to judge, so end the attempt without a verdict.
                if self.attemptToken == token { self.resolve(.idle, token: token) }
            }
        }
    }

    /// Ends the capture (finger lifted or timeout). The recognizer gets a
    /// short grace window to deliver its verdict on the captured audio; if it
    /// stays silent, the attempt fails.
    func finish() {
        guard phase == .listening else { return }
        let token = attemptToken
        timeoutTask?.cancel()

        // Released before capture was up: nothing recorded, nothing to judge.
        guard recognitionRequest != nil else {
            cancel()
            return
        }

        recognitionRequest?.endAudio()
        Task { await captureEngine.stop(ifToken: token) }
        graceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.verdictGrace)
            guard !Task.isCancelled, let self else { return }
            self.resolve(.failure, token: token)
        }
    }

    /// Silently abandons the current attempt, if any.
    func cancel() {
        let staleToken = attemptToken
        attemptToken += 1
        timeoutTask?.cancel()
        graceTask?.cancel()
        resetTask?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        Task { await captureEngine.stop(ifToken: staleToken) }
        activeWordID = nil
        phase = .idle
    }

    // MARK: - Attempt internals

    private static func requestPermissions() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return status == .authorized
    }

    // Recognizer creation and its capability checks talk to the speech daemon,
    // so they run off the main actor.
    private nonisolated static func makeRecognition(target: String, localeID: String)
        -> (SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest)? {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
            recognizer.isAvailable
        else { return nil }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Isolated words lack sentence context, which tanks accuracy; biasing
        // the model toward the expected word recovers most of it. Pronounce it
        // badly and it still transcribes something else.
        request.contextualStrings = [target]
        request.taskHint = .search
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        return (recognizer, request)
    }

    private func startRecognition(target: String, localeID: String, token: Int) async throws {
        let made = await Task.detached(priority: .userInitiated) {
            Self.makeRecognition(target: target, localeID: localeID)
        }.value
        guard let (recognizer, request) = made else { throw CancellationError() }
        guard attemptToken == token, phase == .listening else { return }

        self.recognizer = recognizer
        recognitionRequest = request
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Any candidate transcription counts, not just the top one — the
            // right word is often the recognizer's second guess.
            let candidates = result?.transcriptions.map(\.formattedString) ?? []
            let isFinal = result?.isFinal ?? false
            Task { @MainActor [weak self] in
                guard let self, self.attemptToken == token, self.phase == .listening else { return }
                if candidates.contains(where: { Self.matches(target: target, transcript: $0) }) {
                    self.resolve(.success, token: token)
                } else if isFinal || error != nil {
                    // The recognizer is done and the word wasn't there. While
                    // capture is still running this is definitive; after
                    // finish() the grace timer owns the failure so the verdict
                    // lands on schedule either way.
                    self.resolve(.failure, token: token)
                }
            }
        }

        try await captureEngine.start(feeding: request, token: token)

        // The finger may have lifted (or the attempt been cancelled) while the
        // engine was spinning up off-main; its stop may have run before
        // capture even began, so shut the engine down again.
        guard attemptToken == token, phase == .listening else {
            await captureEngine.stop(ifToken: token)
            return
        }

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.listenTimeout)
            guard !Task.isCancelled, let self, self.attemptToken == token else { return }
            self.finish()
        }
    }

    private func resolve(_ verdict: Phase, token: Int) {
        guard attemptToken == token, phase == .listening else { return }
        timeoutTask?.cancel()
        graceTask?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil
        Task { await captureEngine.stop(ifToken: token) }
        phase = verdict

        switch verdict {
        case .success:
            Haptics.success()
            AudioServicesPlaySystemSound(Self.successSound)
        case .failure:
            Haptics.failure()
            AudioServicesPlaySystemSound(Self.failureSound)
        case .idle:
            activeWordID = nil
            return
        default:
            break
        }
        scheduleReset(after: verdict == .success ? .seconds(2) : .seconds(4), token: token)
    }

    private func scheduleReset(after delay: Duration, token: Int) {
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, self.attemptToken == token else { return }
            self.activeWordID = nil
            self.phase = .idle
        }
    }

    // MARK: - Matching

    // Letters-only, space-delimited comparison so "Ephemeral!" matches
    // "ephemeral" and multi-word targets still require word boundaries.
    private static func matches(target: String, transcript: String) -> Bool {
        !target.isEmpty && normalize(transcript).contains(normalize(target))
    }

    private static func normalize(_ text: String) -> String {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        return " " + words.joined(separator: " ") + " "
    }
}

// Owns microphone capture. AVAudioSession calls block on the audio server
// daemon, which runs at lower QoS than the main thread — doing them on the
// main actor caused priority-inversion stalls, so they are serialized here
// off-main instead.
//
// A fresh AVAudioEngine is built for every capture: input-node state does not
// survive session category changes reliably, and reusing an engine across
// attempts is what previously produced dead-mic captures. Stops carry the
// token of the capture they belong to; actor jobs run by priority rather than
// arrival order, so a stale stop that loses the race against the next start
// must not be able to kill it.
private actor CaptureEngine {
    enum CaptureError: Error {
        case noAudioInput
        case staleAttempt
    }

    private var engine: AVAudioEngine?
    private var activeToken = 0

    func start(feeding request: SFSpeechAudioBufferRecognitionRequest, token: Int) throws {
        // Tokens only grow; a start older than one already seen belongs to a
        // superseded attempt and must not displace the current capture.
        guard token >= activeToken else { throw CaptureError.staleAttempt }
        stopEngine()
        activeToken = token

        // The session must be recording-capable before the engine's input
        // node is first touched; created under a playback-only session the
        // node wires to a dead route and reports a garbage format.
        let session = AVAudioSession.sharedInstance()
        // Mode stays .default: .measurement requests raw unprocessed input,
        // which the simulator's virtual mic route can't always provide.
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // installTap raises an uncatchable NSException on an invalid format,
        // which is what a route with no usable mic reports. Bail as a Swift
        // error instead of crashing.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            restorePlaybackSession(session)
            throw CaptureError.noAudioInput
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            restorePlaybackSession(session)
            throw error
        }
        self.engine = engine
    }

    func stop(ifToken token: Int) {
        guard token == activeToken, engine != nil else { return }
        stopEngine()
        restorePlaybackSession(AVAudioSession.sharedInstance())
    }

    private func stopEngine() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }

    // Hands the session back to SpeechService's text-to-speech setup.
    private func restorePlaybackSession(_ session: AVAudioSession) {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
    }
}
