//
//  PermissionSection.swift
//  GranolaClone
//
//  Created by Partha Praharaj on 07/01/25.
//

import SwiftUI

struct PermissionSection: View {
    @EnvironmentObject private var permissionsManager: AudioPermissionsManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Audio Permissions")
                .font(.title)
                .padding()
            HStack {
                Text("Microphone Access")
                Spacer()
                if !permissionsManager.microphonePermissionGranted {
                    Button("Request Permission") {
                        permissionsManager.requestMicrophonePermission()
                    }
                    .buttonStyle(.borderedProminent)
                }else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
            }
            HStack {
                Text("Screen Recording Access")
                Spacer()
                if !permissionsManager.systemAudioPermissionGranted {
                    Button("Request Permission") {
                        permissionsManager.requestSystemAudioPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal)
        .frame(width: 600)
    }
}

#Preview {
    PermissionSection()
}
