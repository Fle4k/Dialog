import SwiftUI
import UIKit

// MARK: - Dialog View Model
@MainActor
final class DialogViewModel: ObservableObject {
    // MARK: - Undo Manager
    private let undoManager = AppUndoManager.shared
    
    // MARK: - Data Properties
    @Published var textlines: [SpeakerText] = []
    @Published var selectedSpeaker: Speaker = .a
    @Published var inputText: String = ""
    @Published var customSpeakerNames: [Speaker: String] = [:]
    @Published var flaggedTextIds: Set<UUID> = []
    
    // MARK: - Edit Mode Properties
    @Published var isEditingText: Bool = false
    @Published var editingTextId: UUID? = nil
    @Published var editingOriginalSpeaker: Speaker? = nil
    
    // MARK: - UI State Properties (moved from View)
    @Published var showInputArea: Bool = false
    @Published var isFullscreenMode: Bool = false
    @Published var shouldFocusInput: Bool = false
    @Published var currentTitle: String = ""
    
    // MARK: - UI State Management
    func initializeForNewSession() {
        currentTitle = ""
        // Start in writing mode for immediate dialog writing
        isFullscreenMode = false
        showInputAreaWithFocus()
    }
    
    func initializeForExistingSession(_ session: DialogSession) {
        currentTitle = session.title
        loadSession(session)
        
        if !session.textlines.isEmpty {
            enterFullscreenMode()
        }
    }
    
