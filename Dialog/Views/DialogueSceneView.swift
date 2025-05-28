import SwiftUI

// MARK: - Dialogue Scene View
struct DialogueSceneView: View {
    @StateObject private var viewModel = DialogViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showInputArea = false
    @State private var currentTitle = ""
    @State private var isFullscreenMode = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let onSave: ((DialogViewModel) -> Void)?
    let existingSession: DialogueSession?
    let toolbarTransition: Namespace.ID?
    
    init(existingSession: DialogueSession? = nil, toolbarTransition: Namespace.ID? = nil, onSave: ((DialogViewModel) -> Void)? = nil) {
        self.existingSession = existingSession
        self.toolbarTransition = toolbarTransition
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 0) {
            textlinesView
                .onTapGesture {
                    if viewModel.isEditingText {
                        cancelEditMode()
                    } else if isFullscreenMode {
                        // Exit fullscreen mode and show input area + navbar
                        exitFullscreenMode()
                    } else {
                        // Tap to show combo if hidden, or dismiss if shown
                        if !showInputArea {
                            showInputAreaWithFocus()
                        } else {
                            hideInputArea()
                        }
                    }
                }
            
            if showInputArea && !isFullscreenMode {
                inputAreaView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.3), value: showInputArea)
        .animation(.easeInOut(duration: 0.3), value: isFullscreenMode)
        .toolbarBackground(isFullscreenMode ? .hidden : .visible, for: .navigationBar)
        .toolbar(isFullscreenMode ? .hidden : .visible, for: .navigationBar)
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
        .navigationTitle(currentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .statusBarHidden(isFullscreenMode)
        .onAppear {
            // Load existing session data if provided
            if let session = existingSession {
                currentTitle = session.title
                viewModel.loadSession(session)
                
                // Enter fullscreen mode if there are existing texts
                if !session.textlines.isEmpty {
                    enterFullscreenMode()
                }
            } else {
                currentTitle = ""
                // Only show input area and focus for new dialogues
                showInputAreaWithFocus()
            }
        }
        .onDisappear {
            // Auto-save when navigating back, but only if there are texts
            if !viewModel.textlines.isEmpty {
                onSave?(viewModel)
            }
        }
    }
    
    // MARK: - Textlines View
    private var textlinesView: some View {
        ScrollViewReader { proxy in
            textlinesList
                .onChange(of: viewModel.textlines.count) { _, _ in
                    if !viewModel.isEditingText {
                        scrollToLastText(proxy: proxy)
                    }
                }
                .onChange(of: showInputArea) { _, newValue in
                    if newValue && !viewModel.textlines.isEmpty {
                        if viewModel.isEditingText {
                            scrollToEditingText(proxy: proxy)
                        } else {
                            // Delay scroll to allow input area animation to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                scrollToLastText(proxy: proxy)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.editingTextId) { _, editingId in
                    if editingId != nil {
                        scrollToEditingText(proxy: proxy)
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    if focused && !viewModel.textlines.isEmpty {
                        if viewModel.isEditingText {
                            // When keyboard appears during editing, ensure editing text is visible
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                scrollToEditingText(proxy: proxy)
                            }
                        } else {
                            // When keyboard appears for new text, ensure last text is visible
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                scrollToLastText(proxy: proxy)
                            }
                        }
                    }
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
        .contentMargins(.bottom, showInputArea ? 60 : 0)
        .contentMargins(.top, isFullscreenMode ? 0 : (viewModel.isEditingText ? 20 : 0))
    }
    
    private var textlinesForEach: some View {
        ForEach(viewModel.textlines) { speakerText in
            SpeakerTextRowView(
                speakerText: speakerText,
                speakerName: viewModel.getSpeakerName(for: speakerText.speaker),
                isFlagged: viewModel.isTextFlagged(speakerText.id),
                isBeingEdited: viewModel.editingTextId == speakerText.id
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
                    Image(systemName: "star.fill")
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
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
                .padding(.horizontal)
            
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
    private func showInputAreaWithFocus() {
        // Set the correct speaker based on the last text before showing input area
        if !viewModel.isEditingText {
            viewModel.setNextSpeakerBasedOnLastText()
        }
        showInputArea = true
        // Delay focus to ensure the input area is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }
    
    private func hideInputArea() {
        isInputFocused = false
        showInputArea = false
    }
    
    private func startEditingText(_ speakerText: SpeakerText) {
        viewModel.startEditingText(speakerText)
        if isFullscreenMode {
            exitFullscreenMode()
        } else {
            showInputAreaWithFocus()
        }
    }
    
    private func cancelEditMode() {
        viewModel.exitEditMode()
        viewModel.inputText = ""
        // Restore proper speaker turn based on last text
        viewModel.setNextSpeakerBasedOnLastText()
        hideInputArea()
    }
    
    private func scrollToLastText(proxy: ScrollViewProxy) {
        guard let lastText = viewModel.textlines.last else { return }
        
        withAnimation(.easeOut(duration: 0.5)) {
            // Use center anchor to keep the last text visible above the keyboard
            proxy.scrollTo(lastText.id, anchor: .center)
        }
    }
    
    private func exitFullscreenMode() {
        isFullscreenMode = false
        showInputAreaWithFocus()
    }
    
    private func enterFullscreenMode() {
        isFullscreenMode = true
        showInputArea = false
        isInputFocused = false
    }
    
    private func scrollToEditingText(proxy: ScrollViewProxy) {
        guard let editingId = viewModel.editingTextId else { return }
        
        withAnimation(.easeOut(duration: 0.5)) {
            // Use center anchor to keep the editing text visible above the keyboard
            proxy.scrollTo(editingId, anchor: .center)
        }
    }
}

// MARK: - Supporting Views
struct SpeakerTextRowView: View {
    let speakerText: SpeakerText
    let speakerName: String
    let isFlagged: Bool
    let isBeingEdited: Bool
    
    var isSpeakerA: Bool {
        speakerText.speaker == .a
    }
    
    var body: some View {
        HStack {
            if isSpeakerA {
                speakerAView
                Spacer()
            } else {
                Spacer()
                speakerBView
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
    
    private var speakerAView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(speakerName)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(speakerText.text)
                .font(.body)
        }
    }
    
    private var speakerBView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(speakerName)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(speakerText.text)
                .font(.body)
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
                    .opacity(isEditingMode ? 0.5 : 1.0)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                if !isEditingMode {
                                    selectedSpeaker = speaker
                                }
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                if !isEditingMode {
                                    speakerToRename = speaker
                                    newSpeakerName = viewModel.customSpeakerNames[speaker] ?? ""
                                    showingRenameAlert = true
                                }
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
        TextField(isEditing ? "Edit dialogue..." : "Enter dialogue...", text: $text, axis: .vertical)
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
    DialogueSceneView()
}

#Preview("Dark Mode") {
    DialogueSceneView()
        .preferredColorScheme(.dark)
} 
