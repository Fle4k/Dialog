import Foundation

struct DialogueScene: Identifiable, Codable {
    let id: UUID
    var title: String
    var dialogues: [Dialogue]
    var speakerAName: String
    var speakerBName: String
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, dialogues: [Dialogue] = [], speakerAName: String = "A", speakerBName: String = "B") {
        self.id = UUID()
        self.title = title
        self.dialogues = dialogues
        self.speakerAName = speakerAName
        self.speakerBName = speakerBName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 