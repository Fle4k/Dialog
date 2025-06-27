import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    @AppStorage("selectedLanguage") private var selectedLanguage = ""
    
    static let shared = LocalizationManager()
    
    // Supported languages with their display names
    let supportedLanguages: [String: String] = [
        "en": "English",
        "de": "Deutsch",
        "fr": "Français", 
        "es": "Español",
        "fi": "Suomi"
        // Korean and Farsi localization files exist but are not yet enabled in the picker
        // "ko": "한국어",
        // "fa": "فارسی"
    ]
    
    private init() {
        // If no language is manually selected, detect system language
        if selectedLanguage.isEmpty {
            selectedLanguage = detectSystemLanguage()
        }
        currentLanguage = selectedLanguage
    }
    
    @Published var currentLanguage: String = ""
    @Published var isLanguageChanging: Bool = false
    
    private var selectedLanguageInternal: String {
        get { selectedLanguage }
        set { 
            selectedLanguage = newValue
            updateLanguage(newValue)
        }
    }
    
    private func detectSystemLanguage() -> String {
        let systemLanguages = Locale.preferredLanguages
        
        // Check if any of the preferred system languages are supported
        for languageCode in systemLanguages {
            let baseLanguage = String(languageCode.prefix(2))
            if supportedLanguages.keys.contains(baseLanguage) {
                return baseLanguage
            }
        }
        
        // Default to English if no supported language found
        return "en"
    }
    
    func setLanguage(_ language: String) {
        // Add smooth transition state
        isLanguageChanging = true
        
        // Delay the actual language change to allow for smooth UI transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.selectedLanguageInternal = language
            
            // Reset transition state after language change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLanguageChanging = false
            }
        }
    }
    
    private func updateLanguage(_ language: String) {
        currentLanguage = language
        
        // Trigger UI update by posting notification
        NotificationCenter.default.post(name: .languageChanged, object: language)
    }
    
    func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        return NSLocalizedString(key, tableName: nil, bundle: bundle ?? Bundle.main, value: "", comment: "")
    }
}

extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
} 