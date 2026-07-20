import SwiftUI

@MainActor
struct WordRowCard: View {
    let word: Word
    let date: Date?
    let onShare: () -> Void

    @Environment(InteractionsStore.self) private var interactions
    @Environment(VoiceSettings.self) private var voiceSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(word.word)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                PronouncePill(word: word.word, phonetic: word.phonetic,
                              voiceID: voiceSettings.voiceID, compact: true)
            }
            
            if let definitionLine = word.definitionLine {
                Text(definitionLine)
                    .font(.system(size: 16, design: .rounded))
            }
            
            if let example = word.examples?.first {
                Text("(\(example))")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            
            HStack {
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 24) {
                    Button {
                        interactions.toggleLike(word)
                    } label: {
                        Image(systemName: interactions.isLiked(word) ? "heart.fill" : "heart")
                    }
                    .accessibilityLabel(interactions.isLiked(word) ? "Unlike" : "Like")
                    
                    Button {
                        interactions.toggleBookmark(word)
                    } label: {
                        Image(systemName: interactions.isBookmarked(word) ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(interactions.isBookmarked(word) ? "Remove from collection" : "Save to collection")
                    
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share \(word.word)")
                }
                .font(.system(size: 18))
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}
