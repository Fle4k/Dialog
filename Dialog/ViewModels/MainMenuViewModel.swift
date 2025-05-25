import SwiftUI

// MARK: - Sorting Options
enum DialogueSortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case dateEdited = "Date Edited"
    case alphabetical = "Alphabetical"
    
    var systemImage: String {
        switch self {
        case .dateAdded:
            return "calendar.badge.plus"
        case .dateEdited:
            return "calendar.badge.clock"
        case .alphabetical:
            return "textformat.abc"
        }
    }
}

// MARK: - Main Menu View Model
@MainActor
final class MainMenuViewModel: ObservableObject {
    @Published var dialogueSessions: [DialogueSession] = []
    @Published var sortOption: DialogueSortOption = .dateAdded
    
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "DialogueSessions"
    private let sortOptionKey = "DialogueSortOption"
    
    init() {
        loadSortOption()
        loadSessions()
    }
    
    // MARK: - Sorting
    func setSortOption(_ option: DialogueSortOption) {
        sortOption = option
        saveSortOption()
        applySorting()
    }
    
    private func applySorting() {
        switch sortOption {
        case .dateAdded:
            // Keep original order (chronological by creation)
            dialogueSessions = dialogueSessions.sorted { $0.createdAt < $1.createdAt }
        case .dateEdited:
            // Sort by last modified date, most recent first
            dialogueSessions = dialogueSessions.sorted { $0.lastModified > $1.lastModified }
        case .alphabetical:
            // Sort alphabetically by title (case-insensitive)
            dialogueSessions = dialogueSessions.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
    
    // MARK: - Session Management
    func saveSession(_ viewModel: DialogViewModel) {
        let session = DialogueSession(from: viewModel)
        dialogueSessions.append(session)
        applySorting()
        saveSessions()
    }
    
    func deleteSession(_ session: DialogueSession) {
        dialogueSessions.removeAll { $0.id == session.id }
        saveSessions()
    }
    
    func deleteSession(at offsets: IndexSet) {
        dialogueSessions.remove(atOffsets: offsets)
        saveSessions()
    }
    
    func updateSession(_ session: DialogueSession, with viewModel: DialogViewModel) {
        guard let index = dialogueSessions.firstIndex(where: { $0.id == session.id }) else { return }
        
        // Create updated session with new data
        var updatedSession = session
        updatedSession.textlines = viewModel.textlines
        updatedSession.customSpeakerNames = viewModel.customSpeakerNames
        updatedSession.flaggedMessageIds = viewModel.flaggedMessageIds
        updatedSession.title = DialogueSession.generateTitle(from: viewModel.textlines)
        
        // Only update lastModified if content actually changed
        if updatedSession.hasContentChanges(comparedTo: session) {
            updatedSession.lastModified = Date()
        }
        
        dialogueSessions[index] = updatedSession
        applySorting()
        saveSessions()
    }
    
    func renameSession(_ session: DialogueSession, to newTitle: String) {
        guard let index = dialogueSessions.firstIndex(where: { $0.id == session.id }) else { return }
        
        var updatedSession = session
        updatedSession.title = newTitle
        updatedSession.lastModified = Date()
        
        dialogueSessions[index] = updatedSession
        applySorting()
        saveSessions()
    }
    
    // MARK: - Persistence
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(dialogueSessions)
            userDefaults.set(data, forKey: sessionsKey)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey) else { return }
        
        do {
            dialogueSessions = try JSONDecoder().decode([DialogueSession].self, from: data)
            applySorting()
        } catch {
            print("Failed to load sessions: \(error)")
            dialogueSessions = []
        }
    }
    
    private func loadSortOption() {
        guard let savedOption = userDefaults.string(forKey: sortOptionKey) else { return }
        sortOption = DialogueSortOption(rawValue: savedOption) ?? .dateAdded
    }
    
    private func saveSortOption() {
        userDefaults.set(sortOption.rawValue, forKey: sortOptionKey)
    }
    
    // MARK: - Helper Methods
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 