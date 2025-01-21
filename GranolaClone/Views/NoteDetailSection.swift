import SwiftUI
import SwiftData

struct NoteDetailSection: View {
    @Bindable var note: Note
    @State private var copiedMessage = ""
    @State private var selectedTab: Tab = .summary
        
    enum Tab: String {
        case summary = "Summary"
        case body = "Body"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 16) {
                if(!note.summary.isEmpty){
                    Picker("", selection: $selectedTab) {
                        Text("Summary").tag(Tab.summary)
                        Text("Body").tag(Tab.body)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                }
                
                Form {
                    TextField("Title", text: $note.title)
                    if selectedTab == .summary && !note.summary.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading) {
                                Text(LocalizedStringKey(note.summary))
                            }
                        }.background(Color(.textBackgroundColor))
                        Button(action: {
                            copyToClipboard(note.summary)
                            copiedMessage = "Text copied to clipboard!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedMessage = "" // Clear the message after 2 seconds
                            }
                        }) {
                            Label("Copy Text", systemImage: "doc.on.doc")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        if !copiedMessage.isEmpty {
                            Text(copiedMessage)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    } else {
                        TextEditor(text: $note.body)
                            .font(.body)
                            .padding()
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                    }
                    
                }
            }
            TranscriptionSection(currentNote: note)
        }
        .navigationTitle(note.title)
    }
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

//#Preview {
//    NoteDetailSection(note: .init(title: "Example", body: "This is an example note."))
//}
