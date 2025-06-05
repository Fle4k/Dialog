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
    var customSpeakerNames: [Speaker: String]
    var flaggedTextIds: Set<UUID>
    
    // MARK: - FileDocument Conformance
    static var readableContentTypes: [UTType] { [.dialogDocument] }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self = try JSONDecoder().decode(DialogSession.self, from: data)
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
        self.customSpeakerNames = viewModel.customSpeakerNames
        self.flaggedTextIds = viewModel.flaggedTextIds
        
        // Use the viewModel's currentTitle if it's set, otherwise generate one
        if !viewModel.currentTitle.isEmpty {
            self.title = viewModel.currentTitle
        } else {
            self.title = Self.generateTitle(from: self.textlines)
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
    
    var lineCount: Int {
        textlines.count
    }
    
    var isEmpty: Bool {
        textlines.isEmpty
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

// MARK: - Custom UTType
extension UTType {
    static var dialogDocument: UTType {
        UTType(importedAs: "com.dialog.dialog")
    }
} 