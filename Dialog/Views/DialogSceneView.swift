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
    @ObservedObject var viewModel: DialogViewModel
    let shouldShowSpeakerName: Bool
    let shouldShowContd: Bool
    let isBeingEdited: Bool
    
    var isAnyElementFlagged: Bool {
        let flagged = groupedElement.elements.contains { element in
            viewModel.isElementFlagged(element.id)
        }
        print("🎨 Visual check for group \(groupedElement.id): flagged = \(flagged)")
        return flagged
    }
    
    var body: some View {
        Group {
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
        .padding()
        .background(isAnyElementFlagged ? Color.primary : Color.clear)
        .foregroundColor(isAnyElementFlagged ? Color(.systemBackground) : Color(.label))
        .cornerRadius(8)
        .blur(radius: isBeingEdited ? 2 : 0)
        .animation(.easeInOut(duration: 0.3), value: isBeingEdited)
    }
    
    private var speakerAGroupView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // All elements for this speaker
                ForEach(groupedElement.elements.indices, id: \.self) { index in
                    let element = groupedElement.elements[index]
                    IndividualElementView(
                        element: element,
                        viewModel: viewModel,
                        isAnyElementFlagged: isAnyElementFlagged,
                        alignment: .leading,
                        showSpeakerName: index == 0 && shouldShowSpeakerName,
                        shouldShowContd: index == 0 && shouldShowContd,
                        customSpeakerNames: customSpeakerNames
                    )
                }
            }
            Spacer()
        }
    }
    
    private var speakerBGroupView: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                // All elements for this speaker
                ForEach(groupedElement.elements.indices, id: \.self) { index in
                    let element = groupedElement.elements[index]
                    IndividualElementView(
                        element: element,
                        viewModel: viewModel,
                        isAnyElementFlagged: isAnyElementFlagged,
                        alignment: .trailing,
                        showSpeakerName: index == 0 && shouldShowSpeakerName,
                        shouldShowContd: index == 0 && shouldShowContd,
                        customSpeakerNames: customSpeakerNames
                    )
                }
            }
        }
    }
    
    private var centeredView: some View {
        VStack(spacing: 6) {
            // Show all elements for this group
            ForEach(groupedElement.elements.indices, id: \.self) { index in
                let element = groupedElement.elements[index]
                IndividualElementView(
                    element: element,
                    viewModel: viewModel,
                    isAnyElementFlagged: isAnyElementFlagged,
                    alignment: element.type == .action ? .leading : .center,
                    showSpeakerName: index == 0 && shouldShowSpeakerName,
                    shouldShowContd: index == 0 && shouldShowContd,
                    customSpeakerNames: customSpeakerNames
                )
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
    
    // Menu animation state
    @State private var centerLinesJustTapped = false
    
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
                    Button(action: {
                        centerLinesJustTapped = true
                        
                        // Delay the actual toggle so we see the checkmark first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            settingsManager.updateCenterLines(!settingsManager.centerLinesEnabled)
                        }
                        
                        // Reset the animation state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            centerLinesJustTapped = false
                        }
                    }) {
                        Text(settingsManager.centerLinesEnabled ? "Dialog Left/Right".localized : "Center Dialog Lines".localized)
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
                    Text(viewModel.currentTitle.isEmpty ? "New Dialog".localized : viewModel.currentTitle)
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
                            
                            newTitle = viewModel.currentTitle.isEmpty ? "New Dialog".localized : viewModel.currentTitle
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
            // Only save the session if it has content (dialogue, parentheticals, or actions)
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
            // If editing element type, exit the edit mode
            if viewModel.isEditingElementType {
                viewModel.exitEditMode()
            } else {
                viewModel.handleViewTap()
            }
        }
        .gesture(
            // Add swipe gesture to go back when in fullscreen mode
            viewModel.isFullscreenMode ? DragGesture()
                .onEnded { value in
                    // Detect left-to-right swipe (back gesture)
                    let horizontalDistance = value.translation.width
                    let verticalDistance = abs(value.translation.height)
                    
                    // Swipe must be more horizontal than vertical and start from left edge
                    if horizontalDistance > 100 && horizontalDistance > verticalDistance * 2 && value.startLocation.x < 50 {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        // Dismiss the view (go back to main menu)
                        dismiss()
                    }
                } : nil
        )
    }
    
    private var emptyStateView: some View {
        VStack {
            // Completely empty state
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .onTapGesture {
            // If editing element type, exit the edit mode
            if viewModel.isEditingElementType {
                viewModel.exitEditMode()
            } else {
                viewModel.handleViewTap()
            }
        }
    }

    private var screenplayElementsForEach: some View {
        ForEach(Array(getGroupedElements().enumerated()), id: \.element.id) { index, groupedElement in
            GroupedElementRowView(
                groupedElement: groupedElement,
                customSpeakerNames: viewModel.customSpeakerNames,
                centerLines: settingsManager.centerLinesEnabled,
                viewModel: viewModel,
                shouldShowSpeakerName: shouldShowSpeakerName(for: index),
                shouldShowContd: shouldShowContd(for: index),
                isBeingEdited: viewModel.editingGroupId == groupedElement.id
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .id(groupedElement.id)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                let isAnyFlagged = groupedElement.elements.contains { element in
                    viewModel.isElementFlagged(element.id)
                }
                Button {
                    print("🚩 Flag button tapped for group: \(groupedElement.id)")
                    // Flag/unflag all elements in this group
                    for element in groupedElement.elements {
                        print("🚩 Toggling flag for element: \(element.id)")
                        viewModel.toggleFlag(for: element.id)
                    }
                    print("🚩 Flag action completed")
                } label: {
                    Image(systemName: isAnyFlagged ? "flag.slash.fill" : "flag.fill")
                        .font(.title2)
                }
                .tint(.orange)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    // Delete all elements in this group
                    for element in groupedElement.elements {
                        viewModel.deleteScreenplayElement(withId: element.id)
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                }
                .tint(.red)
            }

        }
    }
    

    
    // MARK: - Helper Methods
    private func getGroupedElements() -> [GroupedElement] {
        var groupedElements: [GroupedElement] = []
        var i = 0
        
        print("🎭 getGroupedElements: starting with \(viewModel.screenplayElements.count) elements")
        
        while i < viewModel.screenplayElements.count {
            let element = viewModel.screenplayElements[i]
            
            // Check if this element should start a new group (speaker with potential parenthetical)
            if element.type.requiresSpeaker && element.speaker != nil {
                let speaker = element.speaker!
                var elementsInGroup: [ScreenplayElement] = []
                
                // Add current element
                elementsInGroup.append(element)
                print("🎭 Starting new group for speaker \(speaker.rawValue), element type: \(element.type)")
                
                // Look ahead for consecutive elements from the same speaker
                var j = i + 1
                while j < viewModel.screenplayElements.count {
                    let nextElement = viewModel.screenplayElements[j]
                    // Group together if same speaker and requires speaker
                    if nextElement.speaker == speaker && nextElement.type.requiresSpeaker {
                        elementsInGroup.append(nextElement)
                        print("🎭 Adding element to group: speaker \(speaker.rawValue), type: \(nextElement.type)")
                        j += 1
                    } else {
                        print("🎭 Breaking group: next element speaker \(nextElement.speaker?.rawValue ?? "nil"), type: \(nextElement.type)")
                        break
                    }
                }
                
                // Create grouped element
                let groupedElement = GroupedElement(
                    id: element.id,
                    speaker: speaker,
                    elements: elementsInGroup
                )
                groupedElements.append(groupedElement)
                print("🎭 Created group \(groupedElement.id) with \(elementsInGroup.count) elements for speaker \(speaker.rawValue)")
                
                i = j
            } else {
                // For actions or other standalone elements, create single-element groups
                let groupedElement = GroupedElement(
                    id: element.id,
                    speaker: nil,
                    elements: [element]
                )
                groupedElements.append(groupedElement)
                print("🎭 Created single-element group for non-dialogue element: \(element.type)")
                i += 1
            }
        }
        
        print("🎭 Final result: \(groupedElements.count) groups")
        return groupedElements
    }
    
    private func shouldShowSpeakerName(for index: Int) -> Bool {
        let groupedElements = getGroupedElements()
        guard index < groupedElements.count else { 
            print("🏷️ shouldShowSpeakerName: index \(index) out of bounds, showing speaker name")
            return true 
        }
        
        let currentGroup = groupedElements[index]
        
        // Always show speaker name for first group
        guard index > 0 else { 
            print("🏷️ shouldShowSpeakerName: first group (\(currentGroup.id)), showing speaker name")
            return true 
        }
        
        let previousGroup = groupedElements[index - 1]
        
        // Show speaker name only if the speaker changed from the previous group
        let shouldShow = currentGroup.speaker != previousGroup.speaker
        print("🏷️ shouldShowSpeakerName: index \(index), current: \(currentGroup.speaker?.rawValue ?? "nil"), previous: \(previousGroup.speaker?.rawValue ?? "nil"), shouldShow: \(shouldShow)")
        return shouldShow
    }
    
    /// Determines if a speaker should show "(CONT'D)" after their name
    /// According to screenplay formatting, CONT'D is added when a character speaks again
    /// after an action line has interrupted their dialogue
    private func shouldShowContd(for index: Int) -> Bool {
        let groupedElements = getGroupedElements()
        guard index > 0 && index < groupedElements.count else { return false }
        
        let currentGroup = groupedElements[index]
        guard let currentSpeaker = currentGroup.speaker else { return false }
        
        // Look backwards to find the previous dialogue from the same speaker
        for i in (0..<index).reversed() {
            let previousGroup = groupedElements[i]
            
            if let previousSpeaker = previousGroup.speaker {
                // If we find the same speaker, check if there's an action in between
                if previousSpeaker == currentSpeaker {
                    // Check if there's an action element between them
                    for j in (i+1)..<index {
                        let intermediateGroup = groupedElements[j]
                        if intermediateGroup.elements.contains(where: { $0.type == .action }) {
                            print("🏷️ shouldShowContd: Speaker \(currentSpeaker.rawValue) continuing after action, showing CONT'D")
                            return true
                        }
                    }
                    // If we found the same speaker without action in between, no CONT'D needed
                    return false
                } else {
                    // Different speaker found, so no continuation
                    return false
                }
            } else {
                // This is an action or other non-speaker element, continue looking
                continue
            }
        }
        
        return false
    }
    
    // MARK: - Helper Properties
    private var shouldShowSpeakerSelector: Bool {
        // Always show speaker selector when input area is visible
        // This allows users to change speakers for the entire row even after adding parenthicals
        print("🎯 Speaker selector: SHOW (always available for speaker switching)")
        return true
    }
    
    // MARK: - Input Area View
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            // A/B Speaker Selector (moved to top)
            if shouldShowSpeakerSelector {
                SpeakerSelectorView(
                    selectedSpeaker: $viewModel.selectedSpeaker, 
                    viewModel: viewModel,
                    isInputFocused: $isInputFocused,
                    isEditingMode: viewModel.isEditingText,
                    isDisabled: !viewModel.selectedElementType.requiresSpeaker
                )
                .padding(.horizontal, 32) // Match dialogue row padding: listRowInsets(16) + GroupedElementRowView.padding(16) = 32
                .padding(.top, 12)
            }
            
            // Text Input Field (moved up)
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
            .padding(.top, 2) // Reduced from 6 to 2 to match tight dialogue scene spacing
            
            // Element Type Selector (moved to bottom)
            ElementTypeSelectorView(
                selectedElementType: $viewModel.selectedElementType,
                viewModel: viewModel
            )
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
        guard viewModel.canUndo() || viewModel.canRedo() else { return }
        
        // Show undo/redo confirmation
        showingUndoToast = true
    }
}

