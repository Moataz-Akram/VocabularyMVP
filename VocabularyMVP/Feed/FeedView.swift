import SwiftUI
import SwiftData

@MainActor
struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FeedViewModel()
    @State private var scrolledWordID: String?
    @State private var detailWord: Word?
    @State private var shareWord: Word?
    @State private var showsSettings = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .overlay(alignment: .topLeading) { profileButton }
            .sheet(item: $detailWord) { word in
                WordDetailSheet(word: word, voiceID: viewModel.voiceID)
            }
            .fullScreenCover(item: $shareWord) { word in
                WordShareSheet(word: word)
            }
            .fullScreenCover(isPresented: $showsSettings) {
                ProfileSheet(viewModel: viewModel)
            }
            .task { await viewModel.start(context: modelContext) }
            .onChange(of: scrolledWordID) { _, newID in
                Haptics.stepAdvance()
                viewModel.markSeen(wordID: newID)
                viewModel.loadMoreIfNeeded(nearWordID: newID)
            }
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

    private var profileButton: some View {
        Button {
            showsSettings = true
        } label: {
            Image(systemName: "person")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: Circle())
                .hardShadow(in: Circle(), offset: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityLabel("Profile and settings")
    }
}

#Preview {
    FeedView()
        .modelContainer(for: WordInteraction.self, inMemory: true)
}
