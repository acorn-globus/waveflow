import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var permissionsManager: AudioPermissionsManager
    @EnvironmentObject private var whisperManager: WhisperManager
    @EnvironmentObject private var ollamaManager: OllamaManager
    
    var body: some View {
        VStack(spacing: 20) {
            if !permissionsManager.microphonePermissionGranted || !permissionsManager.systemAudioPermissionGranted {
                PermissionSection()
            }
            else if !whisperManager.isModelLoaded || !ollamaManager.isModelLoaded{
                ModelDownloadSection()
            } else {
                NotesListSection()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
    }
}

#Preview {
    ContentView()
}

