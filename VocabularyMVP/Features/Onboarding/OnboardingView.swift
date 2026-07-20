import SwiftUI

struct OnboardingView: View {
    @State private var coordinator = OnboardingCoordinator()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(coordinator.currentStep.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .animation(.easeInOut(duration: 0.3), value: coordinator.stepIndex)
        .background(Theme.background.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Spacer()
            if coordinator.currentStep.isSkippable {
                Button("Skip") { coordinator.advance() }
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 44)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch coordinator.currentStep.template {
        case .welcome:
            WelcomeStepView(onContinue: coordinator.advance)
        case .info(let symbol, let title):
            InfoStepView(symbol: symbol, title: title, onContinue: coordinator.advance)
        case .transition(let text):
            InfoStepView(symbol: nil, title: text, onContinue: coordinator.advance)
        case .singleSelect(let question, let options, let answer):
            SingleSelectStepView(question: question, options: options,
                                 selection: binding(answer), onContinue: coordinator.advance)
        case .multiSelect(let question, let options, let answer):
            MultiSelectStepView(question: question, options: options,
                                selection: binding(answer), onContinue: coordinator.advance)
        case .textInput(let question, let placeholder, let answer):
            TextInputStepView(question: question, placeholder: placeholder,
                              text: binding(answer), onContinue: coordinator.advance)
        case .voicePicker:
            VoicePickerStepView(voiceID: binding(\.voiceID), onContinue: coordinator.advance)
        case .streakPreview:
            StreakPreviewStepView(onContinue: coordinator.advance)
        case .wordCardPreview:
            WordCardPreviewStepView(voiceID: coordinator.profile.voiceID,
                                    onContinue: coordinator.advance)
        case .wordTest(let level, let words):
            MultiSelectStepView(question: "\(level.title) words",
                                subtitle: "Select all the ones you know",
                                options: words,
                                selection: knownWordsBinding(for: level),
                                onContinue: coordinator.advance)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<OnboardingProfile, T>) -> Binding<T> {
        Binding(get: { coordinator.profile[keyPath: keyPath] },
                set: { coordinator.profile[keyPath: keyPath] = $0 })
    }

    private func knownWordsBinding(for level: WordLevel) -> Binding<[String]> {
        Binding(get: { coordinator.profile.knownWords[level.rawValue] ?? [] },
                set: { coordinator.profile.knownWords[level.rawValue] = $0 })
    }
}

#Preview {
    OnboardingView()
}
