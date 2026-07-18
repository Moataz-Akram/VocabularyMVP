//
//  VocabularyMVPApp.swift
//  VocabularyMVP
//
//  Created by Moataz Akram on 16/07/2026.
//

import SwiftUI
import SwiftData

@main
struct VocabularyMVPApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WordInteraction.self, WordCollection.self])
    }
}
