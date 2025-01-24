import SwiftUI
import SwiftData
import MarkdownUI

struct NoteDetailSection: View {
    @Bindable var note: Note
    @State private var copiedMessage = ""
    @State private var selectedTab: Tab = .summary
    @EnvironmentObject private var whisperManager: WhisperManager
    @EnvironmentObject private var ollamaManager: OllamaManager
    @Query(sort: \TranscriptionMessage.createdAt) private var messages: [TranscriptionMessage]
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isBodyFocused: Bool
    @State private var isTextCopied: Bool = false
        
    init(note: Note) {
        self._note = Bindable(wrappedValue: note)
        let id = note.id
        let predicate = #Predicate<TranscriptionMessage> { message in
            message.note?.id == id
        }
        
        _messages = Query(filter: predicate, sort: [SortDescriptor(\.createdAt)] )
    }
    
    enum Tab: String, CaseIterable {
        case body = "My Notes"
        case summary = "AI Generated"
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ZStack{
                    ScrollView {
                        VStack(alignment: .leading) {
                            if selectedTab == Tab.summary && !note.summary.isEmpty {
                                Markdown(note.summary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                            }else{
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $note.title)
                                        .font(.title)
                                        .background(Color.clear)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 0)
                                        .focused($isTitleFocused)
                                    if note.title.isEmpty {
                                        Text("Untitled Meeting")
                                            .font(.title)
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 5)
                                            .onTapGesture {
                                                isTitleFocused = true
                                            }
                                    }

                                }
                                .padding(.bottom, 4)
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $note.body)
                                        .frame(maxHeight: .infinity, alignment: .leading)
                                        .font(.body)
                                        .focused($isBodyFocused)
                                        .onAppear {
                                            isBodyFocused = true
                                        }
                                    if note.body.isEmpty {
                                        Text("Enter Your Notes Here...")
                                            .font(.body)
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 6)
                                            .onTapGesture {
                                                isBodyFocused = true
                                            }
                                    }
                                }
                            }

                            if ollamaManager.isGeneratingSummary {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 240, height: 48)
                                        .cornerRadius(8)
                                        .overlay(
                                            Rectangle()
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.blue.opacity(0.0),
                                                            Color.blue.opacity(0.06),
                                                            Color.blue.opacity(0.18),
                                                        ]),
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    ),
                                                    lineWidth: 1.25
                                                )
                                                .cornerRadius(8)
                                        )
                                    HStack{
                                        ProgressView()
                                            .frame(width: 20, height: 20)
                                            .padding(.trailing, 12)
                                        Text("Generating Summary...")
                                    }
                                    .padding(.horizontal ,24)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .padding(48)
                        .padding(.bottom, 64)
                    }
                    if selectedTab == Tab.summary {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    isTextCopied = true
                                    copyToClipboard(note.summary)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        isTextCopied = false
                                    }
                                }) {
                                    Image(systemName: isTextCopied ? "checkmark.circle" : "doc.on.doc")
                                        .padding(2)
                                }.offset(x: -10, y: 10)
                            }
                            Spacer()
                        }
                    }
                    
                    if(!note.summary.isEmpty){
                        VStack {
                            Spacer()
                            CustomPickerView()
                        }.padding()
                    }
                    else if(!ollamaManager.isGeneratingSummary){
                        VStack {
                            Spacer()
                            HStack {
                                Button(action: {
                                    whisperManager.toggleRecording()
                                }) {
                                    Image(systemName: whisperManager.isRecording ? "pause.fill" : "play.fill")
                                        .frame(width: 44, height: 44)
                                        .foregroundColor(whisperManager.isRecording ? .red : .green)
                                    Text(whisperManager.isRecording ? "Stop" : "Record")
                                        .padding(.trailing, 8)
                                }
                                .cornerRadius(100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 100)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                if !whisperManager.isRecording && !note.messages.isEmpty {
                                    Button(action: {
                                        Task {
                                            await generateSummary()
                                        }
                                    }) {
                                        Image(systemName: "sparkles")
                                            .frame(width: 44, height: 44)
                                        Text("Generate Summary")
                                            .padding(.trailing, 8)
                                    }
                                    .background(Color.blue)
                                    .cornerRadius(100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 100)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                        }.padding()
                    }
                }
                .frame(width: geometry.size.width * 0.6)
                .background(Color(.textBackgroundColor))
                Divider().layoutPriority(0)
                TranscriptionSection(currentNote: note)
                    .frame(width: geometry.size.width * 0.4)

            }
            .navigationTitle(note.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if whisperManager.isRecording || ollamaManager.isGeneratingSummary || !note.summary.isEmpty { return }
            whisperManager.toggleRecording()
        }
        .onTapGesture {
            isTitleFocused = false
            isBodyFocused = false
        }
    }
    
    @ViewBuilder
    private func CustomPickerView() -> some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { tab in
                segment(for: tab)
            }
        }
        .frame(width: 260)
        .padding(6)
        .background(Color(.secondaryBackground))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func segment(for tab: Tab) -> some View {
        HStack{
            Image(systemName: tab == .body ?"list.bullet": "sparkles")
            Text(tab.rawValue)
        }
        .foregroundColor(selectedTab == tab ? .white : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedTab == tab ? Color.blue : Color(.secondaryBackground))
            .cornerRadius(20)
            .onTapGesture {
                withAnimation {
                    selectedTab = tab
                }
            }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func generateSummary() async {
        guard !whisperManager.isRecording else { return }

        var transcript = ""
        
        for message in messages {
            let currentMessage = "\(message.source.capitalized): \(message.text) \n"
            transcript += currentMessage
        }
        
        let prompt = """
            Summarize the provided meeting transcript to highlight key points, focus on creating a clear and engaging summary in Markdown format following the given instructions.
        
            # Important Instructions 
            1. Title Creation: Create a descriptive and contextually relevant title for the summary and include it in the first line using a # tag. If the meeting context is unclear, generate a general title based on the transcript content.
            2. Context-Aware Structure: Automatically adapt the structure of the summary based on the transcript's topics and context.
            2. Organized Subheadings: Use meaningful subheadings to group key points logically, reflecting the flow and purpose of the meeting.
            3. Highlight Key Points: Under each subheading, include:
                    - Important details and insights discussed during the meeting.
                    - For each key point,try including relevant subpoints or additional details to add depth and clarity.
            4. User Notes Integration: Seamlessly incorporate the provided user notes to enhance the summary’s clarity and depth.
            5. Return the output strictly in Markdown format without any introductory or closing remarks.
        
            # Input: 
            - Transcript: \(transcript)

            - User Notes: \(note.body)
        
            # Output: 
            Return the summary strictly in Markdown format without any introductory or closing remarks. Ensure the inclusion of all specified elements, especially the title.
        """
        
        try? await ollamaManager.generateResponse(prompt: prompt)
    }
}
