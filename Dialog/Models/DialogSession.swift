import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Dialog Session Model
struct DialogSession: Identifiable, Codable, FileDocument {
    var id = UUID()
    let createdAt: Date
    var lastModified: Date
    var title: String
    var textlines: [SpeakerText]
    var screenplayElements: [ScreenplayElement] // New screenplay elements system
    var customSpeakerNames: [Speaker: String]
    var flaggedTextIds: Set<UUID>
    
    // MARK: - FileDocument Conformance
    static var readableContentTypes: [UTType] { [.dialogDocument] }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // Try to decode with new format first, fall back to legacy format
        if let session = try? JSONDecoder().decode(DialogSession.self, from: data) {
            self = session
        } else {
            // Handle legacy format without screenplayElements
            let legacySession = try JSONDecoder().decode(LegacyDialogSession.self, from: data)
            self.id = legacySession.id
            self.createdAt = legacySession.createdAt
            self.lastModified = legacySession.lastModified
            self.title = legacySession.title
            self.textlines = legacySession.textlines
            self.screenplayElements = [] // Empty for legacy sessions
            self.customSpeakerNames = legacySession.customSpeakerNames
            self.flaggedTextIds = legacySession.flaggedTextIds
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(self)
        return FileWrapper(regularFileWithContents: data)
    }
    
    // MARK: - Existing Initializers
    @MainActor
    init(from viewModel: DialogViewModel) {
        self.createdAt = Date()
        self.lastModified = Date()
        self.textlines = viewModel.textlines
        self.screenplayElements = viewModel.screenplayElements
        self.customSpeakerNames = viewModel.customSpeakerNames
        self.flaggedTextIds = viewModel.flaggedTextIds
        
        // Use the viewModel's currentTitle if it's set, otherwise generate one
        if !viewModel.currentTitle.isEmpty {
            self.title = viewModel.currentTitle
        } else {
            // Generate title from screenplay elements if available, otherwise use textlines
            if !screenplayElements.isEmpty {
                self.title = Self.generateTitle(from: screenplayElements)
            } else {
                self.title = Self.generateTitle(from: self.textlines)
            }
        }
    }
    
    static func generateTitle(from textlines: [SpeakerText]) -> String {
        guard !textlines.isEmpty else { return "New Dialog" }
        
        let firstText = textlines[0].text
        let words = firstText.components(separatedBy: .whitespacesAndNewlines)
        let titleWords = Array(words.prefix(3))
        
        if titleWords.isEmpty {
            return "New Dialog"
        }
        
        return titleWords.joined(separator: " ") + (words.count > 3 ? "..." : "")
    }
    
    static func generateTitle(from elements: [ScreenplayElement]) -> String {
        guard !elements.isEmpty else { return "New Screenplay" }
        
        // Find the first meaningful content (dialogue or action)
        let meaningfulElement = elements.first { element in
            element.type == .dialogue || element.type == .action
        }
        
        guard let element = meaningfulElement else {
            // Fall back to first element if no dialogue or action found
            let firstContent = elements[0].content
            let words = firstContent.components(separatedBy: .whitespacesAndNewlines)
            let titleWords = Array(words.prefix(3))
            return titleWords.isEmpty ? "New Screenplay" : titleWords.joined(separator: " ") + (words.count > 3 ? "..." : "")
        }
        
        let words = element.content.components(separatedBy: .whitespacesAndNewlines)
        let titleWords = Array(words.prefix(3))
        
        if titleWords.isEmpty {
            return "New Screenplay"
        }
        
        return titleWords.joined(separator: " ") + (words.count > 3 ? "..." : "")
    }
    
    var lineCount: Int {
        // Count both legacy textlines and new screenplay elements
        return textlines.count + screenplayElements.count
    }
    
    var isEmpty: Bool {
        return textlines.isEmpty && screenplayElements.isEmpty
    }
    
    // MARK: - Content Comparison
    func hasContentChanges(comparedTo other: DialogSession) -> Bool {
        // Check if title has changed
        if title != other.title {
            return true
        }
        
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

// MARK: - Legacy Model for Backward Compatibility
struct LegacyDialogSession: Codable {
    var id = UUID()
    let createdAt: Date
    var lastModified: Date
    var title: String
    var textlines: [SpeakerText]
    var customSpeakerNames: [Speaker: String]
    var flaggedTextIds: Set<UUID>
}

// MARK: - Custom UTType
extension UTType {
    static var dialogDocument: UTType {
        UTType(importedAs: "com.dialog.dialog")
    }
} 