import SwiftUI
import SwiftData

struct NoteDetails: View {
    @Bindable var note: Note
    var body: some View {
        HStack {
            Form {
                TextField("Title", text: $note.title)
                TextEditor(text: $note.body)
                    .font(.body)
                    .padding()
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
            }
            TranscriptionSection(currentNote: note)
        }
        .navigationTitle(note.title)
    }
}

//#Preview {
//    do {
//        let config =  ModelConfiguration(isStoredInMemoryOnly: true)
//        let container =  try ModelContainer(for: Note.self,configuration: config)
//        let example = Note(title: "Example", body: "This is an example note.")
//        
//        NoteDetails(note: example)
//    } catch {
//        fatalError("Error creating preview: \(error)")
//    }
//}
