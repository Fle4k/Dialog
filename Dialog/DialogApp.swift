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
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
        }
    }
}

// MARK: - Empty DialogSession
extension DialogSession {
    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.lastModified = Date()
        self.title = "New Dialog"
        self.textlines = []
        self.customSpeakerNames = [:]
        self.flaggedTextIds = []
    }
}
