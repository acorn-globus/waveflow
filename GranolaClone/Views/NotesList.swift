import SwiftUI
import SwiftData

struct NotesList: View {
    @Environment(\.modelContext) var modelContext
    @Query var notes: [Note]
    @State private var path = [Note]()
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        VStack(alignment: .leading) {
                            Text(note.title)
                                .font(.headline)
                            Text(note.createdAt.formatted(date: .long, time: .shortened))
                        }
                    }
                }
                .onDelete(perform: deleteNote)
            }
            .navigationTitle("Notes List")
            .navigationDestination(for: Note.self, destination: NoteDetails.init)
            .toolbar {
                Button("Add", systemImage: "plus", action: addNote)
            }
        }
    }
    
    func addNote() {
        let newNote = Note(title: "Untitled", body: "")
        modelContext.insert(newNote)
        path = [newNote]
    }
    
    func deleteNote(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(notes[index])
        }
    }
}

#Preview {
    NotesList()
}
 
