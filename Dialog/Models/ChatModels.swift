import Foundation

// MARK: - Dialog Models
struct SpeakerText: Identifiable, Hashable, Codable {
    let id: UUID
    let speaker: Speaker
    let text: String
    
    init(speaker: Speaker, text: String) {
        self.id = UUID()
        self.speaker = speaker
        self.text = text
    }
    
    init(id: UUID, speaker: Speaker, text: String) {
        self.id = id
        self.speaker = speaker
        self.text = text
    }
    
    var isSpeakerA: Bool {
        speaker == .a
    }
}

enum Speaker: String, CaseIterable, Codable {
    case a = "A"
    case b = "B"
    
    func displayName(customNames: [Speaker: String]) -> String {
        if let customName = customNames[self], !customName.isEmpty {
            return customName
        }
        return rawValue
    }
    
    mutating func toggle() {
        self = self == .a ? .b : .a
    }
} 