import SwiftUI

struct VoicePickerStepView: View {
    @Binding var voiceID: String?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Choose a voice to pronounce words")
                .font(.serifTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            VoiceList(voiceID: $voiceID)
            Spacer()
            Button("Save voice selection", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(voiceID == nil)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
