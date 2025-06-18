import SwiftUI

// MARK: - Sorting Options
enum DialogSortOption: String, CaseIterable {
    case alphabetical = "alphabetical"
    case dateEdited = "dateEdited"
    case dateAdded = "dateAdded"
    
    var displayName: String {
        switch self {
        case .alphabetical:
            return "Sort Alphabetically".localized
        case .dateEdited:
            return "Sort by Date Edited".localized
        case .dateAdded:
            return "Sort by Date Added".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .alphabetical:
            return "textformat.abc"
        case .dateEdited:
            return "calendar.badge.clock"
        case .dateAdded:
            return "calendar.badge.plus"
        }
    }
}

// MARK: - Main Menu View Model
@MainActor
final class MainMenuViewModel: ObservableObject {
    @Published var dialogSessions: [DialogSession] = []
    @Published var sortOption: DialogSortOption = .alphabetical
    
    // MARK: - Undo Manager
    private let undoManager = AppUndoManager.shared
    
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "DialogSessions"
    private let sortOptionKey = "DialogSortOption"
    private let dataVersionKey = "DataFormatVersion"
    private let currentDataVersion = 1
    
    init() {
        loadSortOption()
        loadSessions()
        setDataVersion()
    }
    
    // MARK: - Sorting
    func setSortOption(_ option: DialogSortOption) {
        sortOption = option
        saveSortOption()
        applySorting()
    }
    
    private func applySorting() {
        switch sortOption {
        case .dateAdded:
            // Sort by creation date, most recent first
            dialogSessions = dialogSessions.sorted { $0.createdAt > $1.createdAt }
        case .dateEdited:
            // Sort by last modified date, most recent first
            dialogSessions = dialogSessions.sorted { $0.lastModified > $1.lastModified }
        case .alphabetical:
            // Sort alphabetically by title (case-insensitive)
            dialogSessions = dialogSessions.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
    
    // MARK: - Session Management
    func saveSession(_ viewModel: DialogViewModel) {
        let session = DialogSession(from: viewModel)
        dialogSessions.append(session)
        applySorting()
        saveSessions()
    }
    
    func deleteSession(_ session: DialogSession) {
        guard let index = dialogSessions.firstIndex(where: { $0.id == session.id }) else { return }
        
        // Record undo action
        undoManager.recordAction(.deleteSession(session, index))
        
        dialogSessions.removeAll { $0.id == session.id }
        saveSessions()
    }
    
    func deleteSession(at offsets: IndexSet) {
        for offset in offsets {
            let session = dialogSessions[offset]
            
            // Record undo action
            undoManager.recordAction(.deleteSession(session, offset))
        }
        
        dialogSessions.remove(atOffsets: offsets)
        saveSessions()
    }
    
    func updateSession(_ session: DialogSession, with viewModel: DialogViewModel) {
        guard let index = dialogSessions.firstIndex(where: { $0.id == session.id }) else { return }
        
        // Create updated session with new data
        var updatedSession = session
        updatedSession.textlines = viewModel.textlines
        updatedSession.customSpeakerNames = viewModel.customSpeakerNames
        updatedSession.flaggedTextIds = viewModel.flaggedTextIds
        
        // Use the viewModel's currentTitle if it's set, otherwise generate one
        if !viewModel.currentTitle.isEmpty {
            updatedSession.title = viewModel.currentTitle
        } else {
            updatedSession.title = DialogSession.generateTitle(from: viewModel.textlines)
        }
        
        // Only update lastModified if content actually changed
        if updatedSession.hasContentChanges(comparedTo: session) {
            updatedSession.lastModified = Date()
        }
        
        dialogSessions[index] = updatedSession
        applySorting()
        saveSessions()
    }
    
    func renameSession(_ session: DialogSession, to newTitle: String) {
        guard let index = dialogSessions.firstIndex(where: { $0.id == session.id }) else { return }
        
        let oldTitle = session.title
        
        // Record undo action
        undoManager.recordAction(.renameSession(session.id, oldTitle, newTitle))
        
        var updatedSession = session
        updatedSession.title = newTitle
        updatedSession.lastModified = Date()
        
        dialogSessions[index] = updatedSession
        applySorting()
        saveSessions()
    }
    
    // MARK: - Persistence
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(dialogSessions)
            userDefaults.set(data, forKey: sessionsKey)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey) else { return }
        
        do {
            dialogSessions = try JSONDecoder().decode([DialogSession].self, from: data)
            applySorting()
        } catch {
            print("Failed to load sessions: \(error)")
            #if DEBUG
            print("Raw data that failed to decode: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
            #endif
            dialogSessions = []
        }
    }
    
    private func loadSortOption() {
        guard let savedOption = userDefaults.string(forKey: sortOptionKey) else { return }
        sortOption = DialogSortOption(rawValue: savedOption) ?? .alphabetical
    }
    
    private func saveSortOption() {
        userDefaults.set(sortOption.rawValue, forKey: sortOptionKey)
    }
    
    private func setDataVersion() {
        userDefaults.set(currentDataVersion, forKey: dataVersionKey)
    }
    
    // MARK: - Helper Methods
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Undo Methods
    func undoDeleteSession(_ session: DialogSession, at originalIndex: Int) {
        // Insert at the original position if it's valid, otherwise append
        if originalIndex >= 0 && originalIndex <= dialogSessions.count {
            dialogSessions.insert(session, at: originalIndex)
        } else {
            dialogSessions.append(session)
        }
        applySorting()
        saveSessions()
    }
    
    func undoRenameSession(sessionId: UUID, oldTitle: String) {
        guard let index = dialogSessions.firstIndex(where: { $0.id == sessionId }) else { return }
        
        var session = dialogSessions[index]
        session.title = oldTitle
        session.lastModified = Date()
        
        dialogSessions[index] = session
        applySorting()
        saveSessions()
    }
    
    func canUndo() -> Bool {
        return undoManager.canUndo
    }
    
    func getLastActionDescription() -> String {
        return undoManager.lastActionDescription
    }
    
    func performUndo() {
        undoManager.performUndo(mainMenuViewModel: self)
    }
    
    func canRedo() -> Bool {
        return undoManager.canRedo
    }
    
    func performRedo() {
        undoManager.performRedo(mainMenuViewModel: self)
    }
    
    // MARK: - Redo Methods
    func redoDeleteSession(_ session: DialogSession) {
        dialogSessions.removeAll { $0.id == session.id }
        saveSessions()
    }
    
    func redoRenameSession(sessionId: UUID, newTitle: String) {
        guard let index = dialogSessions.firstIndex(where: { $0.id == sessionId }) else { return }
        
        var session = dialogSessions[index]
        session.title = newTitle
        session.lastModified = Date()
        
        dialogSessions[index] = session
        applySorting()
        saveSessions()
    }
} 