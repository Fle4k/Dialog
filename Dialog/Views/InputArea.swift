import SwiftUI

struct InputArea: View {
    @Binding var currentText: String
    @Binding var currentSpeaker: String
    let speakerAName: String
    let speakerBName: String
    let onAdd: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(speakerAName) {
                    currentSpeaker = speakerAName
                }
                .buttonStyle(.bordered)
                .tint(currentSpeaker == speakerAName ? .blue : .gray)
                
                Button(speakerBName) {
                    currentSpeaker = speakerBName
                }
                .buttonStyle(.bordered)
                .tint(currentSpeaker == speakerBName ? .blue : .gray)
            }
            
            TextField("Enter dialogue...", text: $currentText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .focused($isTextFieldFocused)
            
            Button("Add Dialogue") {
                onAdd()
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentText.isEmpty)
        }
        .padding()
    }
} 