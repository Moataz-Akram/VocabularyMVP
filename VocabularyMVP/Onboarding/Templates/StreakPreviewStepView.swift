import SwiftUI

struct StreakPreviewStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(Theme.accent)
                Text("1")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.onAccent)
                    .offset(y: 14)
            }
            Text("Create a consistent daily learning routine")
                .font(.serifLargeTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            weekStrip
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var weekStrip: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
                    VStack(spacing: 8) {
                        Text(label)
                            .font(.system(.caption, design: .rounded).weight(index == 0 ? .bold : .regular))
                            .foregroundStyle(index == 0 ? Theme.textPrimary : Theme.textSecondary)
                        ZStack {
                            Circle()
                                .fill(index == 0 ? Theme.accent : Theme.background)
                                .frame(width: 34, height: 34)
                            if index == 0 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.onAccent)
                            }
                        }
                    }
                }
            }
            Text("Build a streak, one day at a time")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
        .hardShadow(in: RoundedRectangle(cornerRadius: 24))
    }

    // Seven day labels starting from today, e.g. ["We", "Th", ...]
    private var weekdayLabels: [String] {
        let symbols = Calendar.current.shortWeekdaySymbols
        let today = Calendar.current.component(.weekday, from: .now) - 1
        return (0..<7).map { String(symbols[(today + $0) % 7].prefix(2)) }
    }
}
