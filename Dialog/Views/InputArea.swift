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
                .fixedSize()
                
                Button(speakerBName) {
                    currentSpeaker = speakerBName
                }
                .buttonStyle(.bordered)
                .tint(currentSpeaker == speakerBName ? .blue : .gray)
                .fixedSize()
            }
            
            TextEditor(text: $currentText)
                .frame(minHeight: 44, maxHeight: 120)
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .focused($isTextFieldFocused)
            
            Button("Add Dialogue") {
                onAdd()
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentText.isEmpty)
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }
} 