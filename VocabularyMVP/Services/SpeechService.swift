import AVFoundation
import Observation

struct VoiceOption: Identifiable {
    let id: String
    let name: String
    let accent: String
    let voiceIdentifier: String
    let pitch: Float
}

@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()

    let voices: [VoiceOption]
    private(set) var speakingVoiceID: String?
    private(set) var progress = 0.0

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        voices = Self.makeVoices()
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, voiceID: String? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        if let option = voices.first(where: { $0.id == voiceID }) {
            utterance.voice = AVSpeechSynthesisVoice(identifier: option.voiceIdentifier)
            utterance.pitchMultiplier = option.pitch
        }
        speakingVoiceID = voiceID
        progress = 0
        synthesizer.speak(utterance)
    }

    // Maps the app's six personas (male + female per accent) onto system voices.
    // Legacy novelty voices (Fred, Albert, …) all report en-US, so they are
    // excluded; remaining voices are ranked by quality and matched by gender.
    // If a device lacks a distinct voice for a persona, the accent's voice is
    // reused with a pitch shift so every persona still sounds different.
    private static func makeVoices() -> [VoiceOption] {
        let personas: [(name: String, accent: String, language: String, gender: AVSpeechSynthesisVoiceGender)] = [
            ("Brian", "American", "en-US", .male),
            ("Mia", "American", "en-US", .female),
            ("Frederick", "British", "en-GB", .male),
            ("Amelia", "British", "en-GB", .female),
            ("Paul", "Australian", "en-AU", .male),
            ("Matilda", "Australian", "en-AU", .female),
        ]
        let ranked = AVSpeechSynthesisVoice.speechVoices()
            .filter { !$0.identifier.hasPrefix("com.apple.speech.synthesis.voice") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
        var used = Set<String>()

        return personas.compactMap { persona in
            let candidates = ranked.filter { $0.language == persona.language }
            guard let voice = candidates.first(where: { $0.gender == persona.gender && !used.contains($0.identifier) })
                ?? candidates.first(where: { !used.contains($0.identifier) })
                ?? candidates.first
            else { return nil }
            used.insert(voice.identifier)

            let genderMatches = voice.gender == persona.gender || voice.gender == .unspecified
            let pitch: Float = genderMatches ? 1.0 : (persona.gender == .male ? 0.8 : 1.25)
            return VoiceOption(id: persona.name, name: persona.name, accent: persona.accent,
                               voiceIdentifier: voice.identifier, pitch: pitch)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        let total = utterance.speechString.utf16.count
        guard total > 0 else { return }
        progress = Double(characterRange.location + characterRange.length) / Double(total)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        progress = 1
        speakingVoiceID = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        progress = 0
        speakingVoiceID = nil
    }
}
