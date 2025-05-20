import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"
    
    static let shared = LocalizationManager()
    
    private init() {}
    
    var currentLanguage: String {
        get { selectedLanguage }
        set { selectedLanguage = newValue }
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