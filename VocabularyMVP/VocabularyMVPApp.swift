//
//  VocabularyMVPApp.swift
//  VocabularyMVP
//
//  Created by Moataz Akram on 16/07/2026.
//

import SwiftUI
import SwiftData

@main
@MainActor
struct VocabularyMVPApp: App {
    private let container: ModelContainer
    @State private var interactions: InteractionsStore
    @State private var voiceSettings = VoiceSettings()

    init() {
        do {
            container = try ModelContainer(for: WordInteraction.self, WordCollection.self)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
        _interactions = State(initialValue: InteractionsStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(interactions)
                .environment(voiceSettings)
        }
        .modelContainer(container)
    }
}
