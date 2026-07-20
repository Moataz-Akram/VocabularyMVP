import SwiftUI

struct TextInputStepView: View {
    let question: String
    let placeholder: String
    @Binding var text: String?
    let onContinue: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text(question)
                .font(.serifTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            
            TextField(placeholder, text: Binding(
                get: { text ?? "" },
                set: { text = $0.isEmpty ? nil : $0 }))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Theme.surface, in: Capsule())
                .focused($isFocused)
                .submitLabel(.done)
            
            Spacer()
            
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(text == nil)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .onAppear { isFocused = true }
    }
}
