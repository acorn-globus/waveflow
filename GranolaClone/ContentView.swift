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

    var body: some View {
        VStack(spacing: 20) {
            if menuBarManager.isListening {
                ListeningIndicator()
            }

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


            if permissionsManager.microphonePermissionGranted && permissionsManager.systemAudioPermissionGranted {
                Text("All permissions granted!")
                    .foregroundColor(.green)
                    .padding()
            }
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}
