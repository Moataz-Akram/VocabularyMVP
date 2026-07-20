import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 90))
                .foregroundStyle(Theme.accent)
                .padding(.bottom, 24)
            
            Text("Expand your Vocabulary\nin 1 minute a day")
                .font(.serifLargeTitle)
                .multilineTextAlignment(.center)
            
            Text("Learn 10,000+ new words with a new daily habit that takes just 1 minute")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            stats
                .padding(.bottom, 32)
            Button("Get started", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var stats: some View {
        HStack(spacing: 32) {
            stat("350 million", "words learned")
            stat("4.8 ★", "rating")
            stat("14 million", "downloads")
        }
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
            
            Text(caption)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
