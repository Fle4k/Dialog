import Foundation

struct DialogueEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let speaker: String
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), speaker: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.timestamp = timestamp
    }
    
    static func == (lhs: DialogueEntry, rhs: DialogueEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.speaker == rhs.speaker &&
        lhs.text == rhs.text &&
        lhs.timestamp == rhs.timestamp
    }
} 