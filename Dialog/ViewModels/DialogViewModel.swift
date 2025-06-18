import SwiftUI
import UIKit

// MARK: - Dialog View Model
@MainActor
final class DialogViewModel: ObservableObject {
    // MARK: - Undo Manager
    private let undoManager = AppUndoManager.shared
    
    // MARK: - Data Properties
    @Published var textlines: [SpeakerText] = []
    @Published var screenplayElements: [ScreenplayElement] = []
    @Published var selectedSpeaker: Speaker = .a
    @Published var selectedElementType: ScreenplayElementType = .dialogue
    @Published var inputText: String = ""
    @Published var customSpeakerNames: [Speaker: String] = [:]
    @Published var flaggedTextIds: Set<UUID> = []
    
    // MARK: - Edit Mode Properties
    @Published var isEditingText: Bool = false
    @Published var editingTextId: UUID? = nil
    @Published var editingGroupId: UUID? = nil
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
    
    func startEditingGroup(_ groupedElement: GroupedElement) {
        isEditingText = true
        editingGroupId = groupedElement.id
        editingOriginalSpeaker = groupedElement.speaker
        
        // Edit the first element in the group (whether dialogue, parenthetical, or action)
        if let firstElement = groupedElement.elements.first {
            inputText = firstElement.content
            selectedSpeaker = firstElement.speaker ?? groupedElement.speaker ?? .a
            selectedElementType = firstElement.type
        }
        
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
        
        if isEditingText, let editingGroupId = editingGroupId {
            // We're editing a group - replace the first dialogue element with the new text
            saveEditedGroup(groupId: editingGroupId, newText: trimmedText, newSpeaker: selectedSpeaker)
            
            // Add haptic feedback for successful edit confirmation
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        } else if isEditingText, let editingId = editingTextId {
            // Legacy editing for old textlines system
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
            // Add to new screenplay elements system
            addScreenplayElement()
            
            // Only add to legacy textlines system for dialogue elements (for backwards compatibility)
            // Note: No undo recording here since addScreenplayElement() already handles undo
            if selectedElementType == .dialogue {
                let speakerText = SpeakerText(speaker: selectedSpeaker, text: trimmedText)
                textlines.append(speakerText)
            }
        }
        
        inputText = ""
        exitEditMode()
        
        // Stay in writing mode after adding text for continuous dialog writing
        showInputAreaWithFocus()
    }
    
    func addScreenplayElement() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // STRICT VALIDATION: After a parenthetical, only dialogue is allowed
        let lastElement = screenplayElements.last
        if lastElement?.type == .parenthetical && selectedElementType != .dialogue {
            // Force dialogue after parenthetical with haptic feedback
            selectedElementType = .dialogue
            
            // Provide haptic feedback to indicate the rule enforcement
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
            
            print("🚫 Enforcing dialogue-only rule: After parenthetical, only dialogue is allowed")
        }
        
        // Process content based on element type
        var processedContent = trimmedText
        
        // For parentheticals, remove outer parentheses if they exist (we'll add them in display)
        if selectedElementType == .parenthetical {
            if trimmedText.hasPrefix("(") && trimmedText.hasSuffix(")") && trimmedText.count > 2 {
                processedContent = String(trimmedText.dropFirst().dropLast())
            }
        }
        
        // Parentheticals need a speaker (they belong to someone)
        let speaker = (selectedElementType == .parenthetical || selectedElementType.requiresSpeaker) ? selectedSpeaker : nil
        let element = ScreenplayElement(type: selectedElementType, content: processedContent, speaker: speaker)
        
        // Record undo action for screenplay element
        undoManager.recordAction(.addScreenplayElement(element))
        
        screenplayElements.append(element)
        
