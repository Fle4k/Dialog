import SwiftUI

// MARK: - Dialogue Scene View
struct DialogueSceneView: View {
    @StateObject private var viewModel = DialogViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showInputArea = false
    @Environment(\.dismiss) private var dismiss
    
    let onSave: ((DialogViewModel) -> Void)?
    let existingSession: DialogueSession?
    
    init(existingSession: DialogueSession? = nil, onSave: ((DialogViewModel) -> Void)? = nil) {
        self.existingSession = existingSession
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 0) {
            textlinesView
                .blur(radius: viewModel.isEditingMessage ? 8 : 0)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isEditingMessage)
                .onTapGesture {
                    if viewModel.isEditingMessage {
                        cancelEditMode()
                    } else {
                        // Tap to show combo if hidden, or dismiss if shown
                        if !showInputArea {
                            showInputAreaWithFocus()
                        } else {
                            hideInputArea()
                        }
                    }
                }
            
            if showInputArea {
                inputAreaView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.3), value: showInputArea)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(
                        item: viewModel.exportToFDX(),
                        preview: SharePreview("Dialog.fdx")
                    ) {
                        Label("Export to Final Draft", systemImage: "doc.text")
                    }
                    
                    ShareLink(
                        item: viewModel.exportToRTF(),
                        preview: SharePreview("Dialog.rtf")
                    ) {
                        Label("Export as RTF", systemImage: "doc.richtext")
                    }
                    
                    ShareLink(
                        item: viewModel.exportToText(),
                        preview: SharePreview("Dialog.txt")
                    ) {
                        Label("Export as Text", systemImage: "doc.plaintext")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle(existingSession?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load existing session data if provided
            if let session = existingSession {
                viewModel.loadSession(session)
            }
            
            // Show input area and focus when view appears (like starting a new conversation)
            showInputAreaWithFocus()
        }
        .onDisappear {
            // Auto-save when navigating back
            onSave?(viewModel)
        }
    }
    
    // MARK: - Textlines View
    private var textlinesView: some View {
        ScrollViewReader { proxy in
            textlinesList
                .onChange(of: viewModel.textlines.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: showInputArea) { _, newValue in
                    if newValue && !viewModel.textlines.isEmpty {
                        scrollToBottom(proxy: proxy)
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
        .contentMargins(.bottom, showInputArea ? 20 : 0)
    }
    

    
    private var textlinesForEach: some View {
        ForEach(viewModel.textlines) { message in
            MessageRowView(
                message: message,
                speakerName: viewModel.getSpeakerName(for: message.speaker),
                isFlagged: viewModel.isMessageFlagged(message.id)
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteMessage(withId: message.id)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    viewModel.toggleFlag(for: message.id)
                } label: {
                    Image(systemName: "star.fill")
                        .foregroundColor(.white)
                }
                .tint(.primary)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        startEditingMessage(message)
                    }
            )
            .id(message.id)
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
                isEditingMode: viewModel.isEditingMessage
            )
            .padding(.horizontal)
            .padding(.top, 12)
            
            HStack {
                MessageInputView(
                    text: $viewModel.inputText,
                    isInputFocused: $isInputFocused,
                    onSubmit: viewModel.addMessage,
                    isEditing: viewModel.isEditingMessage
                )
                
                if viewModel.isEditingMessage {
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
    
    private func startEditingMessage(_ message: Message) {
        viewModel.startEditingMessage(message)
        showInputAreaWithFocus()
    }
    
    private func cancelEditMode() {
        viewModel.exitEditMode()
        viewModel.inputText = ""
        hideInputArea()
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.textlines.last else { return }
        
        withAnimation(.easeOut(duration: 0.5)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - Supporting Views
struct MessageRowView: View {
    let message: Message
    let speakerName: String
    let isFlagged: Bool
    
    var isSpeakerA: Bool {
        message.speaker == .a
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
        .foregroundColor(isFlagged ? Color(.systemBackground) : .primary)
        .cornerRadius(8)
    }
    
    private var speakerAView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(speakerName)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(message.text)
                .font(.body)
        }
    }
    
    private var speakerBView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(speakerName)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(message.text)
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
        .tint(.primary)
    }
}

struct MessageInputView: View {
    @Binding var text: String
    @FocusState.Binding var isInputFocused: Bool
    let onSubmit: () -> Void
    let isEditing: Bool
    
    var body: some View {
        TextField(isEditing ? "Edit message..." : "Enter dialogue...", text: $text, axis: .vertical)
            .lineLimit(1...4)
            .focused($isInputFocused)
            .onSubmit {
                onSubmit()
            }
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
