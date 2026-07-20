import Foundation

enum OnboardingFlow {
    static let steps: [OnboardingStep] = [
        OnboardingStep(id: "welcome", template: .welcome),
        OnboardingStep(id: "source", template: .singleSelect(
            question: "How did you hear about Vocabulary?",
            options: ["Instagram", "Friend/family", "Web search", "TikTok", "App Store", "Facebook", "Other"],
            answer: \.source)),
        OnboardingStep(id: "tailor-info", template: .info(
            symbol: "chart.line.uptrend.xyaxis",
            title: "Tailor your word recommendations")),
        OnboardingStep(id: "gender", template: .singleSelect(
            question: "Which option represents you best?",
            options: ["Female", "Male", "Other", "Prefer not to say"],
            answer: \.gender), isSkippable: true),
        OnboardingStep(id: "name", template: .textInput(
            question: "What do you want to be called?",
            placeholder: "Your name",
            answer: \.name), isSkippable: true),
        OnboardingStep(id: "customize-info", template: .info(
            symbol: "slider.horizontal.3",
            title: "Customize the app to improve your experience")),
        OnboardingStep(id: "goal", template: .singleSelect(
            question: "How many words do you want to learn per week?",
            options: ["10 words a week", "30 words a week", "50 words a week"],
            answer: \.weeklyGoal), isSkippable: true),
        OnboardingStep(id: "streak", template: .streakPreview),
        OnboardingStep(id: "voice", template: .voicePicker),
        OnboardingStep(id: "topics", template: .multiSelect(
            question: "Which topics are you interested in?",
            options: ["Society", "Human body", "Emotions", "Business", "Other"],
            answer: \.topics), isSkippable: true),
        OnboardingStep(id: "curiosity", template: .singleSelect(
            question: "What drives your curiosity?",
            options: ["I'm a lifelong learner", "Knowing more than others", "Breaking out of my bubble"],
            answer: \.curiosity), isSkippable: true),
        OnboardingStep(id: "word-preview", template: .wordCardPreview),
        OnboardingStep(id: "level", template: .singleSelect(
            question: "What is your vocabulary level?",
            options: ["Beginner", "Intermediate", "Advanced"],
            answer: \.level)),
        OnboardingStep(id: "frequency", template: .singleSelect(
            question: "Do you often encounter words you don't know?",
            options: ["Daily", "Occasionally", "Never"],
            answer: \.encounterFrequency), isSkippable: true),
        OnboardingStep(id: "self-rating", template: .singleSelect(
            question: "How would you describe your vocabulary?",
            options: ["Struggle to find the right words", "Get by but want to improve", "Comfortable in most situations"],
            answer: \.selfRating), isSkippable: true),
        OnboardingStep(id: "weakest", template: .singleSelect(
            question: "Where does your vocabulary feel weakest?",
            options: ["At work", "When reading", "I always feel confident", "When writing", "In social conversations"],
            answer: \.weakestArea), isSkippable: true),
        OnboardingStep(id: "test-intro", template: .transition(
            text: "Amazing!\nLet's test how many words you know…")),
        OnboardingStep(id: "test-beginner", template: .wordTest(
            level: .beginner,
            words: ["Whisper", "Squint", "Genuine", "Metal", "Jumble", "Borrow"])),
        OnboardingStep(id: "test-intermediate", template: .wordTest(
            level: .intermediate,
            words: ["Deportment", "Whet", "Squander", "Impeccable", "Pervasive", "Morose"])),
        OnboardingStep(id: "test-advanced", template: .wordTest(
            level: .advanced,
            words: ["Logophile", "Lucubration", "Quixotic", "Numinous", "Superincumbent", "Callipygian"])),
        OnboardingStep(id: "done", template: .transition(
            text: "Great!\nYour feed is personalized and ready")),
    ]
}
