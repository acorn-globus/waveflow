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
                    if currentNote.summary.isEmpty {
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
                    if !whisperManager.isRecording {
                        Button("Generate Summary",action: {
                            Task {
                                await generateSummary()
                            }
                        })
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
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
    }
    
    private func generateSummary() async {
        guard !whisperManager.isRecording else { return }
        currentNote.summary = ""
        modelContext.insert(currentNote)

        var transcript = ""
        
        for message in messages {
            let currentMessage = "\(message.source.capitalized): \(message.text) \n"
            transcript += currentMessage
        }
        
        let prompt = """
            Summarize the provided meeting transcript to highlight key points, focus on creating a clear and engaging summary in Markdown format following the given instructions.
        
            # Important Instructions 
            1. Create a relevant and descriptive title for the summary and include it in the first line in a `#` tag. 
            2. Use meaningful subheadings to organize key points clearly and logically.
            3. Highlight important details, decisions, and action items using bullet points under each subheading.
            4. Thoughtfully integrate the notes provided by the user into the summary to enhance its quality.
            5. Return the output strictly in Markdown format without any introductory or closing remarks.
        
            ### Transcript
            \(transcript)
            
            ### User Notes
            \(currentNote.body)
        """
        
        try? await ollamaManager.generateResponse(prompt: prompt)
    }
}
