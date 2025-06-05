import SwiftUI
import UIKit

// MARK: - Scroll Coordinator
@MainActor
class ScrollCoordinator: ObservableObject {
    func scrollToLastText(proxy: ScrollViewProxy, textlines: [SpeakerText]) {
        guard let lastText = textlines.last else { return }
        
        withAnimation(.easeOut(duration: 0.5)) {
            proxy.scrollTo(lastText.id, anchor: .center)
        }
    }
    
    func scrollToEditingText(proxy: ScrollViewProxy, editingId: UUID?) {
        guard let editingId = editingId else { return }
        
        withAnimation(.easeOut(duration: 0.5)) {
            proxy.scrollTo(editingId, anchor: .center)
        }
    }
    
    func handleTextCountChange(proxy: ScrollViewProxy, viewModel: DialogViewModel) {
        if !viewModel.isEditingText {
            scrollToLastText(proxy: proxy, textlines: viewModel.textlines)
        }
    }
    
    func handleInputAreaChange(proxy: ScrollViewProxy, viewModel: DialogViewModel, showInputArea: Bool) {
        if showInputArea && !viewModel.textlines.isEmpty {
            if viewModel.isEditingText {
                scrollToEditingText(proxy: proxy, editingId: viewModel.editingTextId)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.scrollToLastText(proxy: proxy, textlines: viewModel.textlines)
                }
            }
        }
    }
    
    func handleEditingChange(proxy: ScrollViewProxy, editingId: UUID?) {
        if editingId != nil {
            scrollToEditingText(proxy: proxy, editingId: editingId)
        }
    }
    
    func handleFocusChange(proxy: ScrollViewProxy, viewModel: DialogViewModel, focused: Bool) {
        if focused && !viewModel.textlines.isEmpty {
            if viewModel.isEditingText {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.scrollToEditingText(proxy: proxy, editingId: viewModel.editingTextId)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.scrollToLastText(proxy: proxy, textlines: viewModel.textlines)
                }
            }
        }
    }
}

// MARK: - Dialog Scene View
struct DialogSceneView: View {
    @StateObject private var viewModel = DialogViewModel()
    @StateObject private var scrollCoordinator = ScrollCoordinator()
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var undoManager = AppUndoManager.shared
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Rename alert state
    @State private var showingTitleRenameAlert = false
    @State private var newTitle = ""
    
    // Undo state
    @State private var showingUndoToast = false
    
    let onSave: ((DialogViewModel) -> Void)?
    let existingSession: DialogSession?
    let toolbarTransition: Namespace.ID?
    
