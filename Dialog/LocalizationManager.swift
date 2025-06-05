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
    ]
    
    private init() {
        // If no language is manually selected, detect system language
        if selectedLanguage.isEmpty {
            selectedLanguage = detectSystemLanguage()
        }
    }
    
    var currentLanguage: String {
        get { selectedLanguage }
        set { selectedLanguage = newValue }
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
    
    func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        return NSLocalizedString(key, tableName: nil, bundle: bundle ?? Bundle.main, value: "", comment: "")
    }
}

extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
} 