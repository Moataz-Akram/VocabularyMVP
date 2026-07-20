import SwiftUI

@MainActor
struct WordShareSheet: View {
    let word: Word

    @State private var rendered: UIImage?
    @State private var savedToPhotos = false
    @State private var showsActivitySheet = false

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                CloseButton()
                Spacer()
            }
            
            Spacer()
            
            framedCard
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            
            Spacer()
            
            actions
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task {
            let renderer = ImageRenderer(content: framedCard)
            renderer.scale = 3
            rendered = renderer.uiImage
        }
    }

    private var framedCard: some View {
        card
            .padding(1)
            .background(.white, in: RoundedRectangle(cornerRadius: 29))
    }

    private var card: some View {
        VStack(spacing: 18) {
            Spacer()
            
            Text(word.word)
                .font(.system(size: 34, weight: .bold, design: .serif))
            
            if let phonetic = word.phonetic {
                Text(phonetic)
                    .font(.system(size: 14, design: .rounded))
                    .opacity(0.7)
            }
            
            if let definitionLine = word.definitionLine {
                Text(definitionLine)
                    .font(.system(size: 18, design: .rounded))
            }
            
            if let example = word.examples?.first {
                Text(example)
                    .font(.system(size: 15, design: .rounded))
                    .opacity(0.8)
            }
            
            watermark
                .padding(.top, 12)
            
            Spacer()
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.1))
        .padding(28)
        .frame(width: 340, height: 490)
        .background(Color(red: 0.94, green: 0.93, blue: 0.89),
                    in: RoundedRectangle(cornerRadius: 28))
    }

    private var watermark: some View {
        HStack(spacing: 6) {
            Text("v")
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .frame(width: 18, height: 18)
                .background(.white, in: RoundedRectangle(cornerRadius: 5))
            
            Text("vocabularymvp.app")
                .font(.system(.caption, design: .rounded))
        }
        .foregroundStyle(Color(red: 0.11, green: 0.11, blue: 0.1).opacity(0.55))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
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
        var text = [word.word, word.definitionLine].compactMap { $0 }.joined(separator: " — ")
        if let example = word.examples?.first {
            text += "\n“\(example)”"
        }
        return text
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