        // Handle element type specific logic
        handleElementTypeSpecificLogic()
    }
    
    private func handleSpeakerToggle() {
        // Legacy method - speaker toggling is now handled in handleElementTypeSpecificLogic()
        selectedSpeaker.toggle()
    }
    
    private func handleElementTypeSpecificLogic() {
        print("🔄 handleElementTypeSpecificLogic - elementType: \(selectedElementType), currentSpeaker: \(selectedSpeaker)")
        
        switch selectedElementType {
        case .dialogue:
            // Check if the previous element was a parenthetical from the same speaker
            let lastElement = screenplayElements.last
            let isFollowingParenthetical = lastElement?.type == .parenthetical && lastElement?.speaker == selectedSpeaker
            
            if isFollowingParenthetical {
                // Don't toggle speaker - this is continuation of the same speaker's dialogue after parenthetical
                print("🔄 After dialogue (following parenthetical): keeping speaker as \(selectedSpeaker)")
            } else {
                // Normal dialogue flow - toggle to other speaker
                selectedSpeaker.toggle()
                print("🔄 After dialogue: toggled speaker to \(selectedSpeaker)")
            }
            
        case .parenthetical:
            // After parenthetical, ENFORCE dialogue only for the SAME speaker (don't toggle)
            selectedElementType = .dialogue
            print("🔄 After parenthetical: enforcing dialogue only, keeping speaker as \(selectedSpeaker), elementType now \(selectedElementType)")
            
        case .action:
            // After action, go back to normal dialogue flow with next speaker
            selectedElementType = .dialogue
            selectedSpeaker.toggle()
            print("🔄 After action: toggled speaker to \(selectedSpeaker), elementType now \(selectedElementType)")
        }
    }
    
    func handleNewlineInput() {
        if inputText.contains("\n") {
            inputText = inputText.replacingOccurrences(of: "\n", with: "")
            addText()
        }
    }
    
    // MARK: - Edit Mode Methods
    func saveEditedGroup(groupId: UUID, newText: String, newSpeaker: Speaker) {
        // Find the element to edit - it should be the one with the matching groupId
        // In our grouped system, the groupId matches the first element's ID in the group
        guard let elementIndex = screenplayElements.firstIndex(where: { $0.id == groupId }) else { 
            print("❌ Could not find element with groupId: \(groupId)")
            return 
        }
        
        let originalElement = screenplayElements[elementIndex]
        
        // Record undo action
        undoManager.recordAction(.editScreenplayElement(
            id: originalElement.id,
            oldContent: originalElement.content,
            newContent: newText,
            oldSpeaker: originalElement.speaker,
            newSpeaker: newSpeaker
        ))
        
        // Update the element
        screenplayElements[elementIndex] = ScreenplayElement(
            id: originalElement.id,
            type: originalElement.type,
            content: newText,
            speaker: newSpeaker
        )
        
        // Update legacy textlines system if needed
        if let textlineIndex = textlines.firstIndex(where: { $0.id == groupId }) {
            textlines[textlineIndex] = SpeakerText(id: groupId, speaker: newSpeaker, text: newText)
        }
        
        print("✅ Successfully edited element \(groupId): '\(newText)' by \(newSpeaker)")
        setNextSpeakerBasedOnLastText()
    }
    
    func exitEditMode() {
        isEditingText = false
        editingTextId = nil
        editingGroupId = nil
        editingOriginalSpeaker = nil
    }
    
    func updateText(withId id: UUID, newText: String, newSpeaker: Speaker) {
        guard let index = textlines.firstIndex(where: { $0.id == id }) else { return }
        
        // Create new speakerText with updated text but same ID and speaker
        let updatedText = SpeakerText(id: id, speaker: newSpeaker, text: newText)
        textlines[index] = updatedText
        
        // Update the selected speaker to match the change
        selectedSpeaker = newSpeaker
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
    
        // MARK: - Flag Management (works for both textlines and screenplay elements)
    func toggleFlag(for id: UUID) {
        let wasAdd = !flaggedTextIds.contains(id)
        print("🚩 toggleFlag called for ID: \(id), wasAdd: \(wasAdd)")
        print("🚩 Current flaggedTextIds: \(flaggedTextIds)")
        
        // Record undo action
        undoManager.recordAction(.toggleFlag(id, wasAdd))
        
        if flaggedTextIds.contains(id) {
            flaggedTextIds.remove(id)
            print("🚩 Removed flag for ID: \(id)")
        } else {
            flaggedTextIds.insert(id)
            print("🚩 Added flag for ID: \(id)")
        }
        print("🚩 Updated flaggedTextIds: \(flaggedTextIds)")
    }

    func isTextFlagged(_ textId: UUID) -> Bool {
        flaggedTextIds.contains(textId)
    }
    
    func isElementFlagged(_ elementId: UUID) -> Bool {
        flaggedTextIds.contains(elementId)
    }
    
    // MARK: - Screenplay Element Management
    func deleteScreenplayElement(withId id: UUID) {
        guard let index = screenplayElements.firstIndex(where: { $0.id == id }) else { return }
        let element = screenplayElements[index]
        
        // Record undo action
        undoManager.recordAction(.deleteScreenplayElement(element, index))
        
        screenplayElements.removeAll { $0.id == id }
        flaggedTextIds.remove(id)
        
        // If we deleted the last element and we're in fullscreen mode, exit to writing mode
        if screenplayElements.isEmpty && isFullscreenMode {
            exitFullscreenMode()
        }
    }
    
    func getSpeakerName(for speaker: Speaker) -> String {
        return speaker.displayName(customNames: customSpeakerNames)
    }
    
    // MARK: - Session Management
    func loadSession(_ session: DialogSession) {
        textlines = session.textlines
        screenplayElements = session.screenplayElements
        customSpeakerNames = session.customSpeakerNames
        flaggedTextIds = session.flaggedTextIds
        // Reset input state
        inputText = ""
        setNextSpeakerBasedOnLastText()
    }
    
    // MARK: - Speaker Management
    func setNextSpeakerBasedOnLastText() {
        // Look for the last dialogue element to determine next speaker
        if let lastDialogue = screenplayElements.last(where: { $0.type == .dialogue }),
           let speaker = lastDialogue.speaker {
            // Set the speaker to the opposite of the last dialogue's speaker
            selectedSpeaker = speaker == .a ? .b : .a
        } else {
            // If no dialogue elements exist, default to speaker A
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
        // Use new screenplay elements if available, otherwise fall back to legacy textlines
        let elementsToExport = screenplayElements.isEmpty ? textlines.map { $0.toScreenplayElement() } : screenplayElements
        
        var fdxElements: [String] = []
        var currentSpeaker: Speaker? = nil
        var lastSpeakerBeforeAction: Speaker? = nil
        
        for (index, element) in elementsToExport.enumerated() {
            let escapedContent = escapeXMLText(element.content)
            
            switch element.type {
            case .dialogue:
                // Add character name if speaker changed or is first dialogue
                if let speaker = element.speaker {
                    var shouldAddCharacterName = false
                    var shouldShowContd = false
                    
                    // Always add character name if speaker changed or first dialogue
                    if speaker != currentSpeaker {
                        shouldAddCharacterName = true
                        
                        // Check if this is a continuation (same speaker as before action)
                        if speaker == lastSpeakerBeforeAction {
                            shouldShowContd = shouldShowContdInExport(for: index, elements: elementsToExport)
                        }
                    }
                    
                    if shouldAddCharacterName {
                        let speakerName = escapeXMLText(speaker.displayName(customNames: customSpeakerNames))
                        let characterName = shouldShowContd ? "\(speakerName) (CONT'D)" : speakerName
                        fdxElements.append("""
                        <Paragraph Type="Character">
                        <Text>\(characterName)</Text>
                        </Paragraph>
                        """)
                        currentSpeaker = speaker
                    }
                }
                
                fdxElements.append("""
                <Paragraph Type="Dialogue">
                <Text>\(escapedContent)</Text>
                </Paragraph>
                """)
                
            case .parenthetical:
                // Add character name if speaker changed
                if let speaker = element.speaker {
                    var shouldAddCharacterName = false
                    var shouldShowContd = false
                    
                    if speaker != currentSpeaker {
                        shouldAddCharacterName = true
                        
                        // Check if this is a continuation (same speaker as before action)
                        if speaker == lastSpeakerBeforeAction {
                            shouldShowContd = shouldShowContdInExport(for: index, elements: elementsToExport)
                        }
                    }
                    
                    if shouldAddCharacterName {
                        let speakerName = escapeXMLText(speaker.displayName(customNames: customSpeakerNames))
                        let characterName = shouldShowContd ? "\(speakerName) (CONT'D)" : speakerName
                        fdxElements.append("""
                        <Paragraph Type="Character">
                        <Text>\(characterName)</Text>
                        </Paragraph>
                        """)
                        currentSpeaker = speaker
                    }
                }
                
                // Wrap parenthetical content in parentheses
                fdxElements.append("""
                <Paragraph Type="Parenthetical">
                <Text>(\(escapedContent))</Text>
                </Paragraph>
                """)
                
            case .action:
                // Remember the last speaker before this action
                lastSpeakerBeforeAction = currentSpeaker
                // Reset current speaker for actions
                currentSpeaker = nil
                fdxElements.append("""
                <Paragraph Type="Action">
                <Text>\(escapedContent)</Text>
                </Paragraph>
                """)
            }
        }
        
        let fdxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="1">
        <Content>
        \(fdxElements.joined(separator: "\n"))
        </Content>
        </FinalDraft>
        """
        return fdxContent.data(using: .utf8) ?? Data()
    }
    
    private func shouldShowContdInExport(for index: Int, elements: [ScreenplayElement]) -> Bool {
        guard index > 0 && index < elements.count else { return false }
        
        let currentElement = elements[index]
        guard let currentSpeaker = currentElement.speaker else { return false }
        
        // Look backwards to find the previous dialogue from the same speaker
        for i in (0..<index).reversed() {
            let previousElement = elements[i]
            
            if let previousSpeaker = previousElement.speaker {
                // If we find the same speaker, check if there's an action in between
                if previousSpeaker == currentSpeaker {
                    // Check if there's an action element between them
                    for j in (i+1)..<index {
                        let intermediateElement = elements[j]
                        if intermediateElement.type == .action {
                            return true // Found action between same speaker → show CONT'D
                        }
                    }
                    return false // Same speaker but no action in between
                } else {
                    return false // Different speaker found before any action
                }
            } else if previousElement.type == .action {
                // Continue looking backwards past this action
                continue
            }
        }
        
        return false
    }
    
    private func escapeXMLText(_ text: String) -> String {
        var escaped = text
        
        // Escape XML special characters
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        
        return escaped
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
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        
        return "\(title)_\(dateString).\(suffix)"
    }
    
    private func generateTitle() -> String {
        // Use the current title if it exists and is not empty
        if !currentTitle.isEmpty {
            // Clean title for filename (remove special characters)
            let cleanTitle = currentTitle.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "")
            return cleanTitle.isEmpty ? "NewDialog" : cleanTitle
        }
        
        // Fallback to generating from first text if no title is set
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
        currentTitle = trimmedTitle.isEmpty ? "New Dialogue".localized : trimmedTitle
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
    
    // MARK: - Redo Methods
    func redoAddText(_ speakerText: SpeakerText) {
        textlines.append(speakerText)
    }
    
    func redoDeleteText(_ speakerText: SpeakerText) {
        textlines.removeAll { $0.id == speakerText.id }
        flaggedTextIds.remove(speakerText.id)
    }
    
    func redoEditText(id: UUID, newText: String, newSpeaker: Speaker) {
        guard let index = textlines.firstIndex(where: { $0.id == id }) else { return }
        let updatedText = SpeakerText(id: id, speaker: newSpeaker, text: newText)
        textlines[index] = updatedText
    }
    
    func redoToggleFlag(textId: UUID, wasAdd: Bool) {
        if wasAdd {
            flaggedTextIds.insert(textId)
        } else {
            flaggedTextIds.remove(textId)
        }
    }
    
    func redoRenameSpeaker(_ speaker: Speaker, newName: String?) {
        customSpeakerNames[speaker] = newName
    }
    
    func redoDeleteScreenplayElement(_ element: ScreenplayElement) {
        screenplayElements.removeAll { $0.id == element.id }
        flaggedTextIds.remove(element.id)
        textlines.removeAll { $0.id == element.id }
    }
    
    func redoEditScreenplayElement(id: UUID, newContent: String, newSpeaker: Speaker?) {
        guard let index = screenplayElements.firstIndex(where: { $0.id == id }) else { return }
        let originalElement = screenplayElements[index]
        
        screenplayElements[index] = ScreenplayElement(
            id: originalElement.id,
            type: originalElement.type,
            content: newContent,
            speaker: newSpeaker
        )
        
        // Also update legacy textlines system if needed
        if let textlineIndex = textlines.firstIndex(where: { $0.id == id }) {
            textlines[textlineIndex] = SpeakerText(id: id, speaker: newSpeaker ?? .a, text: newContent)
        }
    }
    
    func undoAddScreenplayElement(_ element: ScreenplayElement) {
        screenplayElements.removeAll { $0.id == element.id }
        flaggedTextIds.remove(element.id)
        
        // Also remove from legacy textlines if present
        textlines.removeAll { $0.id == element.id }
    }
    
    func redoAddScreenplayElement(_ element: ScreenplayElement) {
        screenplayElements.append(element)
        
        // Also add to legacy textlines if it's dialogue
        if element.type == .dialogue, let speaker = element.speaker {
            let speakerText = SpeakerText(id: element.id, speaker: speaker, text: element.content)
            textlines.append(speakerText)
        }
    }
    
    func undoDeleteScreenplayElement(_ element: ScreenplayElement, at originalIndex: Int) {
        // Insert at the original position if it's valid, otherwise append
        if originalIndex >= 0 && originalIndex <= screenplayElements.count {
            screenplayElements.insert(element, at: originalIndex)
        } else {
            screenplayElements.append(element)
        }
    }
    
    func undoEditScreenplayElement(id: UUID, oldContent: String, oldSpeaker: Speaker?) {
        guard let index = screenplayElements.firstIndex(where: { $0.id == id }) else { return }
        let originalElement = screenplayElements[index]
        
        // Restore the original content and speaker
        screenplayElements[index] = ScreenplayElement(
            id: originalElement.id,
            type: originalElement.type,
            content: oldContent,
            speaker: oldSpeaker
        )
        
        // Also update legacy textlines system if needed
        if let textlineIndex = textlines.firstIndex(where: { $0.id == id }) {
            textlines[textlineIndex] = SpeakerText(id: id, speaker: oldSpeaker ?? .a, text: oldContent)
        }
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
    
    func canRedo() -> Bool {
        return undoManager.canRedo
    }
    
    func performRedo() {
        undoManager.performRedo(dialogViewModel: self)
    }
} 