// MARK: - Supporting Views
struct IndividualElementView: View {
    let element: ScreenplayElement
    @ObservedObject var viewModel: DialogViewModel
    let isAnyElementFlagged: Bool
    var alignment: HorizontalAlignment = .leading
    let showSpeakerName: Bool
    let shouldShowContd: Bool
    let customSpeakerNames: [Speaker: String]
    

    
    var body: some View {
        VStack(alignment: viewAlignment, spacing: 2) {
            // Show speaker name and extension for this individual element when needed
            if showSpeakerName && element.type.requiresSpeaker, let speaker = element.speaker {
                HStack(spacing: 4) {
                    Text(speaker.displayName(customNames: customSpeakerNames))
                        .font(.headline)
                        .fontWeight(.black)
                    if shouldShowContd {
                        Text("(CONT'D)")
                            .font(.headline)
                            .fontWeight(.light)
                            .italic()
                            .foregroundColor(.secondary)
                    } else if let extensionString = element.type.characterExtension {
                        Text(extensionString)
                            .font(.headline)
                            .fontWeight(.light)
                            .italic()
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                // Quick edit element type by tapping on the extension
                                startEditingElementType()
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                // Long press on character extension also activates element type editing
                                startEditingElementType()
                            }
                    }
                }
            }
            
            // The actual content
            Group {
                if element.type == .parenthetical {
                    Text("(\(element.content))")
                        .font(.caption)
                        .foregroundColor(isAnyElementFlagged ? Color(.systemBackground).opacity(0.8) : .secondary)
                        .italic()
                        .multilineTextAlignment(textAlignment)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            // Long press on content opens edit mode
                            editElementContent()
                        }
                } else {
                    Text(element.content)
                        .font(.body)
                        .fontWeight(.light)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            // Long press on content opens edit mode
                            editElementContent()
                        }
                }
            }
        }
    }
    
    private var viewAlignment: HorizontalAlignment {
        return alignment
    }
    
    private func startEditingElementType() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Start editing the element type using the existing element type selector
        viewModel.startEditingElementType(element)
    }
    
    private func editElementContent() {
        // Add haptic feedback for content editing
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Start editing the element content
        viewModel.startEditingElement(element)
    }
    
    private var textAlignment: TextAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }
    
    private var frameAlignment: Alignment {
        switch alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }
}

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
            
        case .offScreen, .voiceOver, .text:
            // Show speaker name for these dialogue variants
            if let speaker = element.speaker {
                Text(speaker.displayName(customNames: customSpeakerNames))
                    .font(.headline)
                    .fontWeight(.black)
            }
        }
    }
    
    // Helper to determine if we should show speaker name for any speaker element
    private var shouldShowSpeakerName: Bool {
        guard element.type.requiresSpeaker,
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
        case .offScreen, .voiceOver, .text:
            return .body  // Same as dialogue
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
        case .offScreen, .voiceOver, .text:
            return .light  // Same as dialogue
        }
    }
}

