import SwiftUI

@available(macOS 15.0, *)
struct TranscriptionView: View {
    @ObservedObject var transcriptionManager: TranscriptionManager
    @EnvironmentObject private var menuBarManager: MenuBarManager
    
    var body: some View {
        VStack(spacing: 16) {
            if menuBarManager.isListening {
                HStack {
                    Text("Transcribing...")
                        .foregroundColor(.secondary)
                    if !transcriptionManager.currentText.isEmpty {
                        Text("• Processing...")
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Confirmed text
                    if !transcriptionManager.confirmedText.isEmpty {
                        Text(transcriptionManager.confirmedText)
                            .fontWeight(.medium)
                    }
                    
                    // Hypothesis text (current processing)
                    if !transcriptionManager.hypothesisText.isEmpty {
                        Text(transcriptionManager.hypothesisText)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    // Current processing text
                    if !transcriptionManager.currentText.isEmpty {
                        Text(transcriptionManager.currentText)
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                            .italic()
                            .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            
            HStack {
                Text("\(transcriptionManager.transcribedText.split(separator: " ").count) words")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Spacer()
                
                Button("Copy") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcriptionManager.transcribedText, forType: .string)
                    #endif
                }
                .disabled(transcriptionManager.transcribedText.isEmpty)
                
                Button("Clear") {
                    transcriptionManager.transcribedText = ""
                    transcriptionManager.confirmedText = ""
                    transcriptionManager.hypothesisText = ""
                    transcriptionManager.currentText = ""
                }
                .disabled(transcriptionManager.transcribedText.isEmpty)
            }
        }
        .padding()
    }
}