    init(existingSession: DialogSession? = nil, toolbarTransition: Namespace.ID? = nil, onSave: ((DialogViewModel) -> Void)? = nil) {
        self.existingSession = existingSession
        self.toolbarTransition = toolbarTransition
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 0) {
            textlinesView
            
            if viewModel.showInputArea && !viewModel.isFullscreenMode {
                inputAreaView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.3), value: viewModel.showInputArea)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isFullscreenMode)
        .toolbarBackground(viewModel.isFullscreenMode ? .hidden : .visible, for: .navigationBar)
        .toolbar(viewModel.isFullscreenMode ? .hidden : .visible, for: .navigationBar)
        .onShake {
            handleShakeGesture()
        }
        .undoToast(
            isPresented: $showingUndoToast,
            actionDescription: viewModel.getLastActionDescription(),
            onUndo: {
                viewModel.performUndo()
            }
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(
                        item: viewModel.exportToFDXURL(),
                        preview: SharePreview("Dialog.fdx", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Export to Final Draft", systemImage: "doc.text")
                    }
                    
                    ShareLink(
                        item: viewModel.exportToRTFURL(),
                        preview: SharePreview("Dialog.rtf", image: Image(systemName: "doc.richtext"))
                    ) {
                        Label("Export as RTF", systemImage: "doc.richtext")
                    }
                    
                    ShareLink(
                        item: viewModel.exportToTextURL(),
                        preview: SharePreview("Dialog.txt", image: Image(systemName: "doc.plaintext"))
                    ) {
                        Label("Export as Text", systemImage: "doc.plaintext")
                    }
                } label: {
                    Group {
                        if let toolbarTransition = toolbarTransition {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                                .matchedGeometryEffect(id: "toolbarIcon", in: toolbarTransition)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {}) {
                    Text(viewModel.currentTitle.isEmpty ? "New Dialog" : viewModel.currentTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .disabled(true)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            // Add haptic feedback for title selection
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            newTitle = viewModel.currentTitle.isEmpty ? "New Dialog" : viewModel.currentTitle
                            showingTitleRenameAlert = true
                        }
                )
            }
        }
        .alert("Rename Dialog", isPresented: $showingTitleRenameAlert) {
            TextField("Dialog name", text: $newTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                viewModel.updateTitle(newTitle)
            }
        } message: {
            Text("Enter a new name for this dialog")
        }
        .statusBarHidden(viewModel.isFullscreenMode)
        .onAppear {
            if let session = existingSession {
                viewModel.initializeForExistingSession(session)
            } else {
                viewModel.initializeForNewSession()
            }
        }
        .onDisappear {
            if !viewModel.textlines.isEmpty {
                onSave?(viewModel)
            }
        }
        .onChange(of: viewModel.shouldFocusInput) { _, shouldFocus in
            isInputFocused = shouldFocus
        }
    }
    
    // MARK: - Textlines View
    private var textlinesView: some View {
        ScrollViewReader { proxy in
            textlinesList
                .onChange(of: viewModel.textlines.count) { _, _ in
                    scrollCoordinator.handleTextCountChange(proxy: proxy, viewModel: viewModel)
                }
                .onChange(of: viewModel.showInputArea) { _, newValue in
                    scrollCoordinator.handleInputAreaChange(proxy: proxy, viewModel: viewModel, showInputArea: newValue)
                }
                .onChange(of: viewModel.editingTextId) { _, editingId in
                    scrollCoordinator.handleEditingChange(proxy: proxy, editingId: editingId)
                }
                .onChange(of: isInputFocused) { _, focused in
                    scrollCoordinator.handleFocusChange(proxy: proxy, viewModel: viewModel, focused: focused)
                }
        }
    }
    
    private var textlinesList: some View {
        List {
            if !viewModel.textlines.isEmpty {
                textlinesForEach
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, viewModel.showInputArea ? 60 : 0)
        .contentMargins(.top, viewModel.isFullscreenMode ? 0 : (viewModel.isEditingText ? 20 : 0))
        .onTapGesture {
            viewModel.handleViewTap()
        }
    }
    
    private var textlinesForEach: some View {
        ForEach(viewModel.textlines) { speakerText in
            SpeakerTextRowView(
                speakerText: speakerText,
                speakerName: viewModel.getSpeakerName(for: speakerText.speaker),
                isFlagged: viewModel.isTextFlagged(speakerText.id),
                isBeingEdited: viewModel.editingTextId == speakerText.id,
                centerLines: settingsManager.centerLinesEnabled
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteText(withId: speakerText.id)
                }
                .tint(.red)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    viewModel.toggleFlag(for: speakerText.id)
                } label: {
                    Image(systemName: "flag.fill")
                }
                .tint(.orange)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        startEditingText(speakerText)
                    }
            )
            .id(speakerText.id)
        }
    }
    
    // MARK: - Input Area View
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            Color(.label)
                .frame(height: 1)
            
            SpeakerSelectorView(
                selectedSpeaker: $viewModel.selectedSpeaker, 
                viewModel: viewModel,
                isInputFocused: $isInputFocused,
                isEditingMode: viewModel.isEditingText
            )
            .padding(.horizontal)
            .padding(.top, 12)
            
            HStack {
                            TextInputView(
                text: $viewModel.inputText,
                isInputFocused: $isInputFocused,
                onSubmit: viewModel.addText,
                isEditing: viewModel.isEditingText,
                selectedSpeaker: viewModel.selectedSpeaker
            )
                
                if viewModel.isEditingText {
                    Button("Cancel") {
                        cancelEditMode()
                    }
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .onChange(of: viewModel.inputText) { _, _ in
            viewModel.handleNewlineInput()
        }
    }
    
    // MARK: - Helper Methods
    private func startEditingText(_ speakerText: SpeakerText) {
        // Add haptic feedback for selection
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        viewModel.startEditingText(speakerText)
    }
    
    private func cancelEditMode() {
        viewModel.cancelEditMode()
    }
    
    private func handleShakeGesture() {
        guard viewModel.canUndo() else { return }
        
        // Show undo confirmation instead of immediately performing undo
        showingUndoToast = true
    }
}

