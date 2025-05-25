import SwiftUI

// MARK: - Dialog View Model
@MainActor
final class DialogViewModel: ObservableObject {
    @Published var textlines: [Message] = []
    @Published var selectedSpeaker: Speaker = .a
    @Published var inputText: String = ""
    @Published var customSpeakerNames: [Speaker: String] = [:]
    @Published var flaggedMessageIds: Set<UUID> = []
    
    // MARK: - Edit Mode Properties
    @Published var isEditingMessage: Bool = false
    @Published var editingMessageId: UUID? = nil
    
    func addMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        if isEditingMessage, let editingId = editingMessageId {
            // Update existing message
            updateMessage(withId: editingId, newText: trimmedText)
        } else {
            // Add new message
            let message = Message(speaker: selectedSpeaker, text: trimmedText)
            textlines.append(message)
            selectedSpeaker.toggle()
        }
        
        // Reset input state
        inputText = ""
        exitEditMode()
    }
    
    func handleNewlineInput() {
        if inputText.contains("\n") {
            inputText = inputText.replacingOccurrences(of: "\n", with: "")
            addMessage()
        }
    }
    
    // MARK: - Edit Mode Methods
    func startEditingMessage(_ message: Message) {
        isEditingMessage = true
        editingMessageId = message.id
        inputText = message.text
        selectedSpeaker = message.speaker
    }
    
    func exitEditMode() {
        isEditingMessage = false
        editingMessageId = nil
    }
    
    func updateMessage(withId id: UUID, newText: String) {
        guard let index = textlines.firstIndex(where: { $0.id == id }) else { return }
        
        // Create new message with updated text but same ID and speaker
        let updatedMessage = Message(id: id, speaker: textlines[index].speaker, text: newText)
        textlines[index] = updatedMessage
    }
    
    func renameSpeaker(_ speaker: Speaker, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        customSpeakerNames[speaker] = trimmedName.isEmpty ? nil : trimmedName
    }
    
    func deleteMessage(withId id: UUID) {
        textlines.removeAll { $0.id == id }
        flaggedMessageIds.remove(id)
    }
    
    func deleteMessage(at offsets: IndexSet) {
        for offset in offsets {
            let message = textlines[offset]
            flaggedMessageIds.remove(message.id)
        }
        textlines.remove(atOffsets: offsets)
    }
    
    func toggleFlag(for messageId: UUID) {
        if flaggedMessageIds.contains(messageId) {
            flaggedMessageIds.remove(messageId)
        } else {
            flaggedMessageIds.insert(messageId)
        }
    }
    
    func isMessageFlagged(_ messageId: UUID) -> Bool {
        flaggedMessageIds.contains(messageId)
    }
    
    func getSpeakerName(for speaker: Speaker) -> String {
        return speaker.displayName(customNames: customSpeakerNames)
    }
    
    // MARK: - Session Management
    func loadSession(_ session: DialogueSession) {
        textlines = session.textlines
        customSpeakerNames = session.customSpeakerNames
        flaggedMessageIds = session.flaggedMessageIds
        // Reset input state
        inputText = ""
        selectedSpeaker = .a
    }
    
    // MARK: - Export Methods
    func exportToText() -> String {
        var result = ""
        for message in textlines {
            let speakerName = message.speaker.displayName(customNames: customSpeakerNames)
            result += "\(speakerName): \(message.text)\n\n"
        }
        return result
    }
    
    func exportToRTF() -> Data {
        let text = exportToText()
        let rtfString = "{\\rtf1\\ansi\\deff0 {\\fonttbl \\f0 Times New Roman;} \\f0\\fs24 \(text.replacingOccurrences(of: "\n", with: "\\par "))}"
        return rtfString.data(using: .utf8) ?? Data()
    }
    
    func exportToFDX() -> Data {
        let fdxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="1">
        <Content>
        \(textlines.map { message in
            let speakerName = message.speaker.displayName(customNames: customSpeakerNames)
            return """
            <Paragraph Type="Character">
            <Text>\(speakerName)</Text>
            </Paragraph>
            <Paragraph Type="Dialogue">
            <Text>\(message.text)</Text>
            </Paragraph>
            """
        }.joined(separator: "\n"))
        </Content>
        </FinalDraft>
        """
        return fdxContent.data(using: .utf8) ?? Data()
    }
} 