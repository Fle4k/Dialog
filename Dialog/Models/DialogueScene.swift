import Foundation

struct DialogueScene: Identifiable, Codable {
    let id: UUID
    var title: String
    var dialogues: [Dialogue]
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, dialogues: [Dialogue] = []) {
        self.id = UUID()
        self.title = title
        self.dialogues = dialogues
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 