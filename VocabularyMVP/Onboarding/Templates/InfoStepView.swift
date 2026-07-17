import SwiftUI

struct InfoStepView: View {
    let symbol: String?
    let title: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.accent)
            }
            Text(title)
                .font(.serifLargeTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
