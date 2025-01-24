import SwiftUI
import SwiftData
import WhisperKit

struct TranscriptionSection: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject private var whisperManager: WhisperManager
    @EnvironmentObject private var ollamaManager: OllamaManager

    var currentNote: Note

    @Query(sort: \TranscriptionMessage.createdAt) var messages: [TranscriptionMessage]
    @State private var currentMicText: TranscriptionMessage?
    @State private var currentSystemText: TranscriptionMessage?
    
    init(currentNote: Note) {
        self.currentNote = currentNote
        let id = currentNote.id
        let predicate = #Predicate<TranscriptionMessage> { message in
            message.note?.id == id
        }
        
        _messages = Query(filter: predicate, sort: [SortDescriptor(\.createdAt)] )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !whisperManager.isModelLoaded {
                VStack(spacing: 16) {
                    Text("Loading WhisperKit Model...")
                        .font(.headline)
                    
                    ProgressView(value: whisperManager.downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 300)
                    
                    Text(whisperManager.modelState.description)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                let isLastIndex = message.id == messages.last?.id
                                if currentSystemText != nil {
                                    MessageBubble(message: message, hypothesisText: isLastIndex ? whisperManager.systemHypothesisText: "")
                                }
                                else {
                                    MessageBubble(message: message, hypothesisText: isLastIndex ? whisperManager.micHypothesisText: "")
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondaryBackground))
        .onChange(of: whisperManager.micConfirmedTextReset) {  _, micText in
            guard !micText.isEmpty else { return }

            currentSystemText = nil
            if currentMicText == nil{
                currentMicText = TranscriptionMessage(source: .microphone, text: micText, note: currentNote)
            }else{
                currentMicText?.text += " \(micText)"
            }
            modelContext.insert(currentMicText!)
        }
        .onChange(of: whisperManager.systemConfirmedTextReset) { _, systemText in
            guard !systemText.isEmpty else { return }

            currentMicText = nil
            if currentSystemText == nil{
                currentSystemText = TranscriptionMessage(source: .system, text: systemText, note: currentNote)
            }else{
                currentSystemText?.text += " \(systemText)"
            }
            modelContext.insert(currentSystemText!)
        }
        .onChange(of: ollamaManager.summaryData) { _, summaryData in
            currentNote.summary.append(contentsOf: summaryData)
            modelContext.insert(currentNote)
        }
        .onChange(of: ollamaManager.isGeneratingSummary) { _, isGenerating in
            if !isGenerating {
                currentNote.title = extractTitle(currentNote.summary)
                modelContext.insert(currentNote)
            }
        }
    }
    
    func extractTitle(_ summary: String) -> String {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for the first line that starts with a Markdown heading (`# `)
            if let titleLine = trimmedSummary.split(separator: "\n").first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") }) {
                // Remove the `# ` prefix to get the title text
                return titleLine.replacingOccurrences(of: "# ", with: "").trimmingCharacters(in: .whitespaces)
            }
            
            return "Untitled" // Default title if no heading is found
    }
}
