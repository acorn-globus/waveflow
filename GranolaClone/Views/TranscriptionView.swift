import SwiftUI

struct TranscriptionView: View {
    @ObservedObject var transcriptionManager: TranscriptionManager
    @EnvironmentObject private var menuBarManager: MenuBarManager
    
    var body: some View {
        VStack(spacing: 16) {
            if menuBarManager.isListening {
                HStack {
                    ListeningIndicator()
                    Text("Transcribing...")
                        .foregroundColor(.secondary)
                }
            }
            
            ScrollView {
                Text(transcriptionManager.transcribedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            
            HStack {
                Text("\(transcriptionManager.transcribedText.split(separator: " ").count) words")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Spacer()
                
                Button("Clear") {
                    transcriptionManager.transcribedText = ""
                }
                .disabled(transcriptionManager.transcribedText.isEmpty)
            }
        }
        .padding()
    }
}

//struct ListeningIndicator: View {
//    @State private var isAnimating = false
//    
//    var body: some View {
//        Circle()
//            .fill(Color.red)
//            .frame(width: 10, height: 10)
//            .opacity(isAnimating ? 0.5 : 1)
//            .animation(
//                Animation.easeInOut(duration: 1)
//                    .repeatForever(),
//                value: isAnimating
//            )
//            .onAppear {
//                isAnimating = true
//            }
//    }
//}
