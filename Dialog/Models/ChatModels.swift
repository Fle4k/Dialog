import Foundation

// MARK: - Screenplay Element Types
enum ScreenplayElementType: String, CaseIterable, Codable {
    case dialogue = "Dialogue"
    case parenthetical = "Parenthetical"
    case action = "Action"
    
    var displayName: String {
        switch self {
        case .dialogue: return "Dialog"
        case .parenthetical: return "Parenthetical"
        case .action: return "Action"
        }
    }
    
    var fdxElementType: String {
        return rawValue
    }
    
    var requiresSpeaker: Bool {
        return self == .dialogue
    }
}

// MARK: - Enhanced Screenplay Element Model
struct ScreenplayElement: Identifiable, Hashable, Codable {
    let id: UUID
    let type: ScreenplayElementType
    let content: String
    let speaker: Speaker? // Only used for character, dialogue, and parenthetical elements
    
    init(type: ScreenplayElementType, content: String, speaker: Speaker? = nil) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.speaker = speaker
    }
    
    init(id: UUID, type: ScreenplayElementType, content: String, speaker: Speaker? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.speaker = speaker
    }
    
    // Convenience properties
    var isDialogueElement: Bool { type == .dialogue }
    var isParentheticalElement: Bool { type == .parenthetical }
    var isActionElement: Bool { type == .action }
    var requiresSpeaker: Bool { type == .dialogue }
    
    // For backwards compatibility with existing SpeakerText usage
    var isSpeakerA: Bool {
        speaker == .a
    }
}

// MARK: - Legacy SpeakerText Model (for backwards compatibility)
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
    
    // Convert to new ScreenplayElement (assuming it's dialogue)
    func toScreenplayElement() -> ScreenplayElement {
        return ScreenplayElement(id: id, type: .dialogue, content: text, speaker: speaker)
    }
}

// MARK: - Speaker Model
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