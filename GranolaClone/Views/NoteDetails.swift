import SwiftUI
import SwiftData

struct NoteDetails: View {
    @Bindable var note: Note
    var body: some View {
        VStack {
            Form {
                TextField("Title", text: $note.title)
                TextField("Body", text: $note.body, axis: .vertical)
            }
            WhisperStreamView(currentNote: note)
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
 
