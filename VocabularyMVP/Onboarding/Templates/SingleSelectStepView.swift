import SwiftUI

struct SingleSelectStepView: View {
    let question: String
    let options: [String]
    @Binding var selection: String?
    let onContinue: () -> Void

    @State private var isAdvancing = false

    var body: some View {
        VStack(spacing: 12) {
            Text(question)
                .font(.serifTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            ForEach(options, id: \.self) { option in
                SelectableRow(title: option, isSelected: selection == option) {
                    select(option)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // Selecting auto-advances after a beat, so the user sees the highlight land.
    private func select(_ option: String) {
        guard !isAdvancing else { return }
        isAdvancing = true
        selection = option
        Haptics.selection()
        Task {
            try? await Task.sleep(for: .seconds(0.4))
            onContinue()
        }
    }
}
