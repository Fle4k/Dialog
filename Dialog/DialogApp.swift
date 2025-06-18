//
//  DialogApp.swift
//  Dialog
//
//  Created by Shahin on 16.05.25.
//

import SwiftUI

@main
struct DialogApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environmentObject(localizationManager)
                .id(localizationManager.currentLanguage) // This forces a complete refresh when language changes
        }
    }
}

// MARK: - Empty DialogSession
extension DialogSession {
    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.lastModified = Date()
        self.title = "New Dialog".localized
        self.textlines = []
        self.screenplayElements = []
        self.customSpeakerNames = [:]
        self.flaggedTextIds = []
    }
}
