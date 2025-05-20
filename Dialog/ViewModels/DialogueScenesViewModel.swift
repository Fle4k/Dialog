import Foundation
import SwiftUI

@MainActor
class DialogueScenesViewModel: ObservableObject {
    @Published var scenes: [DialogueScene] = []
    private let saveKey = "savedDialogueScenes"
    
    init() {
        loadScenes()
    }
    
    func addScene(title: String) {
        let scene = DialogueScene(title: title)
        scenes.append(scene)
        saveScenes()
    }
    
    func deleteScene(_ scene: DialogueScene) {
        scenes.removeAll { $0.id == scene.id }
        saveScenes()
    }
    
    func updateScene(_ scene: DialogueScene) {
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[index] = scene
            saveScenes()
        }
    }
    
    func renameScene(id: UUID, newTitle: String) {
        if let index = scenes.firstIndex(where: { $0.id == id }) {
            scenes[index].title = newTitle
            scenes[index].updatedAt = Date()
            saveScenes()
        }
    }
    
    private func saveScenes() {
        if let encoded = try? JSONEncoder().encode(scenes) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadScenes() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([DialogueScene].self, from: data) {
            scenes = decoded
        }
    }
} 