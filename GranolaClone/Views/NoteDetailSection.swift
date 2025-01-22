import SwiftUI
import SwiftData
import MarkdownUI

struct NoteDetailSection: View {
    @Bindable var note: Note
    @State private var copiedMessage = ""
    @State private var selectedTab: Tab = .summary
        
    enum Tab: String {
        case summary = "Summary"
        case body = "Body"
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ZStack{
                    ScrollView {
                        VStack(alignment: .leading) {
                            TextEditor(text: $note.title)
                                .font(.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 0)
                            if selectedTab == .summary && !note.summary.isEmpty {
                                Markdown(note.summary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }else{
                                TextEditor(text: $note.body)
                                    .frame(maxHeight: .infinity, alignment: .leading)
                                    .font(.body)
                            }
                        }
                        .padding()
                        .padding(.bottom, 42)
                    }
                    if selectedTab == .summary {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    copyToClipboard(note.summary)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                }.offset(x: -10, y: 10)
                            }
                            Spacer()
                        }
                    }
                    
                    if(!note.summary.isEmpty){
                        VStack {
                            Spacer()
                            Picker("", selection: $selectedTab) {
                                Text("Summary").tag(Tab.summary)
                                Text("Body").tag(Tab.body)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding()
                            .background(Color(.textBackgroundColor))
                        }
                    }
                }.frame(width: geometry.size.width * 0.6)
                Divider().layoutPriority(0)
                TranscriptionSection(currentNote: note)
                    .frame(width: geometry.size.width * 0.4)

            }
            .navigationTitle(note.title)
            .background(Color(.textBackgroundColor))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
