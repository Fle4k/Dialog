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
    private var lastDeletedDialogue: (index: Int, dialogue: Dialogue)?
    
    init(scene: DialogueScene, onSceneUpdate: @escaping (DialogueScene) -> Void) {
        self.scene = scene
        self.onSceneUpdate = onSceneUpdate
        self.dialogues = scene.dialogues
        self.speakerAName = scene.speakerAName
        self.speakerBName = scene.speakerBName
    }
    
    private func updateScene() {
        var updatedScene = scene
        updatedScene.dialogues = dialogues
        updatedScene.speakerAName = speakerAName
        updatedScene.speakerBName = speakerBName
        updatedScene.updatedAt = Date()
        onSceneUpdate(updatedScene)
        scene = updatedScene
    }
    
    func addDialogue() {
        let textToAdd = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !textToAdd.isEmpty else {
            currentText = ""
            return
        }
        
        let dialogue = Dialogue(speaker: currentSpeaker, text: textToAdd)
        dialogues.append(dialogue)
        updateScene()
        
        // Clear text immediately
        currentText = ""
    }
    
    func switchSpeaker(to newSpeaker: String) {
        currentSpeaker = newSpeaker
    }
    
    func renameSpeakerA(to newName: String) {
        speakerAName = newName
        if currentSpeaker == scene.speakerAName {
            currentSpeaker = newName
        }
        updateExistingDialogues(from: scene.speakerAName, to: newName)
        updateScene()
    }
    
    func renameSpeakerB(to newName: String) {
        speakerBName = newName
        if currentSpeaker == scene.speakerBName {
            currentSpeaker = newName
        }
        updateExistingDialogues(from: scene.speakerBName, to: newName)
        updateScene()
    }
    
    private func updateExistingDialogues(from oldName: String, to newName: String) {
        for (index, dialogue) in dialogues.enumerated() {
            if dialogue.speaker == oldName {
                dialogues[index] = Dialogue(speaker: newName, text: dialogue.text)
            }
        }
        updateScene()
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
            updateScene()
        }
    }
    
    @MainActor
    func undoLastAction() {
        if let lastDeleted = lastDeletedDialogue {
            dialogues.insert(lastDeleted.dialogue, at: min(lastDeleted.index, dialogues.count))
            updateScene()
            lastDeletedDialogue = nil
        }
    }
    
    func deleteDialogue(id: UUID) {
        if let index = dialogues.firstIndex(where: { $0.id == id }) {
            lastDeletedDialogue = (index, dialogues[index])
            dialogues.remove(at: index)
            updateScene()
        }
    }
} 