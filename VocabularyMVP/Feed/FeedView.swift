import SwiftUI
import SwiftData

@MainActor
struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FeedViewModel()
    @State private var scrolledWordID: String?
    @State private var detailWord: Word?
    @State private var shareWord: Word?
    @State private var collectionPickerWord: Word?
    @State private var showsSettings = false
    @Namespace private var profileZoom

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .overlay(alignment: .topLeading) { profileButton }
            .overlay(alignment: .top) { goalPill }
            .overlay(alignment: .top) { savedToast }
            .sheet(item: $detailWord) { word in
                WordDetailSheet(word: word, voiceID: viewModel.voiceID)
            }
            .sheet(item: $collectionPickerWord) { word in
                CollectionPickerSheet(word: word, viewModel: viewModel)
            }
            .fullScreenCover(item: $shareWord) { word in
                WordShareSheet(word: word)
            }
            .fullScreenCover(isPresented: $showsSettings) {
                ProfileSheet(viewModel: viewModel)
                    .zoomTransition(sourceID: "profile", in: profileZoom)
            }
            .task { await viewModel.start(context: modelContext) }
            .onChange(of: scrolledWordID) { _, newID in
                Haptics.stepAdvance()
                viewModel.markSeen(wordID: newID)
                viewModel.loadMoreIfNeeded(nearWordID: newID)
            }
            .animation(.spring(duration: 0.35), value: viewModel.savedToast?.word.id)
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.userDidTakeScreenshotNotification)) { _ in
                // Mirror the original app: a screenshot opens the share card.
                guard shareWord == nil, detailWord == nil, !showsSettings else { return }
                shareWord = currentWord
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingInitial {
            ProgressView()
                .controlSize(.large)
        } else if viewModel.words.isEmpty {
            VStack(spacing: 16) {
                Text(viewModel.loadFailed ? "Couldn't load your words" : "No words to show")
                    .font(.serifTitle)
                    .foregroundStyle(Theme.textPrimary)
                if viewModel.loadFailed {
                    Button("Try again") {
                        Task { await viewModel.retry() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .fixedSize()
                }
            }
            .padding(24)
        } else {
            feed
        }
    }

    private var feed: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.words) { word in
                    WordCardView(word: word,
                                 isLiked: viewModel.isLiked(word),
                                 isBookmarked: viewModel.isBookmarked(word),
                                 voiceID: viewModel.voiceID,
                                 onInfo: { detailWord = word },
                                 onShare: { shareWord = word },
                                 onLike: { viewModel.toggleLike(word) },
                                 onBookmark: { viewModel.toggleBookmark(word) })
                        .containerRelativeFrame(.vertical)
                }
                // A page load failed mid-feed; the feed otherwise just ends
                // silently. Scrolling near the end also retries on its own.
                if viewModel.loadFailed {
                    VStack(spacing: 16) {
                        Text("Couldn't load more words")
                            .font(.serifTitle)
                            .foregroundStyle(Theme.textPrimary)
                        Button("Try again") {
                            Task { await viewModel.retry() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .fixedSize()
                    }
                    .containerRelativeFrame(.vertical)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledWordID)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
    }

    private var currentWord: Word? {
        viewModel.words.first { $0.id == scrolledWordID } ?? viewModel.words.first
    }

    @ViewBuilder
    private var goalPill: some View {
        if viewModel.bookmarkedTodayCount > 0, viewModel.bookmarkedTodayCount < viewModel.dailyGoal {
            HStack(spacing: 6) {
                Image(systemName: "bookmark")
                    .font(.system(size: 11))
                Text("\(viewModel.bookmarkedTodayCount)/\(viewModel.dailyGoal)")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                ProgressView(value: Double(viewModel.bookmarkedTodayCount) / Double(viewModel.dailyGoal))
                    .tint(Theme.textPrimary)
                    .scaleEffect(y: 0.7)
                    .frame(width: 64)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Theme.surface, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
            .animation(.spring(duration: 0.4), value: viewModel.bookmarkedTodayCount)
            .accessibilityLabel("\(viewModel.bookmarkedTodayCount) of \(viewModel.dailyGoal) words saved today")
        }
    }

    @ViewBuilder
    private var savedToast: some View {
        if let toast = viewModel.savedToast {
            HStack {
                Text("Saved to **\(toast.collection.name)**")
                    .font(.system(.subheadline, design: .rounded))
                Spacer()
                Button("Change") {
                    let word = toast.word
                    viewModel.dismissToast()
                    collectionPickerWord = word
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.accent, in: Capsule())
                .buttonStyle(.plain)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .hardShadow(in: RoundedRectangle(cornerRadius: 20), offset: 2)
            .padding(.horizontal, 16)
            .padding(.top, 52)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var profileButton: some View {
        Button {
            showsSettings = true
        } label: {
            Image(systemName: "person")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .zoomTransitionSource(id: "profile", in: profileZoom)
        .padding(.horizontal, 20)
        .accessibilityLabel("Profile and settings")
    }
}

// Photos-style zoom for the profile cover: the screen grows out of the profile
// button and shrinks back into it on close. The API is iOS 18-only and its
// symbols don't exist in the iOS 17 SDK, so a runtime #available check alone
// wouldn't compile under Xcode 15 — the compiler(>=6.0) condition hides the
// calls from older toolchains entirely and activates them automatically once
// the project is built with Xcode 16+. Until then both modifiers are no-ops.
private extension View {
    @ViewBuilder
    func zoomTransitionSource(id: String, in namespace: Namespace.ID) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func zoomTransition(sourceID: String, in namespace: Namespace.ID) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#Preview {
    FeedView()
        .modelContainer(for: WordInteraction.self, inMemory: true)
}
