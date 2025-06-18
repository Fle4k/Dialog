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
    case addScreenplayElement(ScreenplayElement) // element that was added
    case deleteScreenplayElement(ScreenplayElement, Int) // element and its original index
    case editScreenplayElement(id: UUID, oldContent: String, newContent: String, oldSpeaker: Speaker?, newSpeaker: Speaker?)
}

// MARK: - Undo Manager
@MainActor
class AppUndoManager: ObservableObject {
    static let shared = AppUndoManager()
    
    @Published private var undoAction: UndoAction? = nil
    @Published private var redoAction: UndoAction? = nil
    
    private init() {}
    
    var canUndo: Bool {
        undoAction != nil
    }
    
    var canRedo: Bool {
        redoAction != nil
    }
    
    var lastActionDescription: String {
        if canRedo {
            return "Redo"
        } else if let action = undoAction {
            switch action {
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
            case .addScreenplayElement(_):
                return "Add Element"
            case .deleteScreenplayElement(_, _):
                return "Delete Element"
            case .editScreenplayElement(_, _, _, _, _):
                return "Edit Element"
            }
        } else {
            return ""
        }
    }
    
    func recordAction(_ action: UndoAction) {
        // Store only the most recent action for undo
        undoAction = action
        // Clear any existing redo when a new action is recorded
        redoAction = nil
        
        objectWillChange.send()
    }
    
    func performUndo(dialogViewModel: DialogViewModel? = nil, mainMenuViewModel: MainMenuViewModel? = nil) {
        guard let action = undoAction else { return }
        
        // Move undo action to redo
        redoAction = action
        undoAction = nil
        
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
            
        case .addScreenplayElement(let element):
            dialogViewModel?.undoAddScreenplayElement(element)
            
        case .deleteScreenplayElement(let element, let originalIndex):
            dialogViewModel?.undoDeleteScreenplayElement(element, at: originalIndex)
            
        case .editScreenplayElement(let id, let oldContent, _, let oldSpeaker, _):
            dialogViewModel?.undoEditScreenplayElement(id: id, oldContent: oldContent, oldSpeaker: oldSpeaker)
        }
        
        objectWillChange.send()
    }
    
    func performRedo(dialogViewModel: DialogViewModel? = nil, mainMenuViewModel: MainMenuViewModel? = nil) {
        guard let action = redoAction else { return }
        
        // Move redo action back to undo
        undoAction = action
        redoAction = nil
        
        // Redo means performing the original action again
        switch action {
        case .addText(let speakerText):
            // Redo add: add the text back
            dialogViewModel?.redoAddText(speakerText)
            
        case .deleteText(let speakerText, _):
            // Redo delete: delete the text again
            dialogViewModel?.redoDeleteText(speakerText)
            
        case .editText(let id, _, let newText, _, let newSpeaker):
            // Redo edit: apply the new text/speaker again
            dialogViewModel?.redoEditText(id: id, newText: newText, newSpeaker: newSpeaker)
            
        case .toggleFlag(let textId, let wasAdd):
            // Redo toggle: toggle again
            dialogViewModel?.redoToggleFlag(textId: textId, wasAdd: wasAdd)
            
        case .renameSpeaker(let speaker, _, let newName):
            // Redo rename: apply the new name again
            dialogViewModel?.redoRenameSpeaker(speaker, newName: newName)
            
        case .deleteSession(let session, _):
            // Redo delete: delete the session again
            mainMenuViewModel?.redoDeleteSession(session)
            
        case .renameSession(let sessionId, _, let newTitle):
            // Redo rename: apply the new title again
            mainMenuViewModel?.redoRenameSession(sessionId: sessionId, newTitle: newTitle)
            
        case .addScreenplayElement(let element):
            // Redo add: add the element back
            dialogViewModel?.redoAddScreenplayElement(element)
            
        case .deleteScreenplayElement(let element, _):
            // Redo delete: delete the element again
            dialogViewModel?.redoDeleteScreenplayElement(element)
            
        case .editScreenplayElement(let id, _, let newContent, _, let newSpeaker):
            // Redo edit: apply the new content/speaker again
            dialogViewModel?.redoEditScreenplayElement(id: id, newContent: newContent, newSpeaker: newSpeaker)
        }
        
        objectWillChange.send()
    }
    
    func clearUndoStack() {
        undoAction = nil
        redoAction = nil
        objectWillChange.send()
    }
} 