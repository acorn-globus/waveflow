import SwiftUI
import SwiftData
import WhisperKit

struct TranscriptionSection: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject private var whisperManager: WhisperManager
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
                loadingView
            } else {
                chatView
            }
        }
        .padding()
        .onChange(of: whisperManager.micConfirmedTextReset) {  _, micText in
            guard micText != "" else { return }

            currentSystemText = nil
            if currentMicText == nil{
                currentMicText = TranscriptionMessage(source: .microphone, text: micText, note: currentNote)
            }else{
                currentMicText?.text += " \(micText)"
            }
            modelContext.insert(currentMicText!)
        }
        .onChange(of: whisperManager.systemConfirmedTextReset) { _, systemText in
            guard systemText != "" else { return }

            currentMicText = nil
            if currentSystemText == nil{
                currentSystemText = TranscriptionMessage(source: .system, text: systemText, note: currentNote)
            }else{
                currentSystemText?.text += " \(systemText)"
            }
            modelContext.insert(currentSystemText!)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Text("Loading WhisperKit Model...")
                .font(.headline)
            
            ProgressView(value: whisperManager.downloadProgress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 300)
            
            Text(whisperManager.modelState.description)
                .foregroundColor(.secondary)
        }
    }
    
    private var chatView: some View {
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
            
            Button(action: {
                whisperManager.toggleRecording()
            }) {
                HStack {
                    Image(systemName: whisperManager.isRecording ? "stop.circle.fill" : "record.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundColor(whisperManager.isRecording ? .red : .green)
                    
                    Text(whisperManager.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
            }
    }
}
