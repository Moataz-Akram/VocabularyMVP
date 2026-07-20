import SwiftUI

struct MultiSelectStepView: View {
    let question: String
    var subtitle: String?
    let options: [String]
    @Binding var selection: [String]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(question)
                .font(.serifTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            
            if let subtitle {
                Text(subtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Spacer().frame(height: 12)
            
            ForEach(options, id: \.self) { option in
                SelectableRow(title: option, isSelected: selection.contains(option)) {
                    toggle(option)
                }
            }
            
            Spacer()
            
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func toggle(_ option: String) {
        if let index = selection.firstIndex(of: option) {
            selection.remove(at: index)
            Haptics.deselection()
        } else {
            selection.append(option)
            Haptics.selection()
        }
    }
}