// MARK: - Supporting Views
struct SpeakerTextRowView: View {
    let speakerText: SpeakerText
    let speakerName: String
    let isFlagged: Bool
    let isBeingEdited: Bool
    let centerLines: Bool
    
    var isSpeakerA: Bool {
        speakerText.speaker == .a
    }
    
    var body: some View {
        HStack {
            if centerLines {
                centeredView
            } else {
                if isSpeakerA {
                    speakerAView
                    Spacer()
                } else {
                    Spacer()
                    speakerBView
                }
            }
        }
        .padding()
        .background(isFlagged ? Color.primary : Color.clear)
        .foregroundColor(textColor)
        .cornerRadius(8)
        .blur(radius: isBeingEdited ? 2 : 0)
        .animation(.easeInOut(duration: 0.3), value: isBeingEdited)
    }
    
    private var textColor: Color {
        if isFlagged {
            return Color(.systemBackground)
        } else {
            return Color(.label) // Use .label instead of .primary for better contrast
        }
    }
    
    private var centeredView: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(speakerName)
                .font(.headline)
                .fontWeight(.black)
            
            Text(speakerText.text)
                .font(.body)
                .fontWeight(.light)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var speakerAView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(speakerName)
                .font(.headline)
                .fontWeight(.black)
            
            Text(speakerText.text)
                .font(.body)
                .fontWeight(.light)
        }
    }
    
    private var speakerBView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(speakerName)
                .font(.headline)
                .fontWeight(.black)
            
            Text(speakerText.text)
                .font(.body)
                .fontWeight(.light)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SpeakerSelectorView: View {
    @Binding var selectedSpeaker: Speaker
    let viewModel: DialogViewModel
    @FocusState.Binding var isInputFocused: Bool
    let isEditingMode: Bool
    @State private var showingRenameAlert = false
    @State private var speakerToRename: Speaker? = nil
    @State private var newSpeakerName = ""
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Speaker.allCases, id: \.self) { speaker in
                Text(speaker.displayName(customNames: viewModel.customSpeakerNames))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(selectedSpeaker == speaker ? .primary : Color(.systemGray4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .contentShape(Rectangle())
                    .opacity(isEditingMode ? (selectedSpeaker == speaker ? 1.0 : 0.7) : 1.0)
                    .onTapGesture {
                        if isEditingMode {
                            // In edit mode, temporarily change the selected speaker
                            viewModel.setTemporarySpeaker(speaker)
                        } else {
                            // In normal mode, just select the speaker for new text
                            selectedSpeaker = speaker
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                speakerToRename = speaker
                                newSpeakerName = viewModel.customSpeakerNames[speaker] ?? ""
                                showingRenameAlert = true
                            }
                    )
            }
        }
        .alert("Rename Speaker", isPresented: $showingRenameAlert) {
            TextField("Speaker name", text: $newSpeakerName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let speaker = speakerToRename {
                    viewModel.renameSpeaker(speaker, to: newSpeakerName)
                }
            }
        } message: {
            Text("Enter a custom name for this speaker")
        }
    }
}

struct TextInputView: View {
    @Binding var text: String
    @FocusState.Binding var isInputFocused: Bool
    let onSubmit: () -> Void
    let isEditing: Bool
    let selectedSpeaker: Speaker
    
    var body: some View {
                    TextField(isEditing ? "Edit dialog..." : "Enter dialog...", text: $text, axis: .vertical)
            .lineLimit(1...4)
            .focused($isInputFocused)
            .onSubmit {
                onSubmit()
            }
            .multilineTextAlignment(isEditing && selectedSpeaker == .b ? .trailing : .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
    }
}

// MARK: - Previews
#Preview("Light Mode") {
    DialogSceneView()
}

#Preview("Dark Mode") {
    DialogSceneView()
        .preferredColorScheme(.dark)
} 
