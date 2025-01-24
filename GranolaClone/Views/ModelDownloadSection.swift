import SwiftUI
import WhisperKit

struct ModelDownloadSection: View {
    @EnvironmentObject private var whisperManager: WhisperManager
    @EnvironmentObject private var ollamaManager: OllamaManager
    
    @State private var previousWhisperProgress: Float = 0.0
    @State private var previousOllamaProgress: Float = 0.0
    @State private var showWarning: Bool = false
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 16) {
            if(!whisperManager.isModelLoaded){
                Text("Loading WhisperKit Model...")
                    .font(.headline)
                
                ProgressView(value: whisperManager.downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 300)
                
                Text(whisperManager.modelState.description)
                    .foregroundColor(.secondary)
                Text("This is a one time process. Whisper Small model will be downloaded and stored locally on your device.")
                    .foregroundColor(.secondary)
            } else {
                Text("Loading Ollama Model...")
                    .font(.headline)
                
                ProgressView(value: ollamaManager.downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 300)
                
                Text("This is a one time process. Llama3.2:3b model will be downloaded and stored locally on your device.")
                    .foregroundColor(.secondary)
            }
            
            if showWarning {
                Text("Download seems to be stalled. Please restart the app. To close the app, press ⌘ + Q.")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .onAppear {
            startMonitoringProgress()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startMonitoringProgress() {
            timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
                Task { @MainActor in
                    if !whisperManager.isModelLoaded {
                        if whisperManager.downloadProgress == previousWhisperProgress {
                            showWarning = true
                        } else {
                            showWarning = false
                            previousWhisperProgress = whisperManager.downloadProgress
                        }
                    } else {
                        if ollamaManager.downloadProgress == previousOllamaProgress {
                            showWarning = true
                        } else {
                            showWarning = false
                            previousOllamaProgress = ollamaManager.downloadProgress
                        }
                    }
                }
            }
    }
}
