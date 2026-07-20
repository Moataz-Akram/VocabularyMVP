import SwiftUI

@MainActor
struct ProfileSheet: View {
    @Environment(VoiceSettings.self) private var voiceSettings
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OnboardingProfile.hasCompletedOnboardingKey) private var hasCompletedOnboarding = true
    @State private var showsRestartConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Vocabulary")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())],
                              spacing: 16) {
                        tile("Favorites", symbol: "heart.fill") {
                            WordListView()
                        }
                        
                        tile("Collections", symbol: "bookmark.fill") {
                            CollectionsListView()
                        }
                    }
                    
                    Text("Settings")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .padding(.top, 8)
                    
                    voiceRow
                    
                    // Restart onboarding button is available on debug only.
                    #if DEBUG
                    Button("Restart onboarding", role: .destructive) {
                        showsRestartConfirm = true
                    }
                    .font(.system(.body, design: .rounded))
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity)
                    .confirmationDialog("Restart onboarding?",
                                        isPresented: $showsRestartConfirm, titleVisibility: .visible) {
                        Button("Restart", role: .destructive) {
                            hasCompletedOnboarding = false
                            dismiss()
                        }
                    } message: {
                        Text("Your saved words and collections stay; you'll go through setup again.")
                    }
                    #endif
                    
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Theme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private var voiceRow: some View {
        NavigationLink {
            VoiceSettingsView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                
                Text("Pronunciation voice")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                
                Spacer(minLength: 8)
                
                if let name = SpeechService.shared.voices.first(where: { $0.id == voiceSettings.voiceID })?.name {
                    Text(name)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(HardShadowButtonStyle(shape: RoundedRectangle(cornerRadius: 20)))
    }

    private func tile(_ title: String, symbol: String,
                      @ViewBuilder destination: @escaping () -> some View) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(HardShadowButtonStyle(shape: RoundedRectangle(cornerRadius: 20)))
    }
}

// Selecting a row applies and persists the voice immediately — no save button.
@MainActor
private struct VoiceSettingsView: View {
    @Environment(VoiceSettings.self) private var voiceSettings

    var body: some View {
        ScrollView {
            VoiceList(voiceID: Binding(
                get: { voiceSettings.voiceID },
                set: { voiceSettings.setVoice($0) }))
                .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Pronunciation voice")
        .navigationBarTitleDisplayMode(.inline)
        .customBackButton()
    }
}
