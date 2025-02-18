import Foundation
import SwiftData

@Model
class Note {
    var id: UUID
    var title: String
    var body: String
    var summary: String
    @Relationship(deleteRule: .cascade, inverse: \TranscriptionMessage.note) var messages: [TranscriptionMessage]
    var createdAt: Date
    
    init(title: String, body: String = "", summary: String = "") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.summary = summary
        self.messages = []
        self.createdAt = Date()
    }
}
