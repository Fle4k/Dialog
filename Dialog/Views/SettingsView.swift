import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Language".localized)) {
                    ForEach(viewModel.languages, id: \.0) { language in
                        Button(action: {
                            viewModel.selectLanguage(language.0)
                        }) {
                            HStack {
                                Text(language.1)
                                Spacer()
                                if viewModel.selectedLanguage == language.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
} 