//
//  GranolaCloneApp.swift
//  GranolaClone
//
//  Created by Partha Praharaj on 07/01/25.
//

import SwiftUI
import SwiftData

@available(macOS 15.0, *)
@main
struct GranolaCloneApp: App {
    @StateObject private var menuBarManager = MenuBarManager()
    @StateObject private var permissionsManager = AudioPermissionsManager()
    @StateObject private var whisperManager = WhisperManager()
    @StateObject private var ollamaManager = OllamaManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(menuBarManager)
                .environmentObject(permissionsManager)
                .environmentObject(whisperManager)
                .environmentObject(ollamaManager)
        }
        .modelContainer(for: Note.self)
    }
}
