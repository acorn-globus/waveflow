import SwiftUI
import SwiftData

struct NotesListSection: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var whisperManager: WhisperManager
    @Query(sort: \Note.createdAt) var notes: [Note]
    @State private var path = [Note]()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(notes) { note in
                    VStack(alignment: .leading) {
                        NavigationLink(value: note) {
                            Text(note.title)
                                .font(.headline)

                        }
                        Text(note.createdAt.formatted(date: .long, time: .shortened))
                    }
                }
                .onDelete(perform: deleteNote)
            }
            .navigationTitle("Notes List")
            .navigationDestination(for: Note.self, destination: NoteDetailSection.init)
            .toolbar {
                Button("Add", systemImage: "plus", action: addNote)
            }
        }
        .onChange(of: menuBarManager.isListening) { _, isListening in
            if isListening {
                addNote()
            }
        }
    }

    func addNote() {
        if whisperManager.isRecording {
            return
        }
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
    NotesListSection()
}
