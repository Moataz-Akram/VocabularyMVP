import SwiftUI

struct RadioIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Theme.onAccent : Theme.textSecondary, lineWidth: 2)
                .frame(width: 26, height: 26)

            if isSelected {
                Circle()
                    .fill(Theme.onAccent)
                    .frame(width: 14, height: 14)
            }
        }
    }
}
