import SwiftUI

// MARK: - Models
struct Message: Identifiable, Hashable {
    let id = UUID()
    let speaker: Speaker
    let text: String
    
    var isSpeakerA: Bool {
        speaker == .a
    }
}

enum Speaker: String, CaseIterable {
    case a = "A"
    case b = "B"
    
    func displayName(customNames: [Speaker: String]) -> String {
        if let customName = customNames[self], !customName.isEmpty {
            return customName
        }
        return rawValue
    }
    
    mutating func toggle() {
        self = self == .a ? .b : .a
    }
}

// MARK: - View Model
@MainActor
final class DialogViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var selectedSpeaker: Speaker = .a
    @Published var inputText: String = ""
    @Published var customSpeakerNames: [Speaker: String] = [:]
    @Published var flaggedMessageIds: Set<UUID> = []
    
    func addMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let message = Message(speaker: selectedSpeaker, text: trimmedText)
        messages.append(message)
        selectedSpeaker.toggle()
        inputText = ""
    }
    
    func handleNewlineInput() {
        if inputText.contains("\n") {
            inputText = inputText.replacingOccurrences(of: "\n", with: "")
            addMessage()
        }
    }
    
    func renameSpeaker(_ speaker: Speaker, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        customSpeakerNames[speaker] = trimmedName.isEmpty ? nil : trimmedName
    }
    
    func deleteMessage(withId id: UUID) {
        messages.removeAll { $0.id == id }
        flaggedMessageIds.remove(id)
    }
    
    func deleteMessage(at offsets: IndexSet) {
        for offset in offsets {
            let message = messages[offset]
            flaggedMessageIds.remove(message.id)
        }
        messages.remove(atOffsets: offsets)
    }
    
    func toggleFlag(for messageId: UUID) {
        if flaggedMessageIds.contains(messageId) {
            flaggedMessageIds.remove(messageId)
        } else {
            flaggedMessageIds.insert(messageId)
        }
    }
    
    func isMessageFlagged(_ messageId: UUID) -> Bool {
        flaggedMessageIds.contains(messageId)
    }
    
    // MARK: - Export Methods
    func exportToText() -> String {
        var result = ""
        for message in messages {
            let speakerName = message.speaker.displayName(customNames: customSpeakerNames)
            result += "\(speakerName): \(message.text)\n\n"
        }
        return result
    }
    
    func exportToRTF() -> Data {
        let text = exportToText()
        let rtfString = "{\\rtf1\\ansi\\deff0 {\\fonttbl \\f0 Times New Roman;} \\f0\\fs24 \(text.replacingOccurrences(of: "\n", with: "\\par "))}"
        return rtfString.data(using: .utf8) ?? Data()
    }
    
    func exportToFDX() -> Data {
        let fdxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="1">
        <Content>
        \(messages.map { message in
            let speakerName = message.speaker.displayName(customNames: customSpeakerNames)
            return """
            <Paragraph Type="Character">
            <Text>\(speakerName)</Text>
            </Paragraph>
            <Paragraph Type="Dialogue">
            <Text>\(message.text)</Text>
            </Paragraph>
            """
        }.joined(separator: "\n"))
        </Content>
        </FinalDraft>
        """
        return fdxContent.data(using: .utf8) ?? Data()
    }
}

// MARK: - Main View
struct ContentView3: View {
    @StateObject private var viewModel = DialogViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showInputArea = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesView
                
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
            .onAppear {
                // Show input area and focus when view appears (like starting a new conversation)
                showInputAreaWithFocus()
            }
        }
    }
    
    // MARK: - Messages View
    private var messagesView: some View {
        ScrollViewReader { proxy in
            messagesList
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: showInputArea) { _, newValue in
                    if newValue && !viewModel.messages.isEmpty {
                        scrollToBottom(proxy: proxy)
                    }
                }
        }
    }
    
    private var messagesList: some View {
        List {
            if !viewModel.messages.isEmpty {
                messagesForEach
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, showInputArea ? 20 : 0)
        .onTapGesture {
            // Tap to show combo if hidden, or dismiss if shown
            if !showInputArea {
                showInputAreaWithFocus()
            } else {
                hideInputArea()
            }
        }
    }
    
    private var messagesForEach: some View {
        ForEach(viewModel.messages) { message in
            MessageRowView(message: message, viewModel: viewModel)
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
                isInputFocused: $isInputFocused
            )
            .padding(.horizontal)
            .padding(.top, 20)
            
            MessageInputView(
                text: $viewModel.inputText,
                isInputFocused: $isInputFocused,
                onSubmit: viewModel.addMessage
            )
            .padding(.horizontal)
            .padding(.top, 12)
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
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        
        withAnimation(.easeOut(duration: 0.5)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - Supporting Views
struct MessageRowView: View {
    let message: Message
    @ObservedObject var viewModel: DialogViewModel
    
    var body: some View {
        HStack {
            if message.isSpeakerA {
                speakerAView
                Spacer()
            } else {
                Spacer()
                speakerBView
            }
        }
        .padding()
        .background(viewModel.isMessageFlagged(message.id) ? Color.primary : Color.clear)
        .foregroundColor(viewModel.isMessageFlagged(message.id) ? Color(.systemBackground) : .primary)
        .cornerRadius(8)
    }
    
    private var speakerAView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.speaker.displayName(customNames: viewModel.customSpeakerNames))
                .font(.headline)
                .fontWeight(.bold)
            
            Text(message.text)
                .font(.body)
        }
    }
    
    private var speakerBView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.speaker.displayName(customNames: viewModel.customSpeakerNames))
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
    @State private var showingRenameAlert = false
    @State private var speakerToRename: Speaker? = nil
    @State private var newSpeakerName = ""
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Speaker.allCases, id: \.self) { speaker in
                Text(speaker.displayName(customNames: viewModel.customSpeakerNames))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(selectedSpeaker == speaker ? Color(.systemBackground) : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedSpeaker == speaker ? Color.primary : Color(.systemGray5))
                    )
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                selectedSpeaker = speaker
                            }
                    )
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
        .tint(.primary)
    }
}

struct MessageInputView: View {
    @Binding var text: String
    @FocusState.Binding var isInputFocused: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        TextField("", text: $text, axis: .vertical)
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
    ContentView3()
}

#Preview("Dark Mode") {
    ContentView3()
        .preferredColorScheme(.dark)
}
