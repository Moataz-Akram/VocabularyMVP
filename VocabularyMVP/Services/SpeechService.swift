import AVFoundation
import Observation

@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    struct Voice: Identifiable {
        let name: String
        let accent: String
        let systemVoice: AVSpeechSynthesisVoice
        var id: String { systemVoice.identifier }
    }

    static let shared = SpeechService()

    let voices: [Voice]
    private(set) var speakingVoiceID: String?
    private(set) var isPaused = false
    private(set) var progress = 0.0

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?

    private override init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        voices = Self.makeVoices()
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, voiceID: String? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        if let voiceID {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceID)
        }
        currentUtterance = utterance
        speakingVoiceID = voiceID
        isPaused = false
        progress = 0
        synthesizer.speak(utterance)
    }

    func pauseOrResume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
        } else if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
            isPaused = true
        }
    }

    // MARK: - Voice selection

    // Assigns each persona the best-quality system voice for its accent and
    // gender. Legacy novelty voices all report en-US and are excluded, and the
    // robotic Eloquence screen-reader voices rank below everything else despite
    // reporting the same quality as normal voices. Compact voices report gender
    // as .unspecified, so gender falls back to a known-name table. When no
    // exact match exists, another English voice of the right gender is borrowed
    // rather than listing the same voice twice.
    private static func makeVoices() -> [Voice] {
        let personas: [(name: String, accent: String, language: String, gender: AVSpeechSynthesisVoiceGender)] = [
            ("Brian", "American", "en-US", .male),
            ("Mia", "American", "en-US", .female),
            ("Frederick", "British", "en-GB", .male),
            ("Amelia", "British", "en-GB", .female),
            ("Paul", "Australian", "en-AU", .male),
            ("Matilda", "Australian", "en-AU", .female),
        ]
        let english = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && !$0.identifier.hasPrefix("com.apple.speech.synthesis.voice") }
            .sorted { (rank($0), $1.name) > (rank($1), $0.name) }
        var used = Set<String>()

        func claim(_ matches: (AVSpeechSynthesisVoice) -> Bool) -> AVSpeechSynthesisVoice? {
            guard let voice = english.first(where: { !used.contains($0.identifier) && matches($0) })
            else { return nil }
            used.insert(voice.identifier)
            return voice
        }

        return personas.compactMap { persona in
            let voice = claim { $0.language == persona.language && gender(of: $0) == persona.gender }
                ?? claim { gender(of: $0) == persona.gender }
                ?? claim { $0.language == persona.language }
                ?? claim { _ in true }
            guard let voice else { return nil }
            return Voice(name: persona.name, accent: persona.accent, systemVoice: voice)
        }
    }

    private static func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
        voice.identifier.hasPrefix("com.apple.eloquence.") ? -1 : voice.quality.rawValue
    }

    private static let maleNames: Set<String> = [
        "Aaron", "Alex", "Arthur", "Daniel", "Eddy", "Fred", "Gordon", "Grandpa",
        "Lee", "Oliver", "Reed", "Rishi", "Rocko",
    ]
    private static let femaleNames: Set<String> = [
        "Catherine", "Flo", "Grandma", "Isha", "Karen", "Kate", "Martha", "Moira",
        "Nicky", "Samantha", "Sandy", "Serena", "Shelley", "Tessa", "Zoe",
    ]

    private static func gender(of voice: AVSpeechSynthesisVoice) -> AVSpeechSynthesisVoiceGender {
        if voice.gender != .unspecified { return voice.gender }
        let firstName = voice.name.components(separatedBy: CharacterSet(charactersIn: " (")).first ?? voice.name
        if maleNames.contains(firstName) { return .male }
        if femaleNames.contains(firstName) { return .female }
        return .unspecified
    }

    // MARK: - AVSpeechSynthesizerDelegate

    // Callbacks are compared against currentUtterance because stopping a voice
    // mid-play delivers its didCancel after the next utterance has started;
    // acting on that stale callback would wipe the new utterance's state.

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard utterance === self.currentUtterance else { return }
            let total = utterance.speechString.utf16.count
            guard total > 0 else { return }
            self.progress = Double(characterRange.location + characterRange.length) / Double(total)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard utterance === self.currentUtterance else { return }
            self.progress = 1
            self.speakingVoiceID = nil
            self.isPaused = false
            self.currentUtterance = nil
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            guard utterance === self.currentUtterance else { return }
            self.progress = 0
            self.speakingVoiceID = nil
            self.isPaused = false
            self.currentUtterance = nil
        }
    }
}
