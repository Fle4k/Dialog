import SwiftUI

// MARK: - Main Menu View
struct MainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()
    @StateObject private var undoManager = AppUndoManager.shared
    @State private var showingSettings = false
    
    // Undo state
    @State private var showingUndoToast = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sessions List
                sessionsListView
                
                // Add Button at Bottom
                addButtonView
            }
            .onShake {
                handleShakeGesture()
            }
            .undoToast(
                isPresented: $showingUndoToast,
                actionDescription: viewModel.getLastActionDescription(),
                onUndo: {
                    if viewModel.canRedo() {
                        viewModel.performRedo()
                    } else {
                        viewModel.performUndo()
                    }
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Sort Options Section
                        ForEach(DialogSortOption.allCases, id: \.self) { option in
                            Button {
                                viewModel.setSortOption(option)
                            } label: {
                                HStack {
                                    Text(option.displayName)
                                    Image(systemName: option.systemImage)
                                    if viewModel.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .disabled(viewModel.sortOption == option)
                        }
                        
                        // Divider
                        Divider()
                        
                        // Settings Option
                        Button {
                            showingSettings = true
                        } label: {
                            HStack {
                                Text("Settings".localized)
                                Image(systemName: "gear")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .tint(.primary)
    }
    
    // MARK: - Add Button View
    private var addButtonView: some View {
        NavigationLink {
            DialogSceneView { dialogViewModel in
                viewModel.saveSession(dialogViewModel)
            }
        } label: {
            Text("NEW DIALOG")
                .font(.system(size: 20))
                .fontWeight(.black)
                .foregroundColor(.primary)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Sessions List View
    private var sessionsListView: some View {
        Group {
            if viewModel.dialogSessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Talk balloon icon
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No one said a word.".localized)
                .font(.title2)
                .fontWeight(.regular)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var sessionsList: some View {
        List {
            ForEach(viewModel.dialogSessions) { session in
                NavigationLink {
                    DialogSceneView(existingSession: session) { dialogViewModel in
                        viewModel.updateSession(session, with: dialogViewModel)
                    }
                } label: {
                    SessionRowView(session: session) { newTitle in
                        viewModel.renameSession(session, to: newTitle)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete".localized, role: .destructive) {
                        viewModel.deleteSession(session)
                    }
                    .tint(.red)
                }
            }
            .onDelete(perform: viewModel.deleteSession)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Helper Methods
    private func handleShakeGesture() {
        guard viewModel.canUndo() || viewModel.canRedo() else { return }
        
        // Show undo/redo confirmation
        showingUndoToast = true
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
            let session: DialogSession
    let onRename: (String) -> Void
    @State private var showingRenameAlert = false
    @State private var newTitle = ""
    
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
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(Self.dateFormatter.string(from: session.lastModified))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(session.lineCount) \("Lines".localized)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    newTitle = session.title
                    showingRenameAlert = true
                }
        )
        .alert("Rename Dialog".localized, isPresented: $showingRenameAlert) {
            TextField("Dialog name".localized, text: $newTitle)
            Button("Cancel".localized, role: .cancel) { }
            Button("Save".localized) {
                let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTitle.isEmpty {
                    onRename(trimmedTitle)
                }
            }
        } message: {
            Text("Enter a new name for this dialog".localized)
        }
    }
}

// MARK: - Previews
#Preview("Main Menu - Empty") {
    MainMenuView()
}

#Preview("Main Menu - With Sessions") {
    MainMenuView()
} 
