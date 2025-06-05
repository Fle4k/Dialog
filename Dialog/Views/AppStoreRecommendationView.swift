import SwiftUI

struct AppStoreRecommendationView: View {
    let appName: String
    let appDescription: String
    let appIconName: String // Your local asset or SF Symbol
    let appStoreURL: String
    
    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Image(systemName: appIconName)
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.blue)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // App Info
            VStack(alignment: .leading, spacing: 4) {
                Text(appName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(appDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Get Button
            Button("GET") {
                if let url = URL(string: appStoreURL) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(Capsule())
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Character Creator Specific Component
struct CharacterCreatorRecommendationView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Image("PersonIcon_Light_rounded")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // App Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Character Creator")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Curated, authentic German & British names.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Get Button
            Button("GET") {
                if let url = URL(string: "https://apps.apple.com/de/app/character-creator/id6744124123?l=en-GB") {
                    openURL(url)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.blue)
            .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

#Preview("Character Creator Card") {
    CharacterCreatorRecommendationView()
        .padding()
} 
