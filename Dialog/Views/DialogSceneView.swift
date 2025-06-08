import SwiftUI
import UIKit

// Extension to help find the current text field for cursor positioning
extension UIResponder {
    static var currentFirstResponder: UIResponder? {
        var first: UIResponder?
        
        func findFirstResponder(in view: UIView) {
            for subview in view.subviews {
                if subview.isFirstResponder {
                    first = subview
                    return
                }
                findFirstResponder(in: subview)
            }
        }
        
        for window in UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows }) {
            findFirstResponder(in: window)
            if first != nil {
                break
            }
        }
        
        return first
    }
}

// MARK: - Grouped Element Model
struct GroupedElement: Identifiable {
    let id: UUID
    let speaker: Speaker?
    let elements: [ScreenplayElement]
}

// MARK: - Grouped Element Row View
struct GroupedElementRowView: View {
    let groupedElement: GroupedElement
    let customSpeakerNames: [Speaker: String]
    let centerLines: Bool
    
    var body: some View {
        if centerLines || groupedElement.speaker == nil {
            // Center aligned for actions or when center mode is enabled
            centeredView
        } else {
            // Speaker aligned view
            if groupedElement.speaker == .a {
                speakerAGroupView
            } else {
                speakerBGroupView
            }
        }
    }
    
