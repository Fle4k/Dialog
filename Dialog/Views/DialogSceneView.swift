import SwiftUI
import UIKit

// Note: Removed expensive UIResponder extension for better performance

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
        return groupedElement.elements.contains { element in
            viewModel.isElementFlagged(element.id)
        }
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
        .contentShape(Rectangle())
        .onTapGesture {
            // Regular tap does nothing - user must long press to edit
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press starts editing the group content
            viewModel.startEditingGroup(groupedElement)
        }

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
                        customSpeakerNames: customSpeakerNames,
                        groupedElement: groupedElement
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
                        customSpeakerNames: customSpeakerNames,
                        groupedElement: groupedElement
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
                    customSpeakerNames: customSpeakerNames,
                    groupedElement: groupedElement
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
        // Don't auto-scroll during edit mode - user wants to stay in place
        if !viewModel.isEditingText && !viewModel.isEditingElementType {
            scrollToLastElement(proxy: proxy, elements: viewModel.screenplayElements)
        }
    }
    
    func handleInputAreaChange(proxy: ScrollViewProxy, viewModel: DialogViewModel, showInputArea: Bool) {
        // Don't auto-scroll during edit mode - user wants to stay in place
        if showInputArea && !viewModel.screenplayElements.isEmpty && !viewModel.isEditingText && !viewModel.isEditingElementType {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.scrollToLastElement(proxy: proxy, elements: viewModel.screenplayElements)
            }
        }
    }
    
    func handleFocusChange(proxy: ScrollViewProxy, viewModel: DialogViewModel, focused: Bool) {
        // Don't auto-scroll during edit mode - user wants to stay in place  
        if focused && !viewModel.screenplayElements.isEmpty && !viewModel.isEditingText && !viewModel.isEditingElementType {
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
    
    // Speaker rename from dialog state
    @State private var newSpeakerName = ""
    
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
                // Check what the action description says to determine whether to undo or redo
                let actionDescription = viewModel.getLastActionDescription()
                if actionDescription == "Redo" {
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
                    
                    Button("Export to Final Draft".localized) {
                        exportDocument(type: .fdx)
                    }
                    
                    Button("Export as RTF".localized) {
                        exportDocument(type: .rtf)
                    }
                    
                    Button("Export as Text".localized) {
                        exportDocument(type: .text)
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
        .alert("Rename Speaker".localized, isPresented: .constant(viewModel.speakerToRenameFromDialog != nil)) {
            TextField("Speaker name".localized, text: Binding(
                get: { viewModel.customSpeakerNames[viewModel.speakerToRenameFromDialog ?? .a] ?? "" },
                set: { newSpeakerName = $0 }
            ))
            Button("Cancel".localized, role: .cancel) { 
                viewModel.speakerToRenameFromDialog = nil
            }
            Button("Save".localized) {
                if let speaker = viewModel.speakerToRenameFromDialog {
                    viewModel.renameSpeaker(speaker, to: newSpeakerName)
                }
                viewModel.speakerToRenameFromDialog = nil
            }
        } message: {
            Text("Enter a custom name for this speaker".localized)
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
                    // Only auto-scroll when not in edit mode to prevent scrolling away from edited content
                    if !viewModel.isEditingText && !viewModel.isEditingElementType {
                        scrollCoordinator.handleElementCountChange(proxy: proxy, viewModel: viewModel)
                    }
                }
                .onChange(of: viewModel.showInputArea) { _, newValue in
                    // Only auto-scroll when not in edit mode
                    if !viewModel.isEditingText && !viewModel.isEditingElementType {
                        scrollCoordinator.handleInputAreaChange(proxy: proxy, viewModel: viewModel, showInputArea: newValue)
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    // Only auto-scroll when not in edit mode
                    if !viewModel.isEditingText && !viewModel.isEditingElementType {
                        scrollCoordinator.handleFocusChange(proxy: proxy, viewModel: viewModel, focused: focused)
                    }
                }
        }
    }

    private var screenplayElementsList: some View {
        List {
            if !viewModel.screenplayElements.isEmpty {
                screenplayElementsForEach
                
                // Add invisible spacer that can handle background taps
                Color.clear
                    .frame(height: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // If editing element type or text, exit the edit mode
                        if viewModel.isEditingElementType || viewModel.isEditingText {
                            // Cancel edit mode when tapping above input field (replaces cancel button)
                            viewModel.cancelEditMode()
                        } else {
                            viewModel.handleViewTap()
                        }
                    }
            } else {
                emptyStateView
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, viewModel.showInputArea ? 60 : 0)
        .contentMargins(.top, viewModel.isFullscreenMode ? 0 : 0)
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
        .contentShape(Rectangle())
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
        ForEach(Array(viewModel.groupedElements.enumerated()), id: \.element.id) { index, groupedElement in
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
    
    private enum DocumentType {
        case fdx, rtf, text
    }
    
    private func exportDocument(type: DocumentType) {
        let url: URL
        
        switch type {
        case .fdx:
            url = viewModel.exportToFDXURL()
        case .rtf:
            url = viewModel.exportToRTFURL()
        case .text:
            url = viewModel.exportToTextURL()
        }
        
        // Present the share sheet
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // For iPad, set the popover presentation controller
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func shouldShowSpeakerName(for index: Int) -> Bool {
        let groupedElements = viewModel.groupedElements
        guard index < groupedElements.count else { 
            return true 
        }
        
        let currentGroup = groupedElements[index]
        
        // Always show speaker name for first group
        guard index > 0 else { 
            return true 
        }
        
        let previousGroup = groupedElements[index - 1]
        
        // Show speaker name only if the speaker changed from the previous group
        return currentGroup.speaker != previousGroup.speaker
    }
    
    /// Determines if a speaker should show "(CONT'D)" after their name
    /// According to screenplay formatting, CONT'D is added when a character speaks again
    /// after an action line has interrupted their dialogue
    private func shouldShowContd(for index: Int) -> Bool {
        let groupedElements = viewModel.groupedElements
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
                
                // Cancel button removed - tapping above input field will be the cancel behavior
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
    let groupedElement: GroupedElement // Add reference to the grouped element
    
    // Computed properties for selective blurring
    private var isEditingElementContent: Bool {
        viewModel.isEditingText && viewModel.editingGroupId == groupedElement.id
    }
    
    private var isEditingCharacterExtension: Bool {
        // Only blur character extensions when editing element type AND this specific element AND it has a character extension
        viewModel.isEditingElementType && 
        viewModel.editingGroupId == element.id && 
        element.type.characterExtension != nil
    }
    
    private var isRenamingSpeaker: Bool {
        viewModel.speakerToRenameFromDialog != nil && viewModel.speakerToRenameFromDialog == element.speaker
    }
    
    var body: some View {
        VStack(alignment: viewAlignment, spacing: 2) {
            // Show speaker name and extension for this individual element when needed
            if showSpeakerName && element.type.requiresSpeaker, let speaker = element.speaker {
                HStack(spacing: 4) {
                    Text(speaker.displayName(customNames: customSpeakerNames))
                        .font(.headline)
                        .fontWeight(.black)
                        // Only blur speaker name when being renamed
                        .blur(radius: isRenamingSpeaker ? 2 : 0)
                        .animation(.easeInOut(duration: 0.3), value: isRenamingSpeaker)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            // Long press on speaker name in dialog scene allows renaming
                            startRenamingSpeaker(speaker)
                        }
                    if shouldShowContd {
                        Text("(CONT'D)")
                            .font(.headline)
                            .fontWeight(.light)
                            .italic()
                            .foregroundColor(.secondary)
                            // Never blur (CONT'D)
                    } else if let extensionString = element.type.characterExtension {
                        Text(extensionString)
                            .font(.headline)
                            .fontWeight(.light)
                            .italic()
                            .foregroundColor(.secondary)
                            // Only blur character extension when this specific element is being edited
                            .blur(radius: isEditingCharacterExtension ? 2 : 0)
                            .animation(.easeInOut(duration: 0.3), value: isEditingCharacterExtension)
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        print("🛠️ CHARACTER EXTENSION TAP: element \(element.id)")
                                        // Immediately apply the character extension when tapped on Off Screen/VO text
                                        // Apply this extension to the current dialog input immediately
                                        viewModel.immediatelyApplyCharacterExtension(element.type)
                                    }
                            )
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        print("🛠️ CHARACTER EXTENSION LONG PRESS: element \(element.id)")
                                        // Long press on character extension shows options to remove or replace
                                        startEditingCharacterExtension()
                                    }
                            )
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
                        // Only blur content when editing the content itself
                        .blur(radius: isEditingElementContent ? 2 : 0)
                        .animation(.easeInOut(duration: 0.3), value: isEditingElementContent)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Normal tap toggles fullscreen mode
                            viewModel.handleViewTap()
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            // Long press shows comprehensive editing options
                            showElementEditingOptions()
                        }
                } else {
                    Text(element.content)
                        .font(.body)
                        .fontWeight(.light)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        // Only blur content when editing the content itself
                        .blur(radius: isEditingElementContent ? 2 : 0)
                        .animation(.easeInOut(duration: 0.3), value: isEditingElementContent)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Normal tap toggles fullscreen mode
                            viewModel.handleViewTap()
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            // Long press shows comprehensive editing options
                            showElementEditingOptions()
                        }
                }
            }
        }
    }
    
    private var viewAlignment: HorizontalAlignment {
        return alignment
    }
    
    private func startRenamingSpeaker(_ speaker: Speaker) {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Trigger speaker rename from dialog scene
        viewModel.startRenamingSpeakerFromDialog(speaker)
    }
    
    private func startEditingCharacterExtension() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Start editing the character extension with remove/replace options
        viewModel.startEditingElementType(element)
    }
    
    private func showElementEditingOptions() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Show comprehensive editing options for this element
        // This will include edit, remove, and +actions with logic for parentheticals
        viewModel.startEditingElementWithFullOptions(element, groupedElement: groupedElement)
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
            // Disable keyboard suggestions and autocorrection as requested
            .keyboardType(.asciiCapable)
            .autocorrectionDisabled(true)
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
    
    // When editing element type, show different options based on what's being edited
    private var elementTypes: [ScreenplayElementType] {
        if isEditingElementType {
            // Check what type of element we're editing
            if let editingGroupId = viewModel.editingGroupId,
               let editingElement = viewModel.screenplayElements.first(where: { $0.id == editingGroupId }) {
                
                if editingElement.type == .action {
                    // For actions, only show Remove option
                    return [.dialogue]  // dialogue will be shown as "Remove"
                } else if editingElement.type == .parenthetical {
                    // For parentheticals, show only Remove option (no character extensions)
                    return [.dialogue]  // dialogue will be shown as "Remove Parenthetical"
                } else if editingElement.type.characterExtension != nil {
                    // For character extensions (O.S., V.O., Text), show Remove and other character extensions
                    var options: [ScreenplayElementType] = [.dialogue] // Remove option first
                    
                    // Add other character extension options (excluding the current one)
                    let allCharacterExtensions: [ScreenplayElementType] = [.offScreen, .voiceOver, .text]
                    for extensionType in allCharacterExtensions {
                        if extensionType != editingElement.type {
                            options.append(extensionType)
                        }
                    }
                    
                    return options
                } else {
                    // For plain dialogue, show character extension types (no +Action when editing lines)
                    return [.parenthetical, .offScreen, .voiceOver, .text]
                }
            } else {
                // Fallback
                return [.dialogue, .parenthetical, .offScreen, .voiceOver, .text]
            }
        } else {
            // Normal mode (not editing): show all options
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
                            if elementType == .dialogue {
                                // Handle "Remove" button
                                if let editingGroupId = viewModel.editingGroupId,
                                   let editingElement = viewModel.screenplayElements.first(where: { $0.id == editingGroupId }) {
                                    if editingElement.type == .parenthetical {
                                        // For parentheticals, "Remove" means delete completely
                                        viewModel.removeParentheticalCompletely(elementId: editingGroupId)
                                    } else if editingElement.type == .action {
                                        // For actions, "Remove" means delete completely and return to writing mode
                                        viewModel.removeActionCompletely(elementId: editingGroupId)
                                    } else {
                                        // For dialogue with extensions, "Remove" means change back to plain dialogue
                                        viewModel.changeElementType(elementId: editingGroupId, to: .dialogue)
                                    }
                                }
                                viewModel.exitEditMode()
                            } else if elementType == .parenthetical {
                                // Add new parenthetical above current line
                                viewModel.startAddingParentheticalInEditMode()
                            } else {
                                // Apply character extension and exit edit mode immediately
                                if let editingGroupId = viewModel.editingGroupId {
                                    viewModel.changeElementType(elementId: editingGroupId, to: elementType)
                                }
                                viewModel.exitEditMode()
                            }
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
                            .multilineTextAlignment(.center)
                            .frame(
                                minWidth: isEditingElementType && elementType == .dialogue && isEditingParenthetical() ? 180 : 80,
                                maxWidth: isEditingElementType && elementType == .dialogue && isEditingParenthetical() ? .infinity : nil,
                                alignment: .center
                            )
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
        if isEditingElementType {
            if elementType == .dialogue {
                // Check what type of element we're editing to show appropriate remove text
                if let editingGroupId = viewModel.editingGroupId,
                   let editingElement = viewModel.screenplayElements.first(where: { $0.id == editingGroupId }) {
                    switch editingElement.type {
                    case .parenthetical:
                        return "Remove Parenthetical"
                    case .action:
                        return "Remove Action"
                    case .offScreen:
                        return "Remove O.S."
                    case .voiceOver:
                        return "Remove V.O."
                    case .text:
                        return "Remove Text"
                    default:
                        return "Remove"
                    }
                } else {
                    return "Remove"
                }
            } else if editingElement?.type.characterExtension != nil {
                // When editing character extensions, show plain names for replacement options
                return elementType.displayName
            } else {
                // For regular dialogue editing, show + prefix for adding extensions
                return "+ \(elementType.displayName)"
            }
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
    
    private var editingElement: ScreenplayElement? {
        guard let editingGroupId = viewModel.editingGroupId else { return nil }
        return viewModel.screenplayElements.first(where: { $0.id == editingGroupId })
    }
    
    private func isEditingParenthetical() -> Bool {
        guard let editingGroupId = viewModel.editingGroupId,
              let editingElement = viewModel.screenplayElements.first(where: { $0.id == editingGroupId }) else {
            return false
        }
        return editingElement.type == .parenthetical
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
