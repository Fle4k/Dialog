import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    @AppStorage("selectedLanguage") var selectedLanguage: String = "en"
    
    let languages = [
        ("en", "English"),
        ("de", "Deutsch")
    ]
    
    func selectLanguage(_ languageCode: String) {
        selectedLanguage = languageCode
    }
} 