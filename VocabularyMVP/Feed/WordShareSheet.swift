import SwiftUI

@MainActor
struct WordShareSheet: View {
    let word: Word

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?
    @State private var savedToPhotos = false
    @State private var showsActivitySheet = false

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Theme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                Spacer()
            }
            Spacer()
            card
                .hardShadow(in: RoundedRectangle(cornerRadius: 28))
            Spacer()
            actions
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task {
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3
            rendered = renderer.uiImage
        }
    }

    // Fixed light palette so the exported image looks the same in dark mode.
    private var card: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(word.word)
                .font(.system(size: 38, weight: .bold, design: .serif))
            Text(word.phonetic)
                .font(.system(.subheadline, design: .rounded))
                .opacity(0.7)
            Text("(\(word.partOfSpeech)) \(word.definition)")
                .font(.system(.title3, design: .rounded))
            Text(word.examples.first ?? "")
                .font(.system(.body, design: .rounded))
                .opacity(0.8)
            Spacer()
            Text("VocabularyMVP")
                .font(.system(.caption, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.06), in: Capsule())
                .opacity(0.7)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.1))
        .padding(28)
        .frame(width: 300, height: 440)
        .background(Color(red: 0.94, green: 0.93, blue: 0.89),
                    in: RoundedRectangle(cornerRadius: 28))
    }

    private var actions: some View {
        HStack(spacing: 20) {
            action(savedToPhotos ? "checkmark" : "arrow.down.to.line",
                   savedToPhotos ? "Saved" : "Save image") {
                guard let rendered else { return }
                UIImageWriteToSavedPhotosAlbum(rendered, nil, nil, nil)
                savedToPhotos = true
                Haptics.success()
            }
            action("doc.on.doc", "Copy text") {
                UIPasteboard.general.string = shareText
                Haptics.selection()
            }
            action("square.and.arrow.up", "Share") {
                showsActivitySheet = true
            }
        }
        .sheet(isPresented: $showsActivitySheet) {
            ActivitySheet(items: rendered.map { [$0] } ?? [shareText])
                .presentationDetents([.medium, .large])
        }
    }

    private var shareText: String {
        "\(word.word) (\(word.partOfSpeech)) — \(word.definition)\n“\(word.examples.first ?? "")”"
    }

    private func action(_ symbol: String, _ title: String, handler: @escaping () -> Void) -> some View {
        Button(action: handler) {
            actionLabel(symbol, title)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .frame(width: 56, height: 56)
                .background(Theme.surface, in: Circle())
            Text(title)
                .font(.system(.caption, design: .rounded))
        }
        .foregroundStyle(Theme.textPrimary)
    }
}

// System share sheet, so sharing offers the user's messaging and social apps.
private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
