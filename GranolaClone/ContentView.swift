//
//  ContentView.swift
//  GranolaClone
//
//  Created by Partha Praharaj on 07/01/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var permissionsManager: AudioPermissionsManager
    @EnvironmentObject private var transcriptionManager: TranscriptionManager

    var body: some View {
        VStack(spacing: 20) {
            if menuBarManager.isListening {
                ListeningIndicator()
            }
            if !permissionsManager.microphonePermissionGranted || !permissionsManager.systemAudioPermissionGranted {
                Text("Audio Permissions")
                    .font(.title)
                    .padding()

                PermissionSection(
                    title: "Microphone Access",
                    granted: permissionsManager.microphonePermissionGranted,
                    action: permissionsManager.requestMicrophonePermission
                )
                PermissionSection(
                    title: "Screen Recording Access",
                    granted: permissionsManager.systemAudioPermissionGranted,
                    action: permissionsManager.requestSystemAudioPermission
                )
            }
            else if !transcriptionManager.isInitialized {
                // Show loading view while WhisperKit initializes
                ProgressView("Initializing WhisperKit...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                // Show transcription view
                TranscriptionView(transcriptionManager: transcriptionManager)
            }
        }
        .frame(width: 600, height: 400)
        .onChange(of: menuBarManager.isListening) { _, isListening in
            print("ContentView menuBarManager.isListening changed to \(isListening)")
            if isListening {
                print("Starting recording...CV")
                transcriptionManager.startRecording()
            } else {
                print("STOP recording...CV")
                transcriptionManager.stopRecording()
            }
        }
        .onAppear {
            print("ContentView appeared")
            print("Initial menuBarManager.isListening state: \(menuBarManager.isListening)")
        }
    }
}

#Preview {
    ContentView()
}