struct SpeakerSelectorView: View {
    @Binding var selectedSpeaker: Speaker
    let viewModel: DialogViewModel
    @FocusState.Binding var isInputFocused: Bool
    let isEditingMode: Bool
    let isDisabled: Bool
    @State private var showingRenameAlert = false
    @State private var speakerToRename: Speaker? = nil
    @State private var newSpeakerName = ""
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Speaker.allCases, id: \.self) { speaker in
                HStack {
                    if speaker == .a {
                        // A speaker - align text to the left
                        Text(speaker.displayName(customNames: viewModel.customSpeakerNames))
                            .font(.headline)
                            .fontWeight(.black)
                            .foregroundColor(isDisabled ? Color(.systemGray4) : (selectedSpeaker == speaker ? .primary : Color(.systemGray4)))
                        Spacer()
                    } else {
                        // B speaker - align text to the right
                        Spacer()
                        Text(speaker.displayName(customNames: viewModel.customSpeakerNames))
                            .font(.headline)
                            .fontWeight(.black)
                            .foregroundColor(isDisabled ? Color(.systemGray4) : (selectedSpeaker == speaker ? .primary : Color(.systemGray4)))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .contentShape(Rectangle())
                .opacity(isDisabled ? 0.5 : (isEditingMode ? (selectedSpeaker == speaker ? 1.0 : 0.7) : 1.0))
                .onTapGesture {
                    guard !isDisabled else { return }
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
                            guard !isDisabled else { return }
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
                return "(enter parenthetical)".localized
            case .action:
                return "Enter action...".localized
            case .offScreen:
                return "Enter off screen dialog...".localized
            case .voiceOver:
                return "Enter voice over...".localized
            case .text:
                return "Enter text dialog...".localized
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
            .foregroundColor(.primary)  // System black in light mode, white in dark mode
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .onChange(of: selectedElementType) { _, newType in
                // Clear text when switching element types to avoid confusion
                if !text.isEmpty && newType != selectedElementType {
                    text = ""
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
        case .offScreen, .voiceOver, .text:
            return selectedSpeaker == .b ? .trailing : .leading  // Same as dialogue
        }
    }
}

struct ElementTypeSelectorView: View {
    @Binding var selectedElementType: ScreenplayElementType
    @ObservedObject var viewModel: DialogViewModel
    
    // Check if last element is parenthetical to enforce dialogue-only rule
    private var isLastElementParenthetical: Bool {
        viewModel.screenplayElements.last?.type == .parenthetical
    }
    
    // Only disable if last element is parenthetical AND there's no text being typed AND not editing element type
    private var shouldDisableNonDialogue: Bool {
        !viewModel.isEditingElementType && isLastElementParenthetical && viewModel.inputText.isEmpty
    }
    
    // When editing element type, show all options including dialogue
    private var isEditingElementType: Bool {
        viewModel.isEditingElementType
    }
    
    // Define the order of element types as requested: Action, Parenthetical, Off Screen, Voice Over, Text
    // When editing element type, show Remove option plus all character extension types
    private var elementTypes: [ScreenplayElementType] {
        if isEditingElementType {
            return [.dialogue, .offScreen, .voiceOver, .text]  // dialogue will be shown as "Remove"
        } else {
            return [.action, .parenthetical, .offScreen, .voiceOver, .text]
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(elementTypes.enumerated()), id: \.element) { index, elementType in
                    Button(action: {
                        // Add haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        if isEditingElementType {
                            // When editing element type, apply the change and exit edit mode
                            if let editingGroupId = viewModel.editingGroupId {
                                // dialogue type means "Remove" - keep as dialogue, others are character extensions
                                viewModel.changeElementType(elementId: editingGroupId, to: elementType)
                            }
                            viewModel.exitEditMode()
                        } else {
                            // Normal behavior: Toggle between selected type and dialogue
                            if selectedElementType == elementType {
                                selectedElementType = .dialogue
                            } else {
                                selectedElementType = elementType
                            }
                        }
                    }) {
                        Text(getDisplayName(for: elementType))
                            .font(.caption)
                            .fontWeight(isCurrentlySelected(elementType) ? .black : .regular)
                            .foregroundColor(buttonTextColor(for: elementType))
                            .frame(minWidth: 80) // Minimum width, but allow content to determine size
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(shouldDisableNonDialogue && !isEditingElementType)
                    
                    // Add vertical divider after each button except the last one
                    if index < elementTypes.count - 1 {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 1, height: 20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func getDisplayName(for elementType: ScreenplayElementType) -> String {
        if isEditingElementType && elementType == .dialogue {
            return "Remove"
        } else {
            return elementType.displayName
        }
    }
    
    private func isCurrentlySelected(_ elementType: ScreenplayElementType) -> Bool {
        if isEditingElementType {
            // When editing element type, check against the element being edited
            guard let editingGroupId = viewModel.editingGroupId,
                  let editingElement = viewModel.screenplayElements.first(where: { $0.id == editingGroupId }) else {
                return false
            }
            // Show "Remove" as selected if editing a dialogue type, otherwise match the type
            if elementType == .dialogue {
                return editingElement.type == .dialogue
            } else {
                return editingElement.type == elementType
            }
        } else {
            return selectedElementType == elementType
        }
    }
    
    private func buttonTextColor(for elementType: ScreenplayElementType) -> Color {
        if shouldDisableNonDialogue {
            return .secondary
        } else if isCurrentlySelected(elementType) {
            return .accentColor  // Always use accent color when selected
        } else {
            return .primary
        }
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
