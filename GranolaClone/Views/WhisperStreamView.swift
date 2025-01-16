import SwiftUI
import WhisperKit

struct WhisperStreamView: View {
    @StateObject private var manager = WhisperManager()
    
    var body: some View {
        VStack(spacing: 20) {
            if !manager.isModelLoaded {
                loadingView
            } else {
                transcriptionView
            }
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Text("Loading WhisperKit Model...")
                .font(.headline)
            
            ProgressView(value: manager.downloadProgress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 300)
            
            Text(manager.modelState.description)
                .foregroundColor(.secondary)
        }
    }
    
    private var transcriptionView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                // Microphone Transcription
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Microphone")
                            .font(.headline)
                    }
                    .foregroundColor(.blue)
                    
                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            Text(manager.micConfirmedText)
                                .fontWeight(.bold)
                            + Text(manager.micHypothesisText)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // System Audio Transcription
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                        Text("System Audio")
                            .font(.headline)
                    }
                    .foregroundColor(.purple)
                    
                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            Text(manager.systemConfirmedText)
                                .fontWeight(.bold)
                            + Text(manager.systemHypothesisText)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            Button(action: {
                manager.toggleRecording()
            }) {
                HStack {
                    Image(systemName: manager.isRecording ? "stop.circle.fill" : "record.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundColor(manager.isRecording ? .red : .green)
                    
                    Text(manager.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            if manager.isRecording {
                Text("Recording both microphone and system audio...")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}
