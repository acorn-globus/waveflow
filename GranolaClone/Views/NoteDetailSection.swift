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
            1. Create a relevant and descriptive title for the summary and include it in the first line in a `#` tag. 
            2. Use meaningful subheadings to organize key points clearly and logically.
            3. Highlight important details, decisions, and action items using bullet points under each subheading.
            4. Thoughtfully integrate the notes provided by the user into the summary to enhance its quality.
            5. Return the output strictly in Markdown format without any introductory or closing remarks.
        
            ### Transcript
            \(transcript)
            
            ### User Notes
            \(note.body)
        """
        
        try? await ollamaManager.generateResponse(prompt: prompt)
    }
}

#Preview {
    NoteDetailSection(note: .init(title: "Example", body: "This is an example note.", summary: """
Converting Markdown into HTML
To get started with Ink, all you have to do is to import it, and use its MarkdownParser type to convert any Markdown string into efficiently rendered HTML:

import Ink
- dsafafaa
- To get started with Ink, all you have to do is to import it, and use its MarkdownParser type to convert any Markdown string into efficiently rendered HTML:
        * adsfsdf
        * dsffdsa

```
    let markdown: String = ...
    let parser = MarkdownParser()
    let html = parser.html(from: markdown)
```
That’s it! The resulting HTML can then be displayed as-is, or embedded into some other context — and if that’s all you need Ink for, then no more code is required.
Converting Markdown into HTML
To get started with Ink, all you have to do is to import it, and use its MarkdownParser type to convert any Markdown string into efficiently rendered HTML:

import Ink
- dsafafaa
- To get started with Ink, all you have to do is to import it, and use its MarkdownParser type to convert any Markdown string into efficiently rendered HTML:
        * adsfsdf
        * dsffdsa

```
    let markdown: String = ...
    let parser = MarkdownParser()
    let html = parser.html(from: markdown)
```
That’s it! The resulting HTML can then be displayed as-is, or embedded into some other context — and if that’s all you need Ink for, then no more code is required.
Converting Markdown into HTML
To get started with Ink, all you have to do is to import it, and use its MarkdownParser type to convert any Markdown string into efficiently rendered HTML:

import Ink
- dsafafaa
- To get started with Ink, all you have to do is to import it, and use its MarkdownParser type to convert any Markdown string into efficiently rendered HTML:
        * adsfsdf
        * dsffdsa

```
    let markdown: String = ...
    let parser = MarkdownParser()
    let html = parser.html(from: markdown)
```
That’s it! The resulting HTML can then be displayed as-is, or embedded into some other context — and if that’s all you need Ink for, then no more code is required.
"""))
}