    private var speakerAGroupView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Speaker name
                Text(groupedElement.speaker?.displayName(customNames: customSpeakerNames) ?? "")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // All elements for this speaker
                ForEach(groupedElement.elements) { element in
                    if element.type == .parenthetical {
                        Text("(\(element.content))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text(element.content)
                            .font(.body)
                    }
                }
            }
            Spacer()
        }
    }
    
    private var speakerBGroupView: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                // Speaker name
                Text(groupedElement.speaker?.displayName(customNames: customSpeakerNames) ?? "")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // All elements for this speaker
                ForEach(groupedElement.elements) { element in
                    if element.type == .parenthetical {
                        Text("(\(element.content))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(element.content)
                            .font(.body)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }
    
    private var centeredView: some View {
        VStack(spacing: 6) {
            ForEach(groupedElement.elements) { element in
                Text(element.content)
                    .font(.body)
                    .italic(element.type == .action)
                    .multilineTextAlignment(element.type == .action ? .leading : .center)
                    .frame(maxWidth: .infinity, alignment: element.type == .action ? .leading : .center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Scroll Coordinator
@MainActor
class ScrollCoordinator: ObservableObject {
    func scrollToLastElement(proxy: ScrollViewProxy, elements: [ScreenplayElement]) {
        guard let lastElement = elements.last else { return }
        
        withAnimation(.easeOut(duration: 0.5)) {
            proxy.scrollTo(lastElement.id, anchor: .center)
        }
    }
    
    func handleElementCountChange(proxy: ScrollViewProxy, viewModel: DialogViewModel) {
        scrollToLastElement(proxy: proxy, elements: viewModel.screenplayElements)
    }
    
    func handleInputAreaChange(proxy: ScrollViewProxy, viewModel: DialogViewModel, showInputArea: Bool) {
        if showInputArea && !viewModel.screenplayElements.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.scrollToLastElement(proxy: proxy, elements: viewModel.screenplayElements)
            }
        }
    }
    
    func handleFocusChange(proxy: ScrollViewProxy, viewModel: DialogViewModel, focused: Bool) {
        if focused && !viewModel.screenplayElements.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.scrollToLastElement(proxy: proxy, elements: viewModel.screenplayElements)
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
                    Button(action: {
                        settingsManager.updateCenterLines(!settingsManager.centerLinesEnabled)
                    }) {
                        Label("Center Dialog Lines".localized, systemImage: settingsManager.centerLinesEnabled ? "checkmark" : "lines.measurement.vertical")
                    }
                    
                    Divider()
                    
                    ShareLink(
                        item: viewModel.exportToFDXURL(),
                        preview: SharePreview("Dialog.fdx", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Export to Final Draft".localized, systemImage: "doc.text")
                    }
                    
                    ShareLink(
                        item: viewModel.exportToRTFURL(),
                        preview: SharePreview("Dialog.rtf", image: Image(systemName: "doc.richtext"))
                    ) {
                        Label("Export as RTF".localized, systemImage: "doc.richtext")
                    }
                    
                    ShareLink(
                        item: viewModel.exportToTextURL(),
                        preview: SharePreview("Dialog.txt", image: Image(systemName: "doc.plaintext"))
                    ) {
                        Label("Export as Text".localized, systemImage: "doc.plaintext")
                    }
                } label: {
                    Group {
                        if let toolbarTransition = toolbarTransition {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary)
                                .matchedGeometryEffect(id: "toolbarIcon", in: toolbarTransition)
                        } else {
                            Image(systemName: "ellipsis")
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
        .alert("Rename Dialog".localized, isPresented: $showingTitleRenameAlert) {
            TextField("Dialog name".localized, text: $newTitle)
            Button("Cancel".localized, role: .cancel) { }
            Button("Save".localized) {
                viewModel.updateTitle(newTitle)
            }
        } message: {
            Text("Enter a new name for this dialog".localized)
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
            if !viewModel.screenplayElements.isEmpty {
                onSave?(viewModel)
            }
        }
        .onChange(of: viewModel.shouldFocusInput) { _, shouldFocus in
            isInputFocused = shouldFocus
        }
    }
    
        // MARK: - Screenplay Elements View
    private var textlinesView: some View {
        ScrollViewReader { proxy in
            screenplayElementsList
                .onChange(of: viewModel.screenplayElements.count) { _, _ in
                    scrollCoordinator.handleElementCountChange(proxy: proxy, viewModel: viewModel)
                }
                .onChange(of: viewModel.showInputArea) { _, newValue in
                    scrollCoordinator.handleInputAreaChange(proxy: proxy, viewModel: viewModel, showInputArea: newValue)
                }
                .onChange(of: isInputFocused) { _, focused in
                    scrollCoordinator.handleFocusChange(proxy: proxy, viewModel: viewModel, focused: focused)
                }
        }
    }

    private var screenplayElementsList: some View {
        List {
            if !viewModel.screenplayElements.isEmpty {
                screenplayElementsForEach
            } else {
                emptyStateView
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, viewModel.showInputArea ? 60 : 0)
        .contentMargins(.top, viewModel.isFullscreenMode ? 0 : 0)
        .onTapGesture {
            viewModel.handleViewTap()
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            // Completely empty state
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var screenplayElementsForEach: some View {
        ForEach(Array(getGroupedElements().enumerated()), id: \.element.id) { index, groupedElement in
            GroupedElementRowView(
                groupedElement: groupedElement,
                customSpeakerNames: viewModel.customSpeakerNames,
                centerLines: settingsManager.centerLinesEnabled
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .id(groupedElement.id)
        }
    }
    
    // MARK: - Helper Methods
    private func getGroupedElements() -> [GroupedElement] {
        var groupedElements: [GroupedElement] = []
        var i = 0
        
        while i < viewModel.screenplayElements.count {
            let element = viewModel.screenplayElements[i]
            
            // Check if this element should start a new group (speaker with potential parenthetical)
            if (element.type == .dialogue || element.type == .parenthetical) && element.speaker != nil {
                let speaker = element.speaker!
                var elementsInGroup: [ScreenplayElement] = []
                
                // Add current element
                elementsInGroup.append(element)
                
                // Look ahead for parentheticals from the same speaker
                var j = i + 1
                while j < viewModel.screenplayElements.count {
                    let nextElement = viewModel.screenplayElements[j]
                    if nextElement.type == .parenthetical && nextElement.speaker == speaker {
                        elementsInGroup.append(nextElement)
                        j += 1
                    } else if nextElement.type == .dialogue && nextElement.speaker == speaker {
                        elementsInGroup.append(nextElement)
                        j += 1
                    } else {
                        break
                    }
                }
                
                // Create grouped element
                groupedElements.append(GroupedElement(
                    id: element.id,
                    speaker: speaker,
                    elements: elementsInGroup
                ))
                
                i = j
            } else {
                // For actions or other standalone elements, create single-element groups
                groupedElements.append(GroupedElement(
                    id: element.id,
                    speaker: nil,
                    elements: [element]
                ))
                i += 1
            }
        }
        
        return groupedElements
    }
    
    // MARK: - Input Area View
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            Color(.label)
                .frame(height: 1)
            
            ElementTypeSelectorView(
                selectedElementType: $viewModel.selectedElementType,
                viewModel: viewModel
            )
            .padding(.top, 12)
            
            if viewModel.selectedElementType.requiresSpeaker {
                SpeakerSelectorView(
                    selectedSpeaker: $viewModel.selectedSpeaker, 
                    viewModel: viewModel,
                    isInputFocused: $isInputFocused,
                    isEditingMode: viewModel.isEditingText
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            HStack {
                            TextInputView(
                text: $viewModel.inputText,
                isInputFocused: $isInputFocused,
                onSubmit: viewModel.addText,
                isEditing: viewModel.isEditingText,
                selectedSpeaker: viewModel.selectedSpeaker,
                selectedElementType: viewModel.selectedElementType
            )
                
                if viewModel.isEditingText {
                    Button("Cancel".localized) {
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

struct ScreenplayElementRowView: View {
    let element: ScreenplayElement
    let allElements: [ScreenplayElement]
    let currentIndex: Int
    let customSpeakerNames: [Speaker: String]
    let isFlagged: Bool
    let isBeingEdited: Bool
    let centerLines: Bool
    
    var body: some View {
        HStack {
            if centerLines || element.type == .action {
                centeredOrActionView
            } else {
                // Use speaker views for both dialogue and parentheticals
                if element.isSpeakerA {
                    speakerAView
                    Spacer()
                } else {
                    Spacer()
                    speakerBView
                }
            }
        }
        .padding(element.type == .action ? .vertical : .all)
        .padding(.horizontal, element.type == .action ? 0 : 16)
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
            return Color(.label)
        }
    }
    
    private var centeredOrActionView: some View {
        VStack(alignment: element.type == .action ? .leading : .center, spacing: element.type == .parenthetical ? 1 : 4) {
            if element.type != .action {
                elementTypeLabel
            }
            
            // Use the same format as normal view, just centered
            Text(element.content)
                .font(elementFont)
                .fontWeight(elementFontWeight)
                .italic(element.type == .parenthetical)
                .foregroundColor(element.type == .parenthetical ? Color.secondary : Color.primary)
                .multilineTextAlignment(element.type == .action ? .leading : .center)
                .frame(maxWidth: .infinity, alignment: element.type == .action ? .leading : .center)
        }
    }
    
    private var speakerAView: some View {
        VStack(alignment: .leading, spacing: element.type == .parenthetical ? 1 : 4) {
            elementTypeLabel
            
            // Same format as normal view
            Text(element.content)
                .font(elementFont)
                .fontWeight(elementFontWeight)
                .italic(element.type == .parenthetical)
                .foregroundColor(element.type == .parenthetical ? Color.secondary : Color.primary)
                .multilineTextAlignment(.leading)
        }
    }
    
    private var speakerBView: some View {
        VStack(alignment: .trailing, spacing: element.type == .parenthetical ? 1 : 4) {
            elementTypeLabel
            
            // Same format as normal view
            Text(element.content)
                .font(elementFont)
                .fontWeight(elementFontWeight)
                .italic(element.type == .parenthetical)
                .foregroundColor(element.type == .parenthetical ? Color.secondary : Color.primary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    @ViewBuilder
    private var elementTypeLabel: some View {
        switch element.type {
        case .dialogue:
            // Always show speaker name for dialogue in center mode (like normal view)
            if let speaker = element.speaker {
                Text(speaker.displayName(customNames: customSpeakerNames))
                    .font(.headline)
                    .fontWeight(.black)
            }
            
        case .parenthetical:
            // Always show speaker name for parentheticals in center mode (like normal view)
            if let speaker = element.speaker {
                Text(speaker.displayName(customNames: customSpeakerNames))
                    .font(.headline)
                    .fontWeight(.black)
            }
            
        case .action:
            EmptyView()
        }
    }
    
    // Helper to determine if we should show speaker name for any speaker element
    private var shouldShowSpeakerName: Bool {
        guard element.type == .dialogue || element.type == .parenthetical,
              let currentSpeaker = element.speaker else {
            return false
        }
        
        // If this is the first element, show speaker name
        if currentIndex == 0 {
            return true
        }
        
        // If the previous element is from a different speaker, show speaker name
        let previousElement = allElements[currentIndex - 1]
        return previousElement.speaker != currentSpeaker
    }
    
    private var elementFont: Font {
        switch element.type {
        case .dialogue:
            return .body
        case .parenthetical:
            return .body  // Same size as dialogue for better readability
        case .action:
            return .body
        }
    }
    
    private var elementFontWeight: Font.Weight {
        switch element.type {
        case .dialogue:
            return .light
        case .parenthetical:
            return .regular
        case .action:
            return .regular
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
        .alert("Rename Speaker".localized, isPresented: $showingRenameAlert) {
            TextField("Speaker name".localized, text: $newSpeakerName)
            Button("Cancel".localized, role: .cancel) { }
            Button("Save".localized) {
                if let speaker = speakerToRename {
                    viewModel.renameSpeaker(speaker, to: newSpeakerName)
                }
            }
        } message: {
            Text("Enter a custom name for this speaker".localized)
        }
    }
}

struct TextInputView: View {
    @Binding var text: String
    @FocusState.Binding var isInputFocused: Bool
    let onSubmit: () -> Void
    let isEditing: Bool
    let selectedSpeaker: Speaker
    let selectedElementType: ScreenplayElementType
    
    private var placeholder: String {
        if isEditing {
            return "Edit \(selectedElementType.displayName.lowercased())...".localized
        } else {
            switch selectedElementType {
            case .dialogue:
                return "Enter dialog...".localized
            case .parenthetical:
                return "Type parenthetical text...".localized
            case .action:
                return "Enter action...".localized
            }
        }
    }
    
    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(selectedElementType == .action ? 1...10 : 1...4)
            .focused($isInputFocused)
            .onSubmit {
                onSubmit()
            }
            .multilineTextAlignment(getTextAlignment())
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .onChange(of: selectedElementType) { _, newType in
                // When switching to parenthetical mode, start with opening parenthesis
                if newType == .parenthetical && text.isEmpty {
                    text = "("
                    // Position cursor at the end
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let textField = UIResponder.currentFirstResponder as? UITextField {
                            let endPosition = textField.endOfDocument
                            textField.selectedTextRange = textField.textRange(from: endPosition, to: endPosition)
                        }
                    }
                }
            }
    }
    
    private func getTextAlignment() -> TextAlignment {
        if isEditing && selectedSpeaker == .b {
            return .trailing
        }
        
        switch selectedElementType {
        case .dialogue:
            return selectedSpeaker == .b ? .trailing : .leading
        case .parenthetical:
            return selectedSpeaker == .b ? .trailing : .leading  // Align with speaker
        case .action:
            return .leading
        }
    }
}

struct ElementTypeSelectorView: View {
    @Binding var selectedElementType: ScreenplayElementType
    @ObservedObject var viewModel: DialogViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Only show Parenthetical and Action buttons (skip dialogue)
            ForEach([ScreenplayElementType.parenthetical, ScreenplayElementType.action], id: \.self) { elementType in
                Button(action: {
                    // Toggle behavior: if already selected, go back to dialogue
                    if selectedElementType == elementType {
                        selectedElementType = .dialogue
                    } else {
                        selectedElementType = elementType
                    }
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    Text(elementType.displayName)
                        .font(.caption)
                        .fontWeight(selectedElementType == elementType ? .semibold : .regular)
                        .foregroundColor(selectedElementType == elementType ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedElementType == elementType ? Color.accentColor : Color(.systemGray5))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
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
