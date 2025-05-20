import Foundation
import SwiftUI

@MainActor
class DialogueViewModel: ObservableObject {
    @Published var dialogues: [Dialogue] = []
    @Published var currentSpeaker: String = "A"
    @Published var currentText: String = ""
    @Published var isReadyForInput: Bool = true
    @Published var speakerAName: String = "A"
    @Published var speakerBName: String = "B"
    
    private var scene: DialogueScene
    private var onSceneUpdate: (DialogueScene) -> Void
    
    init(scene: DialogueScene, onSceneUpdate: @escaping (DialogueScene) -> Void) {
        self.scene = scene
        self.onSceneUpdate = onSceneUpdate
        self.dialogues = scene.dialogues
        // Always start with A and B for new scenes
        self.speakerAName = "A"
        self.speakerBName = "B"
    }
    
    func addDialogue() {
        guard !currentText.isEmpty else { return }
        let dialogue = Dialogue(speaker: currentSpeaker, text: currentText)
        dialogues.append(dialogue)
        
        // Update the scene
        scene.dialogues = dialogues
        scene.updatedAt = Date()
        onSceneUpdate(scene)
        
        // Clear the text field after submission
        currentText = ""
    }
    
    func switchSpeaker(to newSpeaker: String) {
        currentSpeaker = newSpeaker.uppercased()
    }
    
    func renameSpeakerA(to newName: String) {
        speakerAName = newName
        if currentSpeaker == "A" {
            currentSpeaker = newName
        }
        updateExistingDialogues(from: "A", to: newName)
    }
    
    func renameSpeakerB(to newName: String) {
        speakerBName = newName
        if currentSpeaker == "B" {
            currentSpeaker = newName
        }
        updateExistingDialogues(from: "B", to: newName)
    }
    
    private func updateExistingDialogues(from oldName: String, to newName: String) {
        for (index, dialogue) in dialogues.enumerated() {
            if dialogue.speaker == oldName {
                dialogues[index] = Dialogue(speaker: newName, text: dialogue.text)
            }
        }
        scene.dialogues = dialogues
        scene.updatedAt = Date()
        onSceneUpdate(scene)
    }
    
    func startNewInput() {
        isReadyForInput = true
    }
    
    func exportToText() -> String {
        var result = ""
        var lastSpeaker: String? = nil
        for dialogue in dialogues {
            if let last = lastSpeaker, last != dialogue.speaker {
                result += "\n" // Add an extra empty line when the speaker changes
            }
            result += "\(dialogue.speaker)\n\(dialogue.text)\n\n"
            lastSpeaker = dialogue.speaker
        }
        return result
    }
    
    func exportToFDX() throws -> URL {
        let dialogueLines = dialogues.map { DialogueLine(speaker: $0.speaker, text: $0.text) }
        return try FDXExportService.exportToFDX(dialogue: dialogueLines, sceneTitle: scene.title)
    }
    
    func exportToRTF() throws -> URL {
        let dialogueLines = dialogues.map { DialogueLine(speaker: $0.speaker, text: $0.text) }
        return try RTFExportService.exportToRTF(dialogue: dialogueLines, sceneTitle: scene.title)
    }
    
    func exportToTextFile() throws -> URL {
        let text = exportToText()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(scene.title).txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    func updateDialogue(id: UUID, newSpeaker: String, newText: String) {
        if let index = dialogues.firstIndex(where: { $0.id == id }) {
            dialogues[index] = Dialogue(speaker: newSpeaker, text: newText)
            scene.dialogues = dialogues
            scene.updatedAt = Date()
            onSceneUpdate(scene)
        }
    }
} 