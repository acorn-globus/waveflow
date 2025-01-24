//
//  WaveflowApp.swift
//  Waveflow
//
//  Created by Partha Praharaj on 24/01/25.
//

import SwiftUI
import SwiftData

@main
struct WaveflowApp: App {
    @StateObject private var menuBarManager = MenuBarManager()
    @StateObject private var permissionsManager = AudioPermissionsManager()
    @StateObject private var whisperManager = WhisperManager()
    @StateObject private var ollamaManager = OllamaManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(menuBarManager)
                .environmentObject(permissionsManager)
                .environmentObject(whisperManager)
                .environmentObject(ollamaManager)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: Note.self)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // App is entering background state, clean up resources
                ollamaManager.shutdown()
            }
        }
    }
}