    func showInputAreaWithFocus() {
        if !isEditingText {
            setNextSpeakerBasedOnLastText()
        }
        showInputArea = true
        // Trigger focus after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shouldFocusInput = true
        }
    }
    
    func hideInputArea() {
        shouldFocusInput = false
        showInputArea = false
    }
    
    func enterFullscreenMode() {
        isFullscreenMode = true
        showInputArea = false
        shouldFocusInput = false
    }
    
    func exitFullscreenMode() {
        isFullscreenMode = false
        showInputAreaWithFocus()
    }
    
    func handleViewTap() {
        if isEditingText {
            // If editing, cancel edit mode but stay in writing mode
            cancelEditMode()
        } else if isFullscreenMode {
            // Transition from fullscreen to writing mode
            exitFullscreenMode()
        } else {
            // Transition from writing mode to fullscreen mode
            enterFullscreenMode()
        }
    }
    
    func startEditingText(_ speakerText: SpeakerText) {
        isEditingText = true
        editingTextId = speakerText.id
        inputText = speakerText.text
        selectedSpeaker = speakerText.speaker
        editingOriginalSpeaker = speakerText.speaker
        
        if isFullscreenMode {
            exitFullscreenMode()
        } else {
            showInputAreaWithFocus()
        }
    }
    
    func cancelEditMode() {
        exitEditMode()
        inputText = ""
        setNextSpeakerBasedOnLastText()
        // Don't hide input area - stay in writing mode
        showInputAreaWithFocus()
    }
    
    func setTemporarySpeaker(_ speaker: Speaker) {
        // Only change the selectedSpeaker during editing, don't modify the actual text
        if isEditingText {
            selectedSpeaker = speaker
        }
    }
    
    // MARK: - Business Logic Methods
    func addText() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        if isEditingText, let editingId = editingTextId {
            // Store original values for undo
            if let index = textlines.firstIndex(where: { $0.id == editingId }) {
                let originalText = textlines[index]
                undoManager.recordAction(.editText(
                    id: editingId,
                    oldText: originalText.text,
                    newText: trimmedText,
                    oldSpeaker: originalText.speaker,
                    newSpeaker: selectedSpeaker
                ))
            }
            
            // Apply both text and speaker changes when saving the edit
            updateText(withId: editingId, newText: trimmedText, newSpeaker: selectedSpeaker)
            setNextSpeakerBasedOnLastText()
            
            // Add haptic feedback for successful edit confirmation
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        } else {
            let speakerText = SpeakerText(speaker: selectedSpeaker, text: trimmedText)
            
            // Record undo action
            undoManager.recordAction(.addText(speakerText))
            
            textlines.append(speakerText)
            selectedSpeaker.toggle()
        }
        
        inputText = ""
        exitEditMode()
        
        // Stay in writing mode after adding text for continuous dialog writing
        showInputAreaWithFocus()
    }
    
    func handleNewlineInput() {
        if inputText.contains("\n") {
            inputText = inputText.replacingOccurrences(of: "\n", with: "")
            addText()
        }
    }
    
    // MARK: - Edit Mode Methods
    func exitEditMode() {
        isEditingText = false
        editingTextId = nil
        editingOriginalSpeaker = nil
    }
    
    func updateText(withId id: UUID, newText: String, newSpeaker: Speaker) {
        guard let index = textlines.firstIndex(where: { $0.id == id }) else { return }
        
        // Create new speakerText with updated text but same ID and speaker
        let updatedText = SpeakerText(id: id, speaker: newSpeaker, text: newText)
        textlines[index] = updatedText
    }
    
    func changeSpeaker(withId id: UUID, to newSpeaker: Speaker) {
        guard let index = textlines.firstIndex(where: { $0.id == id }) else { return }
        
        // Create new speakerText with same ID and text but different speaker
        let updatedText = SpeakerText(id: id, speaker: newSpeaker, text: textlines[index].text)
        textlines[index] = updatedText
        
        // Update the selected speaker to match the change
        selectedSpeaker = newSpeaker
    }
    
    func renameSpeaker(_ speaker: Speaker, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldName = customSpeakerNames[speaker]
        let newName = trimmedName.isEmpty ? nil : trimmedName
        
        // Record undo action
        undoManager.recordAction(.renameSpeaker(speaker, oldName, newName))
        
        customSpeakerNames[speaker] = newName
    }
    
    func deleteText(withId id: UUID) {
        guard let index = textlines.firstIndex(where: { $0.id == id }) else { return }
        let speakerText = textlines[index]
        
        // Record undo action
        undoManager.recordAction(.deleteText(speakerText, index))
        
        textlines.removeAll { $0.id == id }
        flaggedTextIds.remove(id)
    }
    
    func deleteText(at offsets: IndexSet) {
        for offset in offsets {
            let speakerText = textlines[offset]
            
            // Record undo action for each deleted text
            undoManager.recordAction(.deleteText(speakerText, offset))
            
            flaggedTextIds.remove(speakerText.id)
        }
        textlines.remove(atOffsets: offsets)
    }
    
    func toggleFlag(for textId: UUID) {
        let wasAdd = !flaggedTextIds.contains(textId)
        
        // Record undo action
        undoManager.recordAction(.toggleFlag(textId, wasAdd))
        
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
    func loadSession(_ session: DialogSession) {
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
            let speakerName = escapeRTFText(speakerText.speaker.displayName(customNames: customSpeakerNames).uppercased())
            
            // Add centered speaker name in caps
            rtfContent += "\\par\\par\\qc\\b \(speakerName)\\b0\\par"
            
            // Break long lines and add dialog text (centered)
            let wrappedText = wrapText(escapeRTFText(speakerText.text), maxLength: 35)
            rtfContent += "\\qc \(wrappedText)\\par"
        }
        
        rtfContent += "}"
        return rtfContent.data(using: .windowsCP1252) ?? rtfContent.data(using: .utf8) ?? Data()
    }
    
    private func escapeRTFText(_ text: String) -> String {
        var escaped = text
        
        // Escape backslashes first
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        
        // Escape curly braces
        escaped = escaped.replacingOccurrences(of: "{", with: "\\{")
        escaped = escaped.replacingOccurrences(of: "}", with: "\\}")
        
        // German special characters (Windows-1252 codes)
        escaped = escaped.replacingOccurrences(of: "Ä", with: "\\'c4")
        escaped = escaped.replacingOccurrences(of: "ä", with: "\\'e4")
        escaped = escaped.replacingOccurrences(of: "Ö", with: "\\'d6")
        escaped = escaped.replacingOccurrences(of: "ö", with: "\\'f6")
        escaped = escaped.replacingOccurrences(of: "Ü", with: "\\'dc")
        escaped = escaped.replacingOccurrences(of: "ü", with: "\\'fc")
        escaped = escaped.replacingOccurrences(of: "ß", with: "\\'df")
        
        // Other common European characters
        escaped = escaped.replacingOccurrences(of: "é", with: "\\'e9")
        escaped = escaped.replacingOccurrences(of: "è", with: "\\'e8")
        escaped = escaped.replacingOccurrences(of: "à", with: "\\'e0")
        escaped = escaped.replacingOccurrences(of: "á", with: "\\'e1")
        escaped = escaped.replacingOccurrences(of: "ñ", with: "\\'f1")
        escaped = escaped.replacingOccurrences(of: "ç", with: "\\'e7")
        
        return escaped
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
                            <Paragraph Type="Dialog">
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
    
    // MARK: - Title Management
    func updateTitle(_ newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTitle = trimmedTitle.isEmpty ? "New Dialogue" : trimmedTitle
    }
    
    // MARK: - Undo Methods
    func undoAddText(_ speakerText: SpeakerText) {
        textlines.removeAll { $0.id == speakerText.id }
        flaggedTextIds.remove(speakerText.id)
    }
    
    func undoDeleteText(_ speakerText: SpeakerText, at originalIndex: Int) {
        // Insert at the original position if it's valid, otherwise append
        if originalIndex >= 0 && originalIndex <= textlines.count {
            textlines.insert(speakerText, at: originalIndex)
        } else {
            textlines.append(speakerText)
        }
    }
    
    func undoEditText(id: UUID, oldText: String, oldSpeaker: Speaker) {
        guard let index = textlines.firstIndex(where: { $0.id == id }) else { return }
        let updatedText = SpeakerText(id: id, speaker: oldSpeaker, text: oldText)
        textlines[index] = updatedText
    }
    
    func undoToggleFlag(textId: UUID, wasAdd: Bool) {
        if wasAdd {
            flaggedTextIds.remove(textId)
        } else {
            flaggedTextIds.insert(textId)
        }
    }
    
    func undoRenameSpeaker(_ speaker: Speaker, oldName: String?) {
        customSpeakerNames[speaker] = oldName
    }
    
    func canUndo() -> Bool {
        return undoManager.canUndo
    }
    
    func getLastActionDescription() -> String {
        return undoManager.lastActionDescription
    }
    
    func performUndo() {
        undoManager.performUndo(dialogViewModel: self)
    }
} 