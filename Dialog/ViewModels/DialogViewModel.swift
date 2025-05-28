import SwiftUI

// MARK: - Dialog View Model
@MainActor
final class DialogViewModel: ObservableObject {
    @Published var textlines: [SpeakerText] = []
    @Published var selectedSpeaker: Speaker = .a
    @Published var inputText: String = ""
    @Published var customSpeakerNames: [Speaker: String] = [:]
    @Published var flaggedTextIds: Set<UUID> = []
    
    // MARK: - Edit Mode Properties
    @Published var isEditingText: Bool = false
    @Published var editingTextId: UUID? = nil
    
    func addText() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        if isEditingText, let editingId = editingTextId {
            // Update existing text
            updateText(withId: editingId, newText: trimmedText)
            // Restore proper speaker turn based on last text
            setNextSpeakerBasedOnLastText()
        } else {
            // Add new text
            let speakerText = SpeakerText(speaker: selectedSpeaker, text: trimmedText)
            textlines.append(speakerText)
            selectedSpeaker.toggle()
        }
        
        // Reset input state
        inputText = ""
        exitEditMode()
    }
    
    func handleNewlineInput() {
        if inputText.contains("\n") {
            inputText = inputText.replacingOccurrences(of: "\n", with: "")
            addText()
        }
    }
    
    // MARK: - Edit Mode Methods
    func startEditingText(_ speakerText: SpeakerText) {
        isEditingText = true
        editingTextId = speakerText.id
        inputText = speakerText.text
        selectedSpeaker = speakerText.speaker
    }
    
    func exitEditMode() {
        isEditingText = false
        editingTextId = nil
    }
    
    func updateText(withId id: UUID, newText: String) {
        guard let index = textlines.firstIndex(where: { $0.id == id }) else { return }
        
        // Create new speakerText with updated text but same ID and speaker
        let updatedText = SpeakerText(id: id, speaker: textlines[index].speaker, text: newText)
        textlines[index] = updatedText
    }
    
    func renameSpeaker(_ speaker: Speaker, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        customSpeakerNames[speaker] = trimmedName.isEmpty ? nil : trimmedName
    }
    
    func deleteText(withId id: UUID) {
        textlines.removeAll { $0.id == id }
        flaggedTextIds.remove(id)
    }
    
    func deleteText(at offsets: IndexSet) {
        for offset in offsets {
            let speakerText = textlines[offset]
            flaggedTextIds.remove(speakerText.id)
        }
        textlines.remove(atOffsets: offsets)
    }
    
    func toggleFlag(for textId: UUID) {
        if flaggedTextIds.contains(textId) {
            flaggedTextIds.remove(textId)
        } else {
            flaggedTextIds.insert(textId)
        }
    }
    
    func isTextFlagged(_ textId: UUID) -> Bool {
        flaggedTextIds.contains(textId)
    }
    
    func getSpeakerName(for speaker: Speaker) -> String {
        return speaker.displayName(customNames: customSpeakerNames)
    }
    
    // MARK: - Session Management
    func loadSession(_ session: DialogueSession) {
        textlines = session.textlines
        customSpeakerNames = session.customSpeakerNames
        flaggedTextIds = session.flaggedTextIds
        // Reset input state
        inputText = ""
        setNextSpeakerBasedOnLastText()
    }
    
    // MARK: - Speaker Management
    func setNextSpeakerBasedOnLastText() {
        if let lastText = textlines.last {
            // Set the speaker to the opposite of the last text's speaker
            selectedSpeaker = lastText.speaker == .a ? .b : .a
        } else {
            // If no texts exist, default to speaker A
        selectedSpeaker = .a
        }
    }
    
    // MARK: - Export Methods
    func exportToText() -> String {
        var result = ""
        for speakerText in textlines {
            let speakerName = speakerText.speaker.displayName(customNames: customSpeakerNames)
            result += "\(speakerName): \(speakerText.text)\n\n"
        }
        return result
    }
    
    func exportToTextURL() -> URL {
        let content = exportToText()
        let filename = generateFilename(suffix: "txt")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write text file: \(error)")
        }
        
        return tempURL
    }
    
    func exportToRTF() -> Data {
        var rtfContent = "{\\rtf1\\ansi\\deff0 {\\fonttbl \\f0 Courier New;} \\f0\\fs24"
        
        for speakerText in textlines {
            let speakerName = speakerText.speaker.displayName(customNames: customSpeakerNames).uppercased()
            
            // Add centered speaker name in caps
            rtfContent += "\\par\\par\\qc\\b \(speakerName)\\b0\\par"
            
            // Break long lines and add dialogue text (centered)
            let wrappedText = wrapText(speakerText.text, maxLength: 35)
            rtfContent += "\\qc \(wrappedText)\\par"
        }
        
        rtfContent += "}"
        return rtfContent.data(using: .utf8) ?? Data()
    }
    
    private func wrapText(_ text: String, maxLength: Int) -> String {
        let words = text.components(separatedBy: .whitespaces)
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            
            if testLine.count <= maxLength {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.joined(separator: "\\par\\qc ")
    }
    
    func exportToRTFURL() -> URL {
        let data = exportToRTF()
        let filename = generateFilename(suffix: "rtf")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
        } catch {
            print("Failed to write RTF file: \(error)")
        }
        
        return tempURL
    }
    
    func exportToFDX() -> Data {
        let fdxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="1">
        <Content>
        \(textlines.map { speakerText in
            let speakerName = speakerText.speaker.displayName(customNames: customSpeakerNames)
            return """
            <Paragraph Type="Character">
            <Text>\(speakerName)</Text>
            </Paragraph>
            <Paragraph Type="Dialogue">
            <Text>\(speakerText.text)</Text>
            </Paragraph>
            """
        }.joined(separator: "\n"))
        </Content>
        </FinalDraft>
        """
        return fdxContent.data(using: .utf8) ?? Data()
    }
    
    func exportToFDXURL() -> URL {
        let data = exportToFDX()
        let filename = generateFilename(suffix: "fdx")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
        } catch {
            print("Failed to write FDX file: \(error)")
        }
        
        return tempURL
    }
    
    private func generateFilename(suffix: String) -> String {
        let title = generateTitle()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ddMMyyyy"
        let dateString = dateFormatter.string(from: Date())
        
        return "\(title)_\(dateString).\(suffix)"
    }
    
    private func generateTitle() -> String {
        guard !textlines.isEmpty else { return "NewDialog" }
        
        let firstText = textlines[0].text
        let words = firstText.components(separatedBy: .whitespacesAndNewlines)
        let titleWords = Array(words.prefix(3))
        
        if titleWords.isEmpty {
            return "NewDialog"
        }
        
        // Clean title for filename (remove special characters)
        let title = titleWords.joined(separator: " ")
        let cleanTitle = title.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "")
        
        return cleanTitle.isEmpty ? "NewDialog" : cleanTitle
    }
} 