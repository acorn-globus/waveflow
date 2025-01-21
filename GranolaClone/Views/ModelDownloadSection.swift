import SwiftUI
import WhisperKit

struct ModelDownloadSection: View {
    @EnvironmentObject private var whisperManager: WhisperManager
    @EnvironmentObject private var ollamaManager: OllamaManager
    
    var body: some View {
        if(!whisperManager.isModelLoaded){
            VStack(spacing: 16) {
                Text("Loading WhisperKit Model...")
                    .font(.headline)
                
                ProgressView(value: whisperManager.downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 300)
                
                Text(whisperManager.modelState.description)
                    .foregroundColor(.secondary)
                Text("This is a one time process. Whisper Small model will be downloaded and stored locally on your device.")
                    .foregroundColor(.secondary)
            }
        } else {
            VStack(spacing: 16) {
                Text("Loading Ollama Model...")
                    .font(.headline)
                
                ProgressView(value: ollamaManager.downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 300)
                
                Text("This is a one time process. Llama3.2:3b model will be downloaded and stored locally on your device.")
                    .foregroundColor(.secondary)
            }
        }
    }
}
