import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                settingsList
            }
            .navigationTitle("Settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(.primary)
    }
    
    // MARK: - Settings List
    private var settingsList: some View {
        List {
            // Language Section
            Section {
                languageRow
                wordSuggestionsRow
            } header: {
                Text("Language".localized)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Recommended Apps Section
            Section {
                CharacterCreatorRecommendationView()
            } header: {
                Text("Recommended App".localized)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
//            footer: {
//                Text("Apps that work great with this one".localized)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
            
            // Logo and Version Section
            Section {
                // Logo
                HStack {
                    Spacer()
                    Image("metame_Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 160)
                        .padding(.vertical, 8)
                        .onTapGesture {
                            if let url = URL(string: "https://www.metame.de") {
                                openURL(url)
                            }
                        }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                
                appVersionRow
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Language Row
    private var languageRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Language".localized)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Choose your preferred language".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                ForEach(localizationManager.supportedLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { language, displayName in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            localizationManager.setLanguage(language)
                        }
                    }) {
                        HStack {
                            Text(displayName)
                            if localizationManager.currentLanguage == language {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(localizationManager.supportedLanguages[localizationManager.currentLanguage] ?? "English")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Word Suggestions Row
    private var wordSuggestionsRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Predictive".localized)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Enable predictive text suggestions while typing".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { settingsManager.wordSuggestionsEnabled },
                set: { settingsManager.updateWordSuggestions($0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - App Version Row
    private var appVersionRow: some View {
        VStack(spacing: 2) {
            Text("Version".localized)
                .font(.caption)
                .fontWeight(.medium)
            
            Text("0.6.0 Beta")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Custom Toggle Style
struct DarkModeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? Color.black : Color(.systemGray4))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(2)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

// MARK: - Previews
#Preview {
    SettingsView()
}

#Preview("Dark Mode") {
    SettingsView()
        .preferredColorScheme(.dark)
} 
