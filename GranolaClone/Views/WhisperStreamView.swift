import SwiftUI
import SwiftData
import WhisperKit

struct WhisperStreamView: View {
    @Environment(\.modelContext) var modelContext
    @StateObject private var whisperManager = WhisperManager()
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
                // transcriptionView
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
    
    private var transcriptionView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                // Microphone Transcription
                Text(currentNote.title)
                VStack(alignment: .leading, spacing: 10) {
                   
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Microphone")
                            .font(.headline)
                    }
                    .foregroundColor(.blue)
                    
                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            Text(whisperManager.micConfirmedText)
                                .fontWeight(.bold)
                            + Text(whisperManager.micHypothesisText)
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
                            Text(whisperManager.systemConfirmedText)
                                .fontWeight(.bold)
                            + Text(whisperManager.systemHypothesisText)
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
            
            if whisperManager.isRecording {
                Text("Recording both microphone and system audio...")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private var chatView: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        let isLastIndex = message.id == messages.last?.id
                        if currentSystemText != nil {
                            MessageBubbleView(message: message, hypothesisText: isLastIndex ? whisperManager.systemHypothesisText: "")
                        }
                        else {
                            MessageBubbleView(message: message, hypothesisText: isLastIndex ? whisperManager.micHypothesisText: "")
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


struct MessageBubbleView: View {
    let message: TranscriptionMessage
    let hypothesisText: String
    
    var body: some View {
        HStack {
            if message.source == "microphone" {
                Spacer()
            }
            
            VStack(alignment: message.source == "microphone" ? .trailing : .leading) {
                HStack(alignment: .top, spacing: 0) {
                    Text("\(Text(message.text).fontWeight(.bold)) \(Text(hypothesisText).fontWeight(.light))")
                }
                .padding()
                .background(message.source == "microphone" ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(12)
                
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
            }
            .frame(alignment: message.source == "microphone" ? .trailing : .leading)
            
            if message.source == "system" {
                Spacer()
            }
        }
    }
}
