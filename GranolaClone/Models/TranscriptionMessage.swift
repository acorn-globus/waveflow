import Foundation
import SwiftData

@Model
class TranscriptionMessage {
    var id: UUID
    var source: String // Store as string since enum isn't directly supported
    var confirmedText: String
    var hypothesisText: String
    var note: Note?
    var createdAt: Date
    
    init(source: MessageSource, confirmedText: String, hypothesisText: String, note: Note? = nil) {
        self.id = UUID()
        self.source = source.rawValue
        self.confirmedText = confirmedText
        self.hypothesisText = hypothesisText
        self.note = note
        self.createdAt = Date()
    }
    

    enum MessageSource: String { // Add raw type and raw values
        case microphone = "microphone"
        case system = "system"
    }
}


