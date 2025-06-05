import Foundation
import SwiftUI

// MARK: - Settings Manager
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var centerLinesEnabled: Bool = false
    @Published var iCloudSyncEnabled: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let centerLinesKey = "centerLinesEnabled"
    private let iCloudSyncKey = "iCloudSyncEnabled"
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        centerLinesEnabled = userDefaults.bool(forKey: centerLinesKey)
        iCloudSyncEnabled = userDefaults.bool(forKey: iCloudSyncKey)
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
} 