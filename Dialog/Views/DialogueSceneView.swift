import SwiftUI

struct DialogueSceneView: View {
    @StateObject private var viewModel: DialogueViewModel
    @State private var showingRenameDialog = false
    @State private var speakerToRename = ""
    @State private var newSpeakerName = ""
    @State private var dynamicHeight: CGFloat = 36
    @State private var editingDialogue: Dialogue? = nil
    @State private var editedText: String = ""
    @State private var editedSpeaker: String = ""
    @State private var isTextFieldFocused = false
    
    let scene: DialogueScene
    let onSceneUpdate: (DialogueScene) -> Void
    
    init(scene: DialogueScene, onSceneUpdate: @escaping (DialogueScene) -> Void) {
        self.scene = scene
        self.onSceneUpdate = onSceneUpdate
        _viewModel = StateObject(wrappedValue: DialogueViewModel(scene: scene, onSceneUpdate: onSceneUpdate))
    }
    
    var body: some View {
        content
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }
            .navigationTitle(scene.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(
                            item: try! viewModel.exportToFDX(),
                            preview: SharePreview("\(scene.title).fdx")
                        ) {
                            Label("Export to Final Draft", systemImage: "doc.text")
                        }
                        
                        ShareLink(
                            item: try! viewModel.exportToRTF(),
                            preview: SharePreview("\(scene.title).rtf")
                        ) {
                            Label("Export as RTF", systemImage: "doc.richtext")
                        }
                        
                        ShareLink(
                            item: try! viewModel.exportToTextFile(),
                            preview: SharePreview("\(scene.title).txt")
                        ) {
                            Label("Export as Text", systemImage: "doc.plaintext")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .alert("Rename Speaker", isPresented: $showingRenameDialog) {
                TextField("New name", text: $newSpeakerName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if !newSpeakerName.isEmpty {
                        if speakerToRename == viewModel.speakerAName {
                            viewModel.renameSpeakerA(to: newSpeakerName)
                        } else {
                            viewModel.renameSpeakerB(to: newSpeakerName)
                        }
                    }
                }
            }
            .sheet(item: $editingDialogue) { dialogue in
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Button(viewModel.speakerAName) {
                            editedSpeaker = viewModel.speakerAName
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(editedSpeaker == viewModel.speakerAName ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(editedSpeaker == viewModel.speakerAName ? .white : .primary)
                        .cornerRadius(8)
                        Button(viewModel.speakerBName) {
                            editedSpeaker = viewModel.speakerBName
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(editedSpeaker == viewModel.speakerBName ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(editedSpeaker == viewModel.speakerBName ? .white : .primary)
                        .cornerRadius(8)
                    }
                    TextField("Speaker", text: $editedSpeaker)
                        .textFieldStyle(.roundedBorder)
                    TextField("Text", text: $editedText)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel") {
                            editingDialogue = nil
                        }
                        Spacer()
                        Button("Save") {
                            viewModel.updateDialogue(id: dialogue.id, newSpeaker: editedSpeaker, newText: editedText)
                            editingDialogue = nil
                        }
                    }
                }
                .padding()
                .presentationDetents([.medium])
            }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            scrollArea
            DialogueInputArea(
                currentText: $viewModel.currentText,
                speakerAName: viewModel.speakerAName,
                speakerBName: viewModel.speakerBName,
                currentSpeaker: viewModel.currentSpeaker,
                onSpeakerSwitch: { viewModel.switchSpeaker(to: $0) },
                onAdd: { viewModel.addDialogue() },
                onRename: { speaker in
                    speakerToRename = speaker
                    newSpeakerName = speaker
                    showingRenameDialog = true
                },
                isTextFieldFocused: $isTextFieldFocused,
                dynamicHeight: $dynamicHeight
            )
        }
    }
    
    private var scrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.dialogues) { dialogue in
                        DialogueRow(
                            dialogue: dialogue,
                            speakerAName: viewModel.speakerAName,
                            speakerBName: viewModel.speakerBName
                        )
                        .id(dialogue.id)
                        .onLongPressGesture {
                            editingDialogue = dialogue
                            editedText = dialogue.text
                            editedSpeaker = dialogue.speaker
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: viewModel.dialogues) { oldValue, newValue in
                if let lastDialogue = newValue.last {
                    withAnimation {
                        proxy.scrollTo(lastDialogue.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DialogueSceneView(
            scene: DialogueScene(title: "Sample Scene"),
            onSceneUpdate: { _ in }
        )
    }
} 