import AVFoundation
import AudioToolbox
import Observation
import Speech

@Observable
@MainActor
final class PronunciationService {
    enum Phase: Equatable {
        case idle
        case preparing
        case listening
        case success
        case failure
        case denied
        case unavailable
    }

    static let shared = PronunciationService()

    private(set) var phase: Phase = .idle
    private(set) var activeWordID: String?

    private var session: RecognitionSession?
    private var attemptTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var attemptToken = 0

    private static let successSound: SystemSoundID = 1054
    private static let failureSound: SystemSoundID = 1053

    private static let listenTimeout: Duration = .seconds(10)

    private init() {}

    func begin(word: String, wordID: String, localeID: String) {
        cancel()
        let token = attemptToken
        activeWordID = wordID
        phase = .preparing

        attemptTask = Task { [weak self] in
            guard let self else { return }
            guard await Self.requestMicrophone() else {
                self.resolve(.denied, token: token)
                return
            }
            guard self.attemptToken == token else { return }

            do {
                let session = try await RecognitionSession(target: word, localeID: localeID)
                guard self.attemptToken == token else {
                    await session.tearDown()
                    return
                }
                self.session = session

                try await session.start()
                guard self.attemptToken == token else {
                    await session.tearDown()
                    return
                }
                self.phase = .listening
                self.startTimeout(token: token)

                let matched = await session.result()
                guard self.attemptToken == token else { return }
                self.resolve(matched ? .success : .failure, token: token)
            } catch {
                guard self.attemptToken == token else { return }
                self.resolve(.unavailable, token: token)
            }
        }
    }

    func finish() {
        guard phase == .listening || phase == .preparing else { return }
        timeoutTask?.cancel()

        guard let session else {
            cancel()
            return
        }
        Task { await session.stopListening() }
    }

    func cancel() {
        attemptToken += 1
        timeoutTask?.cancel()
        resetTask?.cancel()
        attemptTask?.cancel()
        attemptTask = nil

        if let session {
            self.session = nil
            Task { await session.tearDown() }
        }
        activeWordID = nil
        phase = .idle
    }

    private static func requestMicrophone() async -> Bool {
        Task.detached(priority: .utility) {
            SFSpeechRecognizer.requestAuthorization { _ in }
        }
        return await AVAudioApplication.requestRecordPermission()
    }

    private func startTimeout(token: Int) {
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.listenTimeout)
            guard !Task.isCancelled, let self, self.attemptToken == token else { return }
            self.finish()
        }
    }

    private func resolve(_ verdict: Phase, token: Int) {
        guard attemptToken == token, phase == .listening || phase == .preparing else { return }
        timeoutTask?.cancel()

        if let session {
            self.session = nil
            Task { await session.tearDown() }
        }
        phase = verdict

        switch verdict {
        case .success:
            Haptics.success()
            AudioServicesPlaySystemSound(Self.successSound)
        case .failure:
            Haptics.failure()
            AudioServicesPlaySystemSound(Self.failureSound)
        case .denied, .unavailable:
            return
        default:
            activeWordID = nil
            return
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
}
