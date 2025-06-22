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
    @Published var isEditingElementType: Bool = false
    @Published var editingGroupId: UUID? = nil
    @Published var editingOriginalSpeaker: Speaker? = nil
    @Published var insertionPosition: Int? = nil // For inserting elements at specific positions
    
    // MARK: - UI State Properties (moved from View)
    @Published var showInputArea: Bool = false
    @Published var isFullscreenMode: Bool = false
    @Published var shouldFocusInput: Bool = false
    @Published var currentTitle: String = ""
    
    // MARK: - Cached Properties for Performance
    @Published private(set) var groupedElements: [GroupedElement] = []
    
    // MARK: - UI State Management
    func initializeForNewSession() {
        currentTitle = ""
        // Start in writing mode for immediate dialog writing
        isFullscreenMode = false
        updateGroupedElements()
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
        // Use smoother state transition sequence
        isFullscreenMode = true
        
        // Delay hiding input area to allow smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.showInputArea = false
            self.shouldFocusInput = false
        }
    }
    
    func exitFullscreenMode() {
        // Smoother transition sequence
        isFullscreenMode = false
        
        // Add slight delay before showing input to prevent animation conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showInputAreaWithFocus()
        }
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
    
    func startEditingElement(_ element: ScreenplayElement) {
        print("🛠️ startEditingElement: STARTING edit for element \(element.id) with content '\(element.content)'")
        
        isEditingText = true
        isEditingElementType = true  // Enable element type editing menu for individual elements too
        editingGroupId = element.id // Use element ID directly for individual editing
        editingOriginalSpeaker = element.speaker
        
        // Edit the specific element
        inputText = element.content
        selectedSpeaker = element.speaker ?? .a
        selectedElementType = element.type
        
        print("🛠️ startEditingElement: Set isEditingText=\(isEditingText), isEditingElementType=\(isEditingElementType), editingGroupId=\(editingGroupId?.uuidString ?? "nil")")
        print("🛠️ startEditingElement: Set inputText='\(inputText)', selectedSpeaker=\(selectedSpeaker), selectedElementType=\(selectedElementType)")
        
        if isFullscreenMode {
            exitFullscreenMode()
        } else {
            showInputAreaWithFocus()
        }
        
        print("🛠️ startEditingElement: COMPLETED - isEditingText=\(isEditingText), isEditingElementType=\(isEditingElementType), editingGroupId=\(editingGroupId?.uuidString ?? "nil")")
    }
    
    func startEditingGroup(_ groupedElement: GroupedElement) {
        print("🛠️ startEditingGroup: STARTING edit for group \(groupedElement.id)")
        print("🛠️ startEditingGroup: BEFORE setting - isEditingText=\(isEditingText), editingGroupId=\(editingGroupId?.uuidString ?? "nil")")
        
        isEditingText = true
        isEditingElementType = true  // This enables the horizontal menu with +extensions
        editingGroupId = groupedElement.id
        editingOriginalSpeaker = groupedElement.speaker
        
        print("🛠️ startEditingGroup: AFTER setting - isEditingText=\(isEditingText), isEditingElementType=\(isEditingElementType), editingGroupId=\(editingGroupId?.uuidString ?? "nil")")
        
        // Edit the first element in the group (whether dialogue, parenthetical, or action)
        if let firstElement = groupedElement.elements.first {
            inputText = firstElement.content
            selectedSpeaker = firstElement.speaker ?? groupedElement.speaker ?? .a
            selectedElementType = firstElement.type
            
            print("🛠️ startEditingGroup: Editing first element with content '\(firstElement.content)', type=\(firstElement.type)")
        }
        
        print("🛠️ startEditingGroup: BEFORE showInputAreaWithFocus - isEditingText=\(isEditingText), editingGroupId=\(editingGroupId?.uuidString ?? "nil")")
        
        if isFullscreenMode {
            exitFullscreenMode()
        } else {
            showInputAreaWithFocus()
        }
        
        print("🛠️ startEditingGroup: COMPLETED - isEditingText=\(isEditingText), isEditingElementType=\(isEditingElementType), editingGroupId=\(editingGroupId?.uuidString ?? "nil")")
    }
    
    func startEditingElementType(_ element: ScreenplayElement) {
        isEditingElementType = true
        editingGroupId = element.id // Use element ID for element type editing
        editingOriginalSpeaker = element.speaker
        
        // Set the current element type to be edited
        selectedElementType = element.type
        selectedSpeaker = element.speaker ?? .a
        
        if isFullscreenMode {
            exitFullscreenMode()
        } else {
            showInputAreaWithFocus()
        }
    }
    
    func cancelEditMode() {
        exitEditMode()
        inputText = ""
        // Always return to dialog mode when canceling edit
        selectedElementType = .dialogue
        setNextSpeakerBasedOnLastText()
        // Don't hide input area - stay in writing mode
        showInputAreaWithFocus()
        print("🔄 Cancel edit: Reset to dialog mode, next speaker: \(selectedSpeaker)")
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
            // We're editing - could be individual element or group
            saveEditedElement(elementId: editingGroupId, newText: trimmedText, newSpeaker: selectedSpeaker, newType: selectedElementType)
            
            // Add haptic feedback for successful edit confirmation
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        } else {
            // Add new screenplay element
            addScreenplayElement()
        }
        
        inputText = ""
        
        // Check if we were in edit mode before exiting
        let wasEditing = isEditingText || isEditingElementType
        
        exitEditMode()
        
        // After editing, always return to writing mode for continued dialogue writing
        if wasEditing {
            // Reset to dialog mode and stay in writing mode
            selectedElementType = .dialogue
            showInputAreaWithFocus()
            print("🔄 Post-edit: Returned to writing mode in dialog mode")
        } else {
            // Only auto-focus and scroll for new content, not when editing existing content
            // Stay in writing mode after adding text for continuous dialog writing
            showInputAreaWithFocus()
        }
    }
    
    func addScreenplayElement() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        print("🟢 addScreenplayElement START: selectedElementType=\(selectedElementType), selectedSpeaker=\(selectedSpeaker)")
        
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
        
        print("🎭 addScreenplayElement: Creating element with type \(selectedElementType), speaker \(speaker?.rawValue ?? "nil"), content: '\(processedContent)'")
        
        // Record undo action for screenplay element
        undoManager.recordAction(.addScreenplayElement(element))
        
        // Insert at specific position if set (for parentheticals in edit mode), otherwise append
        if let insertAtIndex = insertionPosition {
                    screenplayElements.insert(element, at: insertAtIndex)
        print("🎭 addScreenplayElement: Inserted element at position \(insertAtIndex)")
        updateGroupedElements()
            // Clear insertion position after use
            insertionPosition = nil
        } else {
                    screenplayElements.append(element)
        print("🎭 addScreenplayElement: Appended element to end")
        updateGroupedElements()
        }
        
        print("🟡 addScreenplayElement BEFORE handleElementTypeSpecificLogic: selectedElementType=\(selectedElementType), selectedSpeaker=\(selectedSpeaker)")
        
        // Handle element type specific logic
        handleElementTypeSpecificLogic()
        
        print("🔴 addScreenplayElement END: selectedElementType=\(selectedElementType), selectedSpeaker=\(selectedSpeaker)")
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
            // Check the second-to-last element (since we just added the current element)
            let previousElement = screenplayElements.count >= 2 ? screenplayElements[screenplayElements.count - 2] : nil
            let isFollowingParenthetical = previousElement?.type == .parenthetical && previousElement?.speaker == selectedSpeaker
            
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
            
        case .offScreen, .voiceOver, .text:
            // These are dialogue variants - always toggle to other speaker after adding
            let originalType = selectedElementType
            selectedElementType = .dialogue
            selectedSpeaker.toggle()
            print("🔄 After \(originalType): reset to dialogue, toggled speaker to \(selectedSpeaker)")
        }
    }
    
    func handleNewlineInput() {
        if inputText.contains("\n") {
            inputText = inputText.replacingOccurrences(of: "\n", with: "")
            addText()
        }
    }
    
    // MARK: - Edit Mode Methods
    func exitEditMode() {
        print("🛠️ exitEditMode: CALLED - before: isEditingText=\(isEditingText), editingGroupId=\(editingGroupId?.uuidString ?? "nil")")
        isEditingText = false
        isEditingElementType = false
        editingGroupId = nil
        editingOriginalSpeaker = nil
        insertionPosition = nil
        print("🛠️ exitEditMode: COMPLETED - after: isEditingText=\(isEditingText), editingGroupId=\(editingGroupId?.uuidString ?? "nil")")
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
        updateGroupedElements()
        
        // If we deleted the last element and we're in fullscreen mode, exit to writing mode
        if screenplayElements.isEmpty && isFullscreenMode {
            exitFullscreenMode()
        }
    }
    
    func removeParentheticalCompletely(elementId: UUID) {
        guard let index = screenplayElements.firstIndex(where: { $0.id == elementId }) else { 
            print("❌ Could not find parenthetical with ID: \(elementId)")
            return 
        }
        
        let element = screenplayElements[index]
        print("🗑️ removeParentheticalCompletely: Removing parenthetical '\(element.content)'")
        
        // Record undo action
        undoManager.recordAction(.deleteScreenplayElement(element, index))
        
        // Remove the parenthetical completely
        screenplayElements.removeAll { $0.id == elementId }
        flaggedTextIds.remove(elementId)
        updateGroupedElements()
        
        // Clear input text so parenthetical content doesn't appear in input field
        inputText = ""
        
        // Reset to normal dialogue writing mode (not parenthetical mode)
        selectedElementType = .dialogue
        
        // Set up for continuing dialogue without the deleted parenthetical content
        setNextSpeakerBasedOnLastText()
        
        print("✅ Successfully removed parenthetical completely - input cleared, back to dialogue mode")
    }
    
    func removeActionCompletely(elementId: UUID) {
        guard let index = screenplayElements.firstIndex(where: { $0.id == elementId }) else { 
            print("❌ Could not find action with ID: \(elementId)")
            return 
        }
        
        let element = screenplayElements[index]
        print("🗑️ removeActionCompletely: Removing action '\(element.content)'")
        
        // Record undo action
        undoManager.recordAction(.deleteScreenplayElement(element, index))
        
        // Remove the action completely
        screenplayElements.removeAll { $0.id == elementId }
        flaggedTextIds.remove(elementId)
        updateGroupedElements()
        
        // Clear input text so action content doesn't appear in input field
        inputText = ""
        
        // Reset to normal dialogue writing mode
        selectedElementType = .dialogue
        
        // Set up for continuing dialogue without the deleted action content
        setNextSpeakerBasedOnLastText()
        
        // If we deleted the last element and we're in fullscreen mode, exit to writing mode
        if screenplayElements.isEmpty && isFullscreenMode {
            exitFullscreenMode()
        } else {
            // Stay in writing mode for continued writing
            showInputAreaWithFocus()
        }
        
        print("✅ Successfully removed action completely - input cleared, back to dialogue mode")
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
        updateGroupedElements()
    }
    
    // MARK: - Speaker Management
    func setNextSpeakerBasedOnLastText() {
        // Look for the last dialogue-like element (dialogue, off screen, voice over, text) to determine next speaker
        if let lastDialogue = screenplayElements.last(where: { $0.type.requiresSpeaker && $0.type != .parenthetical }),
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
            case .dialogue, .offScreen, .voiceOver, .text:
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
                        var characterName = speakerName
                        
                        if shouldShowContd {
                            characterName = "\(speakerName) (CONT'D)"
                        } else if let extensionString = element.type.characterExtension {
                            characterName = "\(speakerName) \(extensionString)"
                        }
                        
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
                        var characterName = speakerName
                        
                        if shouldShowContd {
                            characterName = "\(speakerName) (CONT'D)"
                        } else if let extensionString = element.type.characterExtension {
                            characterName = "\(speakerName) \(extensionString)"
                        }
                        
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
    }
    
    func undoAddScreenplayElement(_ element: ScreenplayElement) {
        screenplayElements.removeAll { $0.id == element.id }
        flaggedTextIds.remove(element.id)
    }
    
    func redoAddScreenplayElement(_ element: ScreenplayElement) {
        screenplayElements.append(element)
    }
    
    func undoDeleteScreenplayElement(_ element: ScreenplayElement, at originalIndex: Int) {
        // Insert at the original position if it's valid, otherwise append
        if originalIndex >= 0 && originalIndex <= screenplayElements.count {
            screenplayElements.insert(element, at: originalIndex)
        } else {
            screenplayElements.append(element)
        }
        
        // Update grouped elements so the UI reflects the restored element
        updateGroupedElements()
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
    
    func saveEditedElement(elementId: UUID, newText: String, newSpeaker: Speaker, newType: ScreenplayElementType) {
        guard let elementIndex = screenplayElements.firstIndex(where: { $0.id == elementId }) else { 
            print("❌ Could not find element with ID: \(elementId)")
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
            type: newType,
            content: newText,
            speaker: newSpeaker
        )
        updateGroupedElements()
        
        print("✅ Successfully edited individual element \(elementId): '\(newText)' by \(newSpeaker)")
        
        // After editing any element, always return to dialog mode for better workflow
        selectedElementType = .dialogue
        setNextSpeakerBasedOnLastText()
        
        print("🔄 After editing: Reset to dialog mode, next speaker: \(selectedSpeaker)")
    }
    
    func changeElementType(elementId: UUID, to newType: ScreenplayElementType) {
        guard let elementIndex = screenplayElements.firstIndex(where: { $0.id == elementId }) else { 
            print("❌ Could not find element with ID: \(elementId)")
            return 
        }
        
        let originalElement = screenplayElements[elementIndex]
        
        // Record undo action
        undoManager.recordAction(.editScreenplayElement(
            id: originalElement.id,
            oldContent: originalElement.content,
            newContent: originalElement.content, // Content stays the same
            oldSpeaker: originalElement.speaker,
            newSpeaker: originalElement.speaker // Speaker stays the same
        ))
        
        // Update only the element type, preserve content and speaker
        screenplayElements[elementIndex] = ScreenplayElement(
            id: originalElement.id,
            type: newType,
            content: originalElement.content,
            speaker: newType.requiresSpeaker ? originalElement.speaker : nil
        )
        updateGroupedElements()
        
        print("✅ Successfully changed element type for \(elementId) from \(originalElement.type) to \(newType)")
        
        // Immediately exit editing mode and clear input text
        exitEditMode()
        inputText = ""
        
        // After changing element type, set up for continuing dialogue
        setNextSpeakerBasedOnLastText()
        
        // Stay in writing mode for continued writing
        showInputAreaWithFocus()
    }
    
    func startAddingParentheticalInEditMode() {
        // This method is called when user taps "+Parenthetical" while editing an element
        // Instead of changing the current element, we want to add a new parenthetical ABOVE it
        
        // Get the speaker and position from the element being edited
        var speakerForParenthetical: Speaker = .a
        var insertAtIndex: Int? = nil
        
        if let editingGroupId = editingGroupId,
           let editingElementIndex = screenplayElements.firstIndex(where: { $0.id == editingGroupId }) {
            let editingElement = screenplayElements[editingElementIndex]
            if let elementSpeaker = editingElement.speaker {
                speakerForParenthetical = elementSpeaker
                insertAtIndex = editingElementIndex // Insert BEFORE the element being edited (above it)
                print("🎭 startAddingParentheticalInEditMode: Found editing element at index \(editingElementIndex) with speaker \(elementSpeaker.rawValue)")
            }
        } else {
            print("🎭 startAddingParentheticalInEditMode: Could not find editing element, defaulting to speaker A")
            print("   editingGroupId: \(editingGroupId?.uuidString ?? "nil")")
            print("   screenplayElements count: \(screenplayElements.count)")
        }
        
        print("🎭 startAddingParentheticalInEditMode: Setting up parenthetical for speaker \(speakerForParenthetical.rawValue) at position \(insertAtIndex?.description ?? "end")")
        
        // DON'T exit edit mode completely - we want to stay in edit mode but switch to adding parenthetical
        // Clear the current input text and set up for parenthetical
        inputText = ""
        selectedElementType = .parenthetical
        selectedSpeaker = speakerForParenthetical
        
        // Set the insertion position so the parenthetical gets added above the current line
        insertionPosition = insertAtIndex
        
        // Stay in edit mode but switch to parenthetical input mode
        isEditingText = false // We're no longer editing the original text
        isEditingElementType = false // We're not editing element type either
        // Keep editingGroupId so we know which element we were editing
        
        // Show input area with focus
        showInputArea = true
        
        // Trigger focus after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shouldFocusInput = true
        }
        
        print("🎭 startAddingParentheticalInEditMode: Final setup - selectedSpeaker: \(selectedSpeaker.rawValue), selectedElementType: \(selectedElementType), insertionPosition: \(insertionPosition?.description ?? "nil")")
    }
    
    private func updateGroupedElements() {
        groupedElements = calculateGroupedElements()
    }
    
    private func calculateGroupedElements() -> [GroupedElement] {
        var groupedElements: [GroupedElement] = []
        var i = 0
        
        while i < screenplayElements.count {
            let element = screenplayElements[i]
            
            // Check if this element should start a new group (speaker with potential parenthetical)
            if element.type.requiresSpeaker && element.speaker != nil {
                let speaker = element.speaker!
                var elementsInGroup: [ScreenplayElement] = []
                
                // Add current element
                elementsInGroup.append(element)
                
                // Look ahead for consecutive elements from the same speaker
                var j = i + 1
                while j < screenplayElements.count {
                    let nextElement = screenplayElements[j]
                    // Group together if same speaker and requires speaker
                    if nextElement.speaker == speaker && nextElement.type.requiresSpeaker {
                        elementsInGroup.append(nextElement)
                        j += 1
                    } else {
                        break
                    }
                }
                
                // Create grouped element
                let groupedElement = GroupedElement(
                    id: element.id,
                    speaker: speaker,
                    elements: elementsInGroup
                )
                groupedElements.append(groupedElement)
                
                i = j
            } else {
                // For actions or other standalone elements, create single-element groups
                let groupedElement = GroupedElement(
                    id: element.id,
                    speaker: nil,
                    elements: [element]
                )
                groupedElements.append(groupedElement)
                i += 1
            }
        }
        
        return groupedElements
    }
} 