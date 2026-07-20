import Foundation

struct OnboardingStep: Identifiable {
    enum Template {
        case welcome
        case info(symbol: String, title: String)
        case transition(text: String)
        case singleSelect(question: String, options: [String], answer: WritableKeyPath<OnboardingProfile, String?>)
        case multiSelect(question: String, options: [String], answer: WritableKeyPath<OnboardingProfile, [String]>)
        case textInput(question: String, placeholder: String, answer: WritableKeyPath<OnboardingProfile, String?>)
        case voicePicker
        case streakPreview
        case wordCardPreview
        case wordTest(level: WordLevel, words: [String])
    }

    let id: String
    let template: Template
    var isSkippable = false
}
