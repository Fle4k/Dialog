import SwiftUI

// MARK: - Main Menu View
struct MainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sessions List
                sessionsListView
                
                // Add Button at Bottom
                addButtonView
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(DialogueSortOption.allCases, id: \.self) { option in
                            Button {
                                viewModel.setSortOption(option)
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    Image(systemName: option.systemImage)
                                    if viewModel.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Add Button View
    private var addButtonView: some View {
        NavigationLink {
            DialogueSceneView { dialogViewModel in
                viewModel.saveSession(dialogViewModel)
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add New Dialogue")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.primary)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Sessions List View
    private var sessionsListView: some View {
        Group {
            if viewModel.dialogueSessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Dialogues Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Tap 'Add New Dialogue' to start your first conversation")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var sessionsList: some View {
        List {
            ForEach(viewModel.dialogueSessions) { session in
                NavigationLink {
                    DialogueSceneView(existingSession: session) { dialogViewModel in
                        viewModel.updateSession(session, with: dialogViewModel)
                    }
                } label: {
                    SessionRowView(session: session)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        viewModel.deleteSession(session)
                    }
                }
            }
            .onDelete(perform: viewModel.deleteSession)
        }
        .listStyle(.plain)
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: DialogueSession
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(Self.dateFormatter.string(from: session.lastModified))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(session.messageCount) lines")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Previews
#Preview("Main Menu - Empty") {
    MainMenuView()
}

#Preview("Main Menu - With Sessions") {
    MainMenuView()
} 