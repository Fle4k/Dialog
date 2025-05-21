import SwiftUI
import UIKit

struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

struct DialogueSceneView: View {
    @StateObject private var viewModel: DialogueViewModel
    @State private var showingRenameDialog = false
    @State private var speakerToRename = ""
    @State private var newSpeakerName = ""
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
                let isNewScene = scene.dialogues.isEmpty
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = isNewScene
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .customBackButton()
            .blur(radius: editingDialogue != nil ? 3 : 0)
            .animation(.easeInOut(duration: 0.1), value: editingDialogue != nil)
            .onShake {
                viewModel.undoLastAction()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(scene.title)
                        .font(.headline)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        // Add keyboard button if it's not a new scene
                        if !viewModel.dialogues.isEmpty {
                            Button(action: {
                                isTextFieldFocused = true
                            }) {
                                Image(systemName: "keyboard")
                            }
                        }
                        
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
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        SpeakerButton(
                            name: viewModel.speakerAName,
                            isSelected: editedSpeaker == viewModel.speakerAName,
                            onTap: { editedSpeaker = viewModel.speakerAName },
                            onLongPress: { }
                        )
                        
                        SpeakerButton(
                            name: viewModel.speakerBName,
                            isSelected: editedSpeaker == viewModel.speakerBName,
                            onTap: { editedSpeaker = viewModel.speakerBName },
                            onLongPress: { }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    PersistentTextField(
                        text: $editedText,
                        onSubmit: {
                            if !editedText.isEmpty {
                                viewModel.updateDialogue(id: dialogue.id, newSpeaker: editedSpeaker, newText: editedText)
                                editingDialogue = nil
                            }
                        },
                        isFocused: .constant(true)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    HStack {
                        Button("Cancel") {
                            editingDialogue = nil
                        }
                        Spacer()
                        Button("Save") {
                            viewModel.updateDialogue(id: dialogue.id, newSpeaker: editedSpeaker, newText: editedText)
                            editingDialogue = nil
                        }
                        .disabled(editedText.isEmpty)
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
                .presentationDetents([.height(200)])
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
                isTextFieldFocused: $isTextFieldFocused
            )
        }
    }
    
    private var scrollArea: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.dialogues) { dialogue in
                    DialogueRow(
                        dialogue: dialogue,
                        speakerAName: viewModel.speakerAName,
                        speakerBName: viewModel.speakerBName
                    )
                    .id(dialogue.id)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteDialogue(id: dialogue.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            editingDialogue = dialogue
                            editedText = dialogue.text
                            editedSpeaker = dialogue.speaker
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .onLongPressGesture {
                        editingDialogue = dialogue
                        editedText = dialogue.text
                        editedSpeaker = dialogue.speaker
                    }
                }
            }
            .listStyle(.plain)
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
