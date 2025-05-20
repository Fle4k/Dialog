import Foundation

struct Dialogue: Identifiable, Codable, Equatable {
    let id: UUID
    let speaker: String
    let text: String
    let timestamp: Date
    
    init(speaker: String, text: String) {
        self.id = UUID()
        self.speaker = speaker
        self.text = text
        self.timestamp = Date()
    }
    
    static func == (lhs: Dialogue, rhs: Dialogue) -> Bool {
        lhs.id == rhs.id &&
        lhs.speaker == rhs.speaker &&
        lhs.text == rhs.text &&
        lhs.timestamp == rhs.timestamp
    }
} 