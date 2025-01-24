import SwiftUI
import SwiftData

struct NotesListSection: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var whisperManager: WhisperManager
    @EnvironmentObject private var ollamaManager: OllamaManager
    @Query(sort: \Note.createdAt) var notes: [Note]
    @State private var path = [Note]()
    
    @State private var overText: UUID? = nil
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationStack(path: $path) {

        ZStack{
            VStack(alignment: .leading){
                if notes.count == 0 {
                    EmptyNotesView()
                } else {
                    Text("Recent Notes")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.vertical)
                }
                List {
                    ForEach(notes) { note in
                        NavigationLink(value: note) {
                            NoteRow(note)
                        }
                        .listRowBackground(note.id == overText ? Color.secondaryBackground : .clear)
                        .onHover(perform: { hovering in
                            overText = note.id
                        })
                    }
                    .onDelete(perform: deleteNote)
                }
                .listStyle(.plain)
                .navigationTitle("")
                .navigationDestination(for: Note.self, destination: NoteDetailSection.init)
                .toolbar {
                    ToolbarView()
                }
            }
            .padding(36)
            .frame(maxWidth: 900)
            if showSettings {
                SettingsModal()
            }
        }
            
        }
        .onChange(of: menuBarManager.createNewNoteCount) { _, newNoteCount in
            if whisperManager.isRecording { return }
            addNote()
        }
    }
    
    @ViewBuilder
    private func ToolbarView() -> some View {
        Button (action: addNote) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                Text("New Note")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(BorderlessButtonStyle())
        
        Button (action: {
            showSettings = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(BorderlessButtonStyle())
    }
    
    @ViewBuilder
    private func EmptyNotesView() -> some View {
       VStack(spacing: 16) {
           ZStack {
               Circle()
                   .fill(Color.blue.opacity(0.1))
                   .frame(width: 60, height: 60)
                   .overlay(
                       Circle()
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
                   )

               Image(.docIcon)
                   .resizable()
                   .scaledToFit()
                   .frame(width: 36, height: 36)
           }
           
           Text("Create your first Note")
               .font(.title)
               .fontWeight(.semibold)
           
           Text("Record your meetings and create summaries with waveflow.")
               .foregroundColor(.gray)
           
           Button {
               addNote()
           } label: {
               HStack(spacing: 8) {
                   Image(systemName: "mic.fill")
                   Text("Start Recording")
               }
               .padding(.horizontal, 16)
               .padding(.vertical, 8)
               .background(Color.blue)
               .foregroundColor(.white)
               .cornerRadius(8)
           }
           .buttonStyle(BorderlessButtonStyle())
       }
       .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func SettingsModal() -> some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea() // Make background span the whole screen
                .onTapGesture {
                    showSettings = false
                }
            
            VStack {
                VStack(spacing: 12) {
                    HStack {
                        Text("Settings")
                            .font(.title2)
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .onTapGesture {
                                showSettings = false
                            }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transcription Modal")
                                .font(.title3)
                            Text("AI model used to convert voice-to-text")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(whisperManager.modelName.capitalized)
                            .font(.body)
                    }
                    .padding()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Model for Summaries")
                                .font(.title3)
                            Text("AI model used to create a summary of the transcription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(ollamaManager.defaultModel.capitalized)
                            .font(.body)
                    }
                    .padding()
                }
                .frame(maxWidth: 480) // Set a max width for the content
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 8)
            }
            .padding()
        }
    }

    
    @ViewBuilder
    private func NoteRow(_ note: Note) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 24){
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
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
                        )

                    Image(.docIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40 * 0.6, height: 40 * 0.6)
                }
                VStack(alignment: .leading) {
                    Text(note.title)
                        .font(.title3)
                    Text(note.createdAt.formatted(date: .long, time: .omitted))
                        .font(.caption)
                        .foregroundColor(Color.gray)
                }
                Spacer()
                Text(note.createdAt.formatted(date: .omitted,time: .shortened))
                    .font(.caption)
                    .foregroundColor(Color.gray)
            }
            .padding(12)
        }
        .alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
            return -viewDimensions.width
        }
    }

    private func addNote() {
        let newNote = Note(title: "", body: "")
        modelContext.insert(newNote)
        path = [newNote]
    }

    private func deleteNote(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(notes[index])
        }
    }
}

#Preview {
    NotesListSection()
}
