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
    
    private var selectedLanguageInternal: String {
        get { selectedLanguage }
        set { 
            selectedLanguage = newValue
            currentLanguage = newValue
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
        selectedLanguageInternal = language
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