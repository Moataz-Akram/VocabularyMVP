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
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var attemptToken = 0

    private static let successSound: SystemSoundID = 1054
    private static let failureSound: SystemSoundID = 1053

    private static let listenTimeout: Duration = .seconds(5)
    private static let verdictGrace: Duration = .seconds(0.25)

    private init() {}

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
                if self.attemptToken == token { self.resolve(.idle, token: token) }
            }
        }
    }

    func finish() {
        guard phase == .listening else { return }
        let token = attemptToken
        timeoutTask?.cancel()

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

    private static func requestPermissions() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return status == .authorized
    }

    private nonisolated static func makeRecognition(target: String, localeID: String)
        -> (SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest)? {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
            recognizer.isAvailable
        else { return nil }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
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
            let candidates = result?.transcriptions.map(\.formattedString) ?? []
            let isFinal = result?.isFinal ?? false
            Task { @MainActor [weak self] in
                guard let self, self.attemptToken == token, self.phase == .listening else { return }
                if candidates.contains(where: { Self.matches(target: target, transcript: $0) }) {
                    self.resolve(.success, token: token)
                } else if isFinal || error != nil {
                    self.resolve(.failure, token: token)
                }
            }
        }

        try await captureEngine.start(feeding: request, token: token)

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

private actor CaptureEngine {
    enum CaptureError: Error {
        case noAudioInput
        case staleAttempt
    }

    private var engine: AVAudioEngine?
    private var activeToken = 0

    func start(feeding request: SFSpeechAudioBufferRecognitionRequest, token: Int) throws {
        guard token >= activeToken else { throw CaptureError.staleAttempt }
        stopEngine()
        activeToken = token

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
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

    private func restorePlaybackSession(_ session: AVAudioSession) {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
    }
}
