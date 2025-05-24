//
//  ContentView.swift
//  Dialog
//
//  Created by Shahin on 16.05.25.
//

import SwiftUI
import UIKit

struct PersistentTextField: UIViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    @Binding var isFocused: Bool
    
    init(text: Binding<String>, onSubmit: @escaping () -> Void, isFocused: Binding<Bool>? = nil) {
        self._text = text
        self.onSubmit = onSubmit
        self._isFocused = isFocused ?? .constant(false)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = true
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.returnKeyType = .done
        textView.text = text
        
        // Set initial height to single line
        let initialHeight = textView.font?.lineHeight ?? 20
        textView.frame.size.height = initialHeight + 16 // Add padding
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if text != uiView.text {
            uiView.text = text
        }
        
        // Handle focus changes
        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
        
        // Calculate and update height based on content
        let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: .greatestFiniteMagnitude))
        let minHeight = uiView.font?.lineHeight ?? 20
        let maxHeight = minHeight * 5 // Maximum 5 lines
        let newHeight = min(max(size.height, minHeight), maxHeight)
        
        if uiView.frame.height != newHeight {
            UIView.animate(withDuration: 0.25) {
                uiView.frame.size.height = newHeight
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: PersistentTextField
        
        init(_ parent: PersistentTextField) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused {
                parent.isFocused = true
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused {
                parent.isFocused = false
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText string: String) -> Bool {
            // Check if return key is pressed
            if string == "\n" {
                textView.resignFirstResponder() // Dismiss keyboard
                parent.onSubmit()
                return false // Don't add the newline
            }
            return true
        }
    }
}

struct SpeakerButton: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
    }
}

struct DialogueInputArea: View {
    @Binding var currentText: String
    let speakerAName: String
    let speakerBName: String
    let currentSpeaker: String
    let onSpeakerSwitch: (String) -> Void
    let onAdd: () -> Void
    let onRename: (String) -> Void
    @Binding var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SpeakerButton(
                    name: speakerAName,
                    isSelected: currentSpeaker == speakerAName,
                    onTap: { onSpeakerSwitch(speakerAName) },
                    onLongPress: { onRename(speakerAName) }
                )
                
                SpeakerButton(
                    name: speakerBName,
                    isSelected: currentSpeaker == speakerBName,
                    onTap: { onSpeakerSwitch(speakerBName) },
                    onLongPress: { onRename(speakerBName) }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            PersistentTextField(
                text: $currentText, 
                onSubmit: {
                    if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onAdd()
                    }
                },
                isFocused: $isTextFieldFocused
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                withAnimation(.easeOut(duration: 0.25)) {
                    // Update layout state here
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = DialogueViewModel(
        scene: DialogueScene(title: "Preview", dialogues: []),
        onSceneUpdate: { _ in }
    )
    @State private var showingShareSheet = false
    @State private var showingRenameDialog = false
    @State private var speakerToRename = ""
    @State private var newSpeakerName = ""
    @State private var editingDialogue: Dialogue? = nil
    @State private var editedText: String = ""
    @State private var editedSpeaker: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.dialogues) { dialogue in
                                DialogueRow(dialogue: dialogue, speakerAName: viewModel.speakerAName, speakerBName: viewModel.speakerBName)
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
                    isTextFieldFocused: .constant(false)
                )
            }
            .navigationTitle("Dialogue")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(
                            item: try! viewModel.exportToFDX(),
                            preview: SharePreview("Dialogue.fdx")
                        ) {
                            Label("Export to Final Draft", systemImage: "doc.text")
                        }
                        
                        ShareLink(
                            item: try! viewModel.exportToRTF(),
                            preview: SharePreview("Dialogue.rtf")
                        ) {
                            Label("Export as RTF", systemImage: "doc.richtext")
                        }
                        
                        ShareLink(
                            item: viewModel.exportToText(),
                            preview: SharePreview("Dialogue.txt")
                        ) {
                            Label("Export as Text", systemImage: "doc.plaintext")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [viewModel.exportToText()])
            }
            .alert("Rename Speaker".localized, isPresented: $showingRenameDialog) {
                TextField("New name".localized, text: $newSpeakerName)
                Button("Cancel".localized, role: .cancel) { }
                Button("Save".localized) {
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
    }
}

struct DialogueRow: View {
    let dialogue: Dialogue
    let speakerAName: String
    let speakerBName: String
    
    var body: some View {
        let isB = dialogue.speaker == speakerBName
        VStack(alignment: isB ? .trailing : .leading, spacing: 4) {
            Text(dialogue.speaker)
                .font(.headline)
                .foregroundColor(.accentColor)
            Text(dialogue.text)
                .font(.body)
                .multilineTextAlignment(isB ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: isB ? .trailing : .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
