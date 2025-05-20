import Foundation

protocol DialogueServiceProtocol {
    func saveDialogue(_ entries: [DialogueEntry])
    func loadDialogue() -> [DialogueEntry]
    func clearDialogue()
}

class DialogueService: DialogueServiceProtocol {
    private let userDefaults = UserDefaults.standard
    private let dialogueKey = "savedDialogue"
    
    func saveDialogue(_ entries: [DialogueEntry]) {
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: dialogueKey)
        }
    }
    
    func loadDialogue() -> [DialogueEntry] {
        guard let data = userDefaults.data(forKey: dialogueKey),
              let entries = try? JSONDecoder().decode([DialogueEntry].self, from: data) else {
            return []
        }
        return entries
    }
    
    func clearDialogue() {
        userDefaults.removeObject(forKey: dialogueKey)
    }
} 