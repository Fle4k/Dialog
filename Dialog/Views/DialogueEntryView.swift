import SwiftUI

struct DialogueEntryView: View {
    let entry: DialogueEntry
    let speakerAName: String
    let speakerBName: String
    
    var body: some View {
        let isB = entry.speaker == speakerBName
        VStack(alignment: isB ? .trailing : .leading, spacing: 4) {
            Text(entry.speaker)
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: isB ? .trailing : .leading)
            Text(entry.text)
                .font(.body)
                .multilineTextAlignment(isB ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: isB ? .trailing : .leading)
        }
        .padding(.horizontal)
    }
} 