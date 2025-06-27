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
    @StateObject private var mainMenuViewModel = MainMenuViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .environmentObject(localizationManager)
                .environmentObject(mainMenuViewModel)
                .overlay(
                    // Add smooth transition overlay for language changes
                    Group {
                        if localizationManager.isLanguageChanging {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.3), value: localizationManager.isLanguageChanging)
                        }
                    }
                )
                .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                    // Handle language change notification for any necessary updates
                    // UI will update automatically through @Published properties
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Save any current dialog state when app goes to background
                    saveCurrentDialogState()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Save any current dialog state when app is terminated
                    saveCurrentDialogState()
                }
        }
    }
    
    private func saveCurrentDialogState() {
        // Check if there's a current dialog session that needs saving
        // This will be implemented in conjunction with DialogSceneView state management
        UserDefaults.standard.synchronize() // Force immediate save to disk
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
