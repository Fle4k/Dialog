import Foundation

// MARK: - Dialogue Session Model
struct DialogueSession: Identifiable, Codable {
    var id = UUID()
    let createdAt: Date
    var lastModified: Date
    var title: String
    var textlines: [SpeakerText]
    var customSpeakerNames: [Speaker: String]
    var flaggedTextIds: Set<UUID>
    
    @MainActor
    init(from viewModel: DialogViewModel) {
        self.createdAt = Date()
        self.lastModified = Date()
        self.textlines = viewModel.textlines
        self.customSpeakerNames = viewModel.customSpeakerNames
        self.flaggedTextIds = viewModel.flaggedTextIds
        self.title = Self.generateTitle(from: self.textlines)
    }
    
    static func generateTitle(from textlines: [SpeakerText]) -> String {
        guard !textlines.isEmpty else { return "New Dialogue" }
        
        let firstText = textlines[0].text
        let words = firstText.components(separatedBy: .whitespacesAndNewlines)
        let titleWords = Array(words.prefix(3))
        
        if titleWords.isEmpty {
            return "New Dialogue"
        }
        
        return titleWords.joined(separator: " ") + (words.count > 3 ? "..." : "")
    }
    
    var lineCount: Int {
        textlines.count
    }
    
    var isEmpty: Bool {
        textlines.isEmpty
    }
    
    // MARK: - Content Comparison
    func hasContentChanges(comparedTo other: DialogueSession) -> Bool {
        // Check if textlines have changed
        if textlines.count != other.textlines.count {
            return true
        }
        
        // Check if any textline content has changed
        for (index, speakerText) in textlines.enumerated() {
            if index < other.textlines.count {
                let otherSpeakerText = other.textlines[index]
                if speakerText.text != otherSpeakerText.text || 
                   speakerText.speaker != otherSpeakerText.speaker {
                    return true
                }
            }
        }
        
        // Check if custom speaker names have changed
        if customSpeakerNames != other.customSpeakerNames {
            return true
        }
        
        // Check if flagged textlines have changed
        if flaggedTextIds != other.flaggedTextIds {
            return true
        }
        
        return false
    }
}

// MARK: - SpeakerText Codable Extension
extension SpeakerText: Codable {
    enum CodingKeys: String, CodingKey {
        case id, speaker, text
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle backward compatibility - if no ID is present, generate one
        if let id = try? container.decode(UUID.self, forKey: .id) {
            self.id = id
        } else {
            self.id = UUID()
        }
        
        self.speaker = try container.decode(Speaker.self, forKey: .speaker)
        self.text = try container.decode(String.self, forKey: .text)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(speaker, forKey: .speaker)
        try container.encode(text, forKey: .text)
    }
}

// MARK: - Speaker Codable Extension
extension Speaker: Codable {} 