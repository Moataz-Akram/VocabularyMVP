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
        case failure(heard: String?)
        case denied
    }

    static let shared = PronunciationService()

    private(set) var phase: Phase = .idle
    private(set) var activeWordID: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var latestTranscript = ""

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
        activeWordID = wordID
        phase = .listening
        latestTranscript = ""

        Task {
            guard await Self.requestPermissions() else {
                self.resolve(.denied, wordID: wordID)
                return
            }
            guard self.activeWordID == wordID, self.phase == .listening else { return }
            do {
                try self.beginRecognition(target: word, wordID: wordID, localeID: localeID)
            } catch {
                self.resolve(.idle, wordID: wordID)
            }
        }
    }

    /// Stops the mic the moment the finger lifts. The engine is shut down
    /// immediately so no further audio is captured; the recognizer gets a short
    /// grace window to finish judging what was already recorded, after which we
    /// rule on the last transcript ourselves. Released before recognition
    /// started (e.g. during the permission prompt) there is nothing to judge,
    /// so the attempt is abandoned.
    func stopListening() {
        timeoutTask?.cancel()
        guard phase == .listening else { return }
        guard recognitionRequest != nil else {
            cancel()
            return
        }
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        graceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled, let self, let wordID = self.activeWordID else { return }
            self.resolve(self.failureVerdict, wordID: wordID)
        }
    }

    func cancel() {
        timeoutTask?.cancel()
        graceTask?.cancel()
        resetTask?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        stopAudio()
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

    private func beginRecognition(target: String, wordID: String, localeID: String) throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
            recognizer.isAvailable
        else { throw CancellationError() }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

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
        recognitionRequest = request

        let input = audioEngine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Any candidate transcription counts, not just the top one — the
            // right word is often the recognizer's second guess.
            let candidates = result?.transcriptions.map(\.formattedString) ?? []
            let best = result?.bestTranscription.formattedString ?? ""
            let isFinal = result?.isFinal ?? false
            Task { @MainActor [weak self] in
                guard let self, self.activeWordID == wordID, self.phase == .listening else { return }
                if !best.isEmpty { self.latestTranscript = best }
                if ([best] + candidates).contains(where: { Self.matches(target: target, transcript: $0) }) {
                    self.resolve(.success, wordID: wordID)
                } else if isFinal || error != nil {
                    self.resolve(self.failureVerdict, wordID: wordID)
                }
            }
        }

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.listenTimeout)
            guard !Task.isCancelled else { return }
            self?.stopListening()
        }
    }

    private var failureVerdict: Phase {
        .failure(heard: latestTranscript.isEmpty ? nil : latestTranscript)
    }

    private func resolve(_ result: Phase, wordID: String) {
        guard activeWordID == wordID, phase == .listening else { return }
        timeoutTask?.cancel()
        graceTask?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        stopAudio()
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

    private func stopAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        // Hand the session back to SpeechService's text-to-speech setup.
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
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
