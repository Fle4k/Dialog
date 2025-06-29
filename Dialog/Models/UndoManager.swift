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
    case changeElementType(id: UUID, oldType: ScreenplayElementType, newType: ScreenplayElementType) // Add proper element type change tracking
    case removeSpeaker(speaker: Speaker, oldActiveSpeakers: [Speaker], oldMaxSpeakerInUse: Speaker, oldCustomName: String?, removedElements: [(Int, ScreenplayElement)], removedTextlines: [(Int, SpeakerText)])
}

// MARK: - Undo Manager
@MainActor
class AppUndoManager: ObservableObject {
    static let shared = AppUndoManager()
    
    // Changed to store stacks of actions instead of just one
    @Published private var undoStack: [UndoAction] = []
    @Published private var redoStack: [UndoAction] = []
    
    // Maximum number of undo actions to keep in memory
    private let maxUndoStackSize = 50
    
    private init() {}
    
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    var lastActionDescription: String {
        if canRedo {
            return "Redo".localized
        } else if let action = undoStack.last {
            switch action {
            case .addText(_):
                return "Add Text".localized
            case .deleteText(_, _):
                return "Delete Text".localized
            case .editText(_, _, _, _, _):
                return "Edit Text".localized
            case .toggleFlag(_, let wasAdd):
                return wasAdd ? "Flag Text".localized : "Unflag Text".localized
                    case .renameSpeaker(_, _, _):
            return "Rename Character".localized
            case .deleteSession(_, _):
                return "Delete Dialog".localized
            case .renameSession(_, _, _):
                return "Rename Dialog".localized
            case .addScreenplayElement(_):
                return "Add Element".localized
            case .deleteScreenplayElement(_, _):
                return "Delete Element".localized
            case .editScreenplayElement(_, _, _, _, _):
                return "Edit Element".localized
            case .changeElementType(_, _, _):
                return "Change Type".localized
                    case .removeSpeaker(_, _, _, _, _, _):
            return "Remove Character".localized
            }
        } else {
            return ""
        }
    }
    
    func recordAction(_ action: UndoAction) {
        // Add action to undo stack
        undoStack.append(action)
        
        // Limit stack size to prevent memory issues
        if undoStack.count > maxUndoStackSize {
            undoStack.removeFirst()
        }
        
        // Clear redo stack when a new action is recorded
        redoStack.removeAll()
        
        objectWillChange.send()
        print("🔄 UndoManager: Recorded action, undo stack size: \(undoStack.count)")
    }
    
    func performUndo(dialogViewModel: DialogViewModel? = nil, mainMenuViewModel: MainMenuViewModel? = nil) {
        guard let action = undoStack.last else { return }
        
        // Move undo action to redo
        redoStack.append(action)
        undoStack.removeLast()
        
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
            
        case .changeElementType(let id, let oldType, let newType):
            dialogViewModel?.undoChangeElementType(id: id, oldType: oldType, newType: newType)
            
        case .removeSpeaker(let speaker, let oldActiveSpeakers, let oldMaxSpeakerInUse, let oldCustomName, let removedElements, let removedTextlines):
            dialogViewModel?.undoRemoveSpeaker(speaker: speaker, oldActiveSpeakers: oldActiveSpeakers, oldMaxSpeakerInUse: oldMaxSpeakerInUse, oldCustomName: oldCustomName, removedElements: removedElements, removedTextlines: removedTextlines)
        }
        
        objectWillChange.send()
    }
    
    func performRedo(dialogViewModel: DialogViewModel? = nil, mainMenuViewModel: MainMenuViewModel? = nil) {
        guard let action = redoStack.last else { return }
        
        // Move redo action back to undo
        undoStack.append(action)
        redoStack.removeLast()
        
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
            
        case .changeElementType(let id, let oldType, let newType):
            dialogViewModel?.redoChangeElementType(id: id, oldType: oldType, newType: newType)
            
        case .removeSpeaker(let speaker, _, _, _, _, _):
            dialogViewModel?.removeSpeaker(speaker)
        }
        
        objectWillChange.send()
    }
    
    func clearUndoStack() {
        undoStack.removeAll()
        redoStack.removeAll()
        objectWillChange.send()
    }
} 