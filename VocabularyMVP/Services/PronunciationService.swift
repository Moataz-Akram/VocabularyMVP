import AVFoundation
import AudioToolbox
import Observation
import Speech

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
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    // Bumped on every cancel/new attempt so in-flight async work from a
    // superseded attempt can tell it is stale and bail out.
    private var attempt = 0

    // SIMToolkit ack sounds: a short positive blip and its negative twin.
    // Both respect the silent switch, leaving haptics as the only feedback in
    // silent mode.
    private static let successSound: SystemSoundID = 1054
    private static let failureSound: SystemSoundID = 1053

    private static let listenTimeout: Duration = .seconds(5)

    private init() {}

    /// Listens for the user to say `word` and resolves to success or failure.
    /// Recognition prefers the on-device model for the voice's locale; the
    /// simulator lacks on-device models, so it falls back to Apple's server.
    func check(word: String, wordID: String, localeID: String) {
        cancel()
        let attemptID = attempt
        activeWordID = wordID
        phase = .listening

        Task {
            guard await Self.requestPermissions() else {
                if self.attempt == attemptID { self.resolve(.denied, wordID: wordID) }
                return
            }
            guard self.attempt == attemptID, self.phase == .listening else { return }
            do {
                try await self.beginRecognition(target: word, wordID: wordID,
                                                localeID: localeID, attemptID: attemptID)
            } catch {
                if self.attempt == attemptID { self.resolve(.idle, wordID: wordID) }
            }
        }
    }

    /// Stops the mic the moment the finger lifts. Capture shuts down right
    /// away; the recognizer gets a short grace window to finish judging the
    /// audio it already has, after which we rule on the last transcript
    /// ourselves. Released before recognition started (e.g. during the
    /// permission prompt) there is nothing to judge, so the attempt is
    /// abandoned.
    func stopListening() {
        timeoutTask?.cancel()
        guard phase == .listening else { return }
        guard recognitionRequest != nil else {
            cancel()
            return
        }
        recognitionRequest?.endAudio()
        Task { await captureEngine.stop() }
        graceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled, let self, let wordID = self.activeWordID else { return }
            self.resolve(.failure, wordID: wordID)
        }
    }

    func cancel() {
        attempt += 1
        timeoutTask?.cancel()
        graceTask?.cancel()
        resetTask?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        Task { await captureEngine.stop() }
        activeWordID = nil
        phase = .idle
    }

    // MARK: - Recognition

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
        async -> (SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest)? {
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

    private func beginRecognition(target: String, wordID: String,
                                  localeID: String, attemptID: Int) async throws {
        guard let (recognizer, request) = await Self.makeRecognition(target: target, localeID: localeID)
        else { throw CancellationError() }
        guard attempt == attemptID, phase == .listening else { return }
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Any candidate transcription counts, not just the top one — the
            // right word is often the recognizer's second guess.
            let candidates = result?.transcriptions.map(\.formattedString) ?? []
            let isFinal = result?.isFinal ?? false
            Task { @MainActor [weak self] in
                guard let self, self.activeWordID == wordID, self.phase == .listening else { return }
                if candidates.contains(where: { Self.matches(target: target, transcript: $0) }) {
                    self.resolve(.success, wordID: wordID)
                } else if isFinal || error != nil {
                    self.resolve(.failure, wordID: wordID)
                }
            }
        }

        try await captureEngine.start(feeding: request)

        // The finger may have lifted (or the attempt been cancelled) while the
        // engine was spinning up off-main; if so the stop enqueued then ran
        // before capture began, so shut the engine down again.
        guard attempt == attemptID, phase == .listening else {
            await captureEngine.stop()
            return
        }

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.listenTimeout)
            guard !Task.isCancelled else { return }
            self?.stopListening()
        }
    }

    private func resolve(_ result: Phase, wordID: String) {
        guard activeWordID == wordID, phase == .listening else { return }
        timeoutTask?.cancel()
        graceTask?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        Task { await captureEngine.stop() }
        phase = result

        switch result {
        case .success:
            Haptics.success()
            AudioServicesPlaySystemSound(Self.successSound)
        case .failure:
            Haptics.failure()
            AudioServicesPlaySystemSound(Self.failureSound)
        default:
            break
        }
        scheduleReset(after: result == .success ? .seconds(2) : .seconds(4))
    }

    private func scheduleReset(after delay: Duration) {
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, self.phase != .listening else { return }
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

// Owns the audio engine and session. AVAudioSession calls block on the audio
// server daemon, which runs at lower QoS than the main thread — doing them on
// the main actor caused priority-inversion warnings and visible UI stalls, so
// they are serialized here off-main instead.
private actor CaptureEngine {
    enum CaptureError: Error {
        case noAudioInput
    }

    private let engine = AVAudioEngine()
    private var isCapturing = false

    func start(feeding request: SFSpeechAudioBufferRecognitionRequest) throws {
        guard !isCapturing else { return }
        let session = AVAudioSession.sharedInstance()
        // Mode stays .default: .measurement requests raw unprocessed input,
        // which the simulator's virtual mic route can't always provide,
        // yielding an invalid input format.
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // installTap raises an uncatchable NSException on an invalid format,
        // which is what a route with no usable mic reports. Bail as a Swift
        // error instead of crashing.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            restorePlaybackSession(session)
            throw CaptureError.noAudioInput
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    func stop() {
        guard isCapturing else { return }
        isCapturing = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        restorePlaybackSession(AVAudioSession.sharedInstance())
    }

    // Hands the session back to SpeechService's text-to-speech setup.
    private func restorePlaybackSession(_ session: AVAudioSession) {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
    }
}
