# Vocabulary MVP

A vocabulary-learning iOS app inspired by [Vocabulary — Learn words daily](https://apps.apple.com/us/app/vocabulary-learn-words-daily/id1084540807). Learn new words through a personalized onboarding, a swipeable word feed, and a voice-powered pronunciation coach.

Built entirely with native frameworks — SwiftUI, SwiftData, AVFoundation, and Speech. No third-party dependencies. iOS 17.2+.

## Features

### Onboarding

A 21-step flow that gets to know the user and tailors the experience:

- Profile questions (single-select, multi-select, text input) with skippable steps.
- A voice picker with tap-to-preview pronunciation voices.
- A three-level word test (beginner / intermediate / advanced) that scores the user's vocabulary level.
- Auto-advance on selection with a haptic tick — fewer taps, smoother flow.

The whole flow is driven by data, not views: one step array rendered by a handful of reusable templates. Adding or reordering a question is a one-line change.

### Word feed

- Full-screen vertical pager of word cards: large serif word, definition, and a tappable phonetic pill that pronounces the word with the chosen voice.
- Detail sheet with examples, synonyms, and word origin.
- Like, bookmark, and share — sharing renders a polished word-card image.
- **Collections**: organize bookmarked words into custom collections (create, rename, delete, reassign).
- Searchable word list.
- Profile screen: change the pronunciation voice, browse liked and saved words, restart onboarding.
- Infinite scroll with proper loading, error, and retry states.

### Pronunciation coach — our addition beyond the original app

Hold the mic button on any word card and say the word. The app listens while the finger is down, checks the speech against the target word using on-device recognition, and reveals the result with haptic and visual feedback. Works fully offline.

### Polish

- Layered, tasteful haptics on every interaction — selections, page snaps, likes, results — tuned from a single central service.
- Accessibility: VoiceOver labels, Dynamic Type, reduce-motion-aware animations, 44pt touch targets.
- Adaptive light/dark theming from a single token set.

## Architecture

MVVM with `@Observable` view models. SwiftData persists likes, bookmarks, and collections; UserDefaults stores the onboarding profile.

```
VocabularyMVP/
├── DesignSystem/     Theme tokens, button styles, haptics, shared controls
├── Onboarding/       Step array + coordinator + template step views
├── Feed/             Feed pager, word cards, collections, sheets, view model
├── Models/           Word, WordInteraction, WordCollection
├── Networking/       APIClient protocol, MockAPIClient, URLSessionAPIClient
├── Repositories/     WordRepository
├── Services/         SpeechService, PronunciationService
└── Resources/        words.json — 100 curated words across 3 levels
```

The app is built as if a backend existed: all data flows through an `APIClient` protocol with REST-shaped endpoints. A mock client serves the bundled word content with pagination and simulated latency, so loading and error states are real; a `URLSession` implementation is ready, and swapping it in is one change at the injection point.

## Running

Open `VocabularyMVP/VocabularyMVP.xcodeproj` and run the `VocabularyMVP` scheme. No setup needed. The pronunciation coach uses the microphone and speech recognition, so it works best on a real device.

## Tests

Unit tests cover the onboarding coordinator and level scoring, the networking layer, and the feed view model. Run with **⌘U**.
