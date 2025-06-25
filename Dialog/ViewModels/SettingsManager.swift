import Foundation
import SwiftUI

// MARK: - Settings Manager
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var centerLinesEnabled: Bool = false
    @Published var iCloudSyncEnabled: Bool = false
    @Published var wordSuggestionsEnabled: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let centerLinesKey = "centerLinesEnabled"
    private let iCloudSyncKey = "iCloudSyncEnabled"
    private let wordSuggestionsKey = "wordSuggestionsEnabled"
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        centerLinesEnabled = userDefaults.bool(forKey: centerLinesKey)
        iCloudSyncEnabled = userDefaults.bool(forKey: iCloudSyncKey)
        // Default to false for word suggestions if not set
        if userDefaults.object(forKey: wordSuggestionsKey) == nil {
            wordSuggestionsEnabled = false
            saveSetting(false, forKey: wordSuggestionsKey)
        } else {
            wordSuggestionsEnabled = userDefaults.bool(forKey: wordSuggestionsKey)
        }
    }
    
    func saveSetting<T>(_ value: T, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func updateCenterLines(_ enabled: Bool) {
        centerLinesEnabled = enabled
        saveSetting(enabled, forKey: centerLinesKey)
    }
    
    func updateiCloudSync(_ enabled: Bool) {
        iCloudSyncEnabled = enabled
        saveSetting(enabled, forKey: iCloudSyncKey)
    }
    
    func updateWordSuggestions(_ enabled: Bool) {
        wordSuggestionsEnabled = enabled
        saveSetting(enabled, forKey: wordSuggestionsKey)
    }
} 