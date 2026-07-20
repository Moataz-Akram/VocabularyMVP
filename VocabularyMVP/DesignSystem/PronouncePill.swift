import SwiftUI

// Phonetic capsule that pronounces the word when tapped. `compact` is the
// smaller variant used inside word row cards.
struct PronouncePill: View {
    let word: String
    let phonetic: String?
    let voiceID: String?
    var compact = false

    var body: some View {
        Button {
            SpeechService.shared.speak(word, voiceID: voiceID)
        } label: {
            HStack(spacing: 6) {
                if let phonetic {
                    Text(phonetic)
                }
                Image(systemName: "speaker.wave.2")
            }
            .font(.system(compact ? .caption : .subheadline, design: .rounded))
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 6 : 8)
            .background(Theme.background, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pronounce \(word)")
    }
}
