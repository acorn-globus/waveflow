//
//  GranolaCloneApp.swift
//  GranolaClone
//
//  Created by Partha Praharaj on 07/01/25.
//

import SwiftUI
import SwiftData
import AVFoundation

@main
struct GranolaCloneApp: App {
    @StateObject private var menuBarManager = MenuBarManager()
    @StateObject private var permissionsManager = AudioPermissionsManager()
    @StateObject private var transcriptionManager = TranscriptionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(menuBarManager)
                .environmentObject(permissionsManager)
                .environmentObject(transcriptionManager)
        }
    }
}
