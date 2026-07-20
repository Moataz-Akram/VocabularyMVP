@preconcurrency import AVFoundation
import Speech

/// One pronunciation attempt: owns the audio graph, the `SpeechAnalyzer` and the
/// transcriber, and settles on a single verdict.
actor RecognitionSession {
    enum SessionError: Error {
        case unsupportedLocale
        case noAudioFormat
        case noAudioInput
    }

    private let target: PronunciationMatcher.Target
    private let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let analysisFormat: AVAudioFormat
    private let inputStream: AsyncStream<AnalyzerInput>
    private let inputContinuation: AsyncStream<AnalyzerInput>.Continuation
    private let locale: Locale

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var consumeTask: Task<Void, Never>?
    private var backstopTask: Task<Void, Never>?
    private var isCapturing = false

    private var matched: Bool?
    private var waiter: CheckedContinuation<Bool, Never>?

    init(target word: String, localeID: String) async throws {
        var resolved = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeID))
        if resolved == nil {
            resolved = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
        }
        guard let locale = resolved else { throw SessionError.unsupportedLocale }
        self.locale = locale
        self.target = PronunciationMatcher.Target(word)

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .alternativeTranscriptions],
            attributeOptions: [.transcriptionConfidence]
        )
        self.transcriber = transcriber

        if await AssetInventory.status(forModules: [transcriber]) != .installed,
           let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        // Best effort: a full reservation table is not a reason to fail the attempt.
        _ = try? await AssetInventory.reserve(locale: locale)

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        else { throw SessionError.noAudioFormat }
        self.analysisFormat = format

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputStream = stream
        self.inputContinuation = continuation

        // Biasing toward the target is what keeps correctly-said words from being
        // transcribed as something else — the main source of false negatives.
        let context = AnalysisContext()
        context.contextualStrings[.general] = PronunciationMatcher.biasStrings(for: word)

        self.analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.setContext(context)
    }

    func start() async throws {
        consumeTask = Task { [weak self] in await self?.consumeResults() }

        try await analyzer.prepareToAnalyze(in: analysisFormat)
        try await analyzer.start(inputSequence: inputStream)
        try startCapture()
    }

    /// Ends audio and asks the analyzer to finalize. The verdict follows from the
    /// results stream ending, not from a fixed grace period.
    func stopListening() async {
        guard isCapturing else { return }
        stopCapture()
        inputContinuation.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()

        // Safety net only: if finalization never delivers, do not hang the UI.
        backstopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.settle(matched: false)
        }
    }

    func tearDown() async {
        backstopTask?.cancel()
        stopCapture()
        inputContinuation.finish()
        await analyzer.cancelAndFinishNow()
        consumeTask?.cancel()
        consumeTask = nil
        settle(matched: false)
        _ = await AssetInventory.release(reservedLocale: locale)
    }

    /// True once the target is matched, false when the recognizer has finished
    /// without a match. The transcript itself is deliberately never surfaced: on a
    /// failed attempt it is usually the recognizer's guess, not what was said.
    func result() async -> Bool {
        if let matched { return matched }
        return await withCheckedContinuation { waiter = $0 }
    }

    private func consumeResults() async {
        do {
            for try await result in transcriber.results {
                let confidence = PronunciationMatcher.meanConfidence(result.text)
                let candidates = [String(result.text.characters)]
                    + result.alternatives.map { String($0.characters) }

                if PronunciationMatcher.matches(target, candidates: candidates, confidence: confidence) {
                    settle(matched: true)
                    return
                }
            }
        } catch {
            // Fall through — an errored stream is a failed attempt, not a crash.
        }
        settle(matched: false)
    }

    private func settle(matched value: Bool) {
        guard matched == nil else { return }
        backstopTask?.cancel()
        matched = value
        waiter?.resume(returning: value)
        waiter = nil
    }

    // MARK: Audio capture

    private func startCapture() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            restorePlaybackSession()
            throw SessionError.noAudioInput
        }

        // SpeechAnalyzer, unlike SFSpeechAudioBufferRecognitionRequest, will not
        // resample for us — the mic format has to be converted explicitly.
        if !inputFormat.isEqual(analysisFormat) {
            converter = AVAudioConverter(from: inputFormat, to: analysisFormat)
            converter?.primeMethod = .none
        }

        let continuation = inputContinuation
        let convert = Self.makeConverterClosure(converter, to: analysisFormat)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            if let ready = convert(buffer) {
                continuation.yield(AnalyzerInput(buffer: ready))
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            restorePlaybackSession()
            throw error
        }
        isCapturing = true
    }

    /// Built once so the tap block captures a plain closure rather than the actor.
    private static func makeConverterClosure(
        _ converter: AVAudioConverter?,
        to format: AVAudioFormat
    ) -> @Sendable (AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return { $0 } }
        return { buffer in
            let ratio = format.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1024
            guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                return nil
            }
            var consumed = false
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, inputStatus in
                if consumed {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                consumed = true
                inputStatus.pointee = .haveData
                return buffer
            }
            guard status != .error, output.frameLength > 0 else { return nil }
            return output
        }
    }

    private func stopCapture() {
        guard isCapturing else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isCapturing = false
        restorePlaybackSession()
    }

    private nonisolated func restorePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
    }
}
