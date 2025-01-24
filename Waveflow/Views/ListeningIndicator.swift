import SwiftUI

struct ListeningIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                    .opacity(isAnimating ? 0.5 : 1.0)
                
                Text("Listening...")
                    .foregroundStyle(.red)
            }
            .font(.title2)
            .padding()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.red.opacity(0.1))
        }
    }
}

#Preview {
    ListeningIndicator()
}
