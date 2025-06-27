import SwiftUI

struct TextInputView: View {
    @Binding var text: String
    @FocusState.Binding var isInputFocused: Bool
    let onSubmit: () -> Void
    let isEditing: Bool
    let selectedSpeaker: Speaker
    let selectedElementType: ScreenplayElementType
    
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    private var placeholder: String {
        if isEditing {
            return NSLocalizedString("Edit text...", comment: "Placeholder for editing text")
        } else {
            switch selectedElementType {
            case .dialogue:
                return String(format: NSLocalizedString("%@ says...", comment: "Placeholder for dialogue"), selectedSpeaker.displayName(customNames: [:]))
            case .parenthetical:
                return NSLocalizedString("Add parenthetical...", comment: "Placeholder for parenthetical")
            case .action:
                return NSLocalizedString("Describe action...", comment: "Placeholder for action")
            case .offScreen:
                return String(format: NSLocalizedString("%@ (off screen)...", comment: "Placeholder for off screen"), selectedSpeaker.displayName(customNames: [:]))
            case .voiceOver:
                return String(format: NSLocalizedString("%@ (voice over)...", comment: "Placeholder for voice over"), selectedSpeaker.displayName(customNames: [:]))
            case .text:
                return String(format: NSLocalizedString("%@ (text)...", comment: "Placeholder for text"), selectedSpeaker.displayName(customNames: [:]))
            }
        }
    }
    
    private func getTextAlignment() -> TextAlignment {
        switch selectedElementType {
        case .dialogue:
            return .leading
        case .parenthetical:
            return .leading
        case .action:
            return .leading
        case .offScreen, .voiceOver, .text:
            return .leading
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
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            // Apply predictive text setting and ensure proper capitalization
            .autocorrectionDisabled(!settingsManager.wordSuggestionsEnabled)
            .textInputAutocapitalization(.sentences) // Always capitalize sentences for better UX
            // Use disableAutocorrection instead of keyboardType for better control
            .keyboardType(.default)
            // Set keyboard language based on app language
            .environment(\.locale, Locale(identifier: localizationManager.currentLanguage))
            .onChange(of: selectedElementType) { _, newType in
                // Clear text when switching element types to avoid confusion
                if !text.isEmpty && newType != selectedElementType {
                    text = ""
                }
            }
    }
} 