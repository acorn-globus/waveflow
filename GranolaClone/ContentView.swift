//
//  ContentView.swift
//  GranolaClone
//
//  Created by Partha Praharaj on 07/01/25.
//

import SwiftUI
import SwiftData

@available(macOS 15.0, *)
struct ContentView: View {
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var permissionsManager: AudioPermissionsManager
    @StateObject private var manager = WhisperManager()

    var body: some View {
        VStack(spacing: 20) {
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
            else if !manager.isModelLoaded {
                ModelDownload(manager: manager)
            } else {
                NotesList()
            }
        }
        .frame(width: 600, height: 400)
//        .onChange(of: menuBarManager.isListening) { _, isListening in
//            if isListening {
//                print("Starting recording...CV")
//                transcriptionManager.startRecording()
//            } else {
//                transcriptionManager.stopRecording()
//            }
//        }
    }
}

#Preview {
    if #available(macOS 15.0, *) {
        ContentView()
    } 
}
