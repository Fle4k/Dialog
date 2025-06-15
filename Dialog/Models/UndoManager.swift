import Foundation
import SwiftUI

// MARK: - Undo Action Types
enum UndoAction {
    case addText(SpeakerText)
    case deleteText(SpeakerText, Int) // text and its original index
    case editText(id: UUID, oldText: String, newText: String, oldSpeaker: Speaker, newSpeaker: Speaker)
    case toggleFlag(UUID, Bool) // textId and wasAdd (true if flag was added, false if removed)
    case renameSpeaker(Speaker, String?, String?) // speaker, oldName, newName
    case deleteSession(DialogSession, Int) // session and its original index
    case renameSession(UUID, String, String) // sessionId, oldTitle, newTitle
    case deleteScreenplayElement(ScreenplayElement, Int) // element and its original index
    case editScreenplayElement(id: UUID, oldContent: String, newContent: String, oldSpeaker: Speaker?, newSpeaker: Speaker?)
}

// MARK: - Undo Manager
@MainActor
class AppUndoManager: ObservableObject {
    static let shared = AppUndoManager()
    
    @Published private var undoStack: [UndoAction] = []
    private let maxUndoActions = 50
    
    private init() {}
    
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var lastActionDescription: String {
        guard let lastAction = undoStack.last else { return "" }
        
        switch lastAction {
        case .addText(_):
            return "Add Text"
        case .deleteText(_, _):
            return "Delete Text"
        case .editText(_, _, _, _, _):
            return "Edit Text"
        case .toggleFlag(_, let wasAdd):
            return wasAdd ? "Flag Text" : "Unflag Text"
        case .renameSpeaker(_, _, _):
            return "Rename Speaker"
        case .deleteSession(_, _):
            return "Delete Dialog"
        case .renameSession(_, _, _):
            return "Rename Dialog"
        case .deleteScreenplayElement(_, _):
            return "Delete Element"
        case .editScreenplayElement(_, _, _, _, _):
            return "Edit Element"
        }
    }
    
    func recordAction(_ action: UndoAction) {
        undoStack.append(action)
        
        // Limit undo stack size
        if undoStack.count > maxUndoActions {
            undoStack.removeFirst()
        }
        
        objectWillChange.send()
    }
    
    func performUndo(dialogViewModel: DialogViewModel? = nil, mainMenuViewModel: MainMenuViewModel? = nil) {
        guard let action = undoStack.popLast() else { return }
        
        switch action {
        case .addText(let speakerText):
            dialogViewModel?.undoAddText(speakerText)
            
        case .deleteText(let speakerText, let originalIndex):
            dialogViewModel?.undoDeleteText(speakerText, at: originalIndex)
            
        case .editText(let id, let oldText, _, let oldSpeaker, _):
            dialogViewModel?.undoEditText(id: id, oldText: oldText, oldSpeaker: oldSpeaker)
            
        case .toggleFlag(let textId, let wasAdd):
            dialogViewModel?.undoToggleFlag(textId: textId, wasAdd: wasAdd)
            
        case .renameSpeaker(let speaker, let oldName, _):
            dialogViewModel?.undoRenameSpeaker(speaker, oldName: oldName)
            
        case .deleteSession(let session, let originalIndex):
            mainMenuViewModel?.undoDeleteSession(session, at: originalIndex)
            
        case .renameSession(let sessionId, let oldTitle, _):
            mainMenuViewModel?.undoRenameSession(sessionId: sessionId, oldTitle: oldTitle)
            
        case .deleteScreenplayElement(let element, let originalIndex):
            dialogViewModel?.undoDeleteScreenplayElement(element, at: originalIndex)
            
        case .editScreenplayElement(let id, let oldContent, _, let oldSpeaker, _):
            dialogViewModel?.undoEditScreenplayElement(id: id, oldContent: oldContent, oldSpeaker: oldSpeaker)
        }
        
        objectWillChange.send()
    }
    
    func clearUndoStack() {
        undoStack.removeAll()
        objectWillChange.send()
    }
} 