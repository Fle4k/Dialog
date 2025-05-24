import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
    let isSpeakerA: Bool
}

struct ContentView2: View {
    // Sample data for the dialog
    let messages: [Message] = [
        Message(speaker: "Speaker A", text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Commodo s", isSpeakerA: true),
        Message(speaker: "Speaker B", text: "A lacus vestibulum sed arcu!", isSpeakerA: false),
        Message(speaker: "Speaker A", text: "Eu non diam phasellus vestibulum lorem. Labore et dolore magna aliqua. Commodo", isSpeakerA: true)
    ]

    // State for the currently selected speaker (A or B)
    // For UI preview, let's assume A is selected by default.
    @State private var selectedSpeaker: String = "A"
    @FocusState private var isInputActive: Bool
    
    // Placeholder for the current text being typed
    @State private var inputText: String = "Id diam vel quam elementum. Praesent semper feugiat nibh sed. Neque vitae tempus quam pellentesque nec nam."

    var body: some View {
        VStack(spacing: 0) {
            // Dialog Area
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(messages) { message in
                        HStack {
                            if message.isSpeakerA {
                                VStack(alignment: .leading) {
                                    Text(message.speaker)
                                        .font(.headline)
                                        .fontWeight(.black)
                                    Text(message.text)
                                        .font(.body)
                                }
                                Spacer() // Pushes Speaker A's text to the left
                            } else {
                                Spacer() // Pushes Speaker B's text to the right
                                VStack(alignment: .trailing) {
                                    Text(message.speaker)
                                        .font(.headline)
                                        .fontWeight(.black)
                                    Text(message.text)
                                        .font(.body)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()
                .padding(.horizontal)

            // Speaker Selection Buttons & Current Text Area
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button(action: {
                        selectedSpeaker = "A"
                    }) {
                        Text("A")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedSpeaker == "A" ? Color.black : Color(UIColor.systemGray5))
                            .foregroundColor(selectedSpeaker == "A" ? Color.white : Color.black)
                            .cornerRadius(8, corners: [.topLeft, .bottomLeft])
                    }

                    Button(action: {
                        selectedSpeaker = "B"
                    }) {
                        Text("B")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedSpeaker == "B" ? Color.black : Color(UIColor.systemGray5))
                            .foregroundColor(selectedSpeaker == "B" ? Color.white : Color.black)
                            .cornerRadius(8, corners: [.topRight, .bottomRight])
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 8)

                Divider()
                    .padding(.horizontal)

                TextField("Enter text here...", text: $inputText)
                    .focused($isInputActive)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // This empty space simulates the keyboard area.
                // In a real app, this would be handled by keyboard avoidance techniques.
                // For this UI-only task, we'll ensure this section is at the bottom.
            }
            .background(Color(UIColor.systemGray6)) // Mimicking the keyboard/input area background
        }
        .edgesIgnoringSafeArea(.bottom) // Allow content to go to the very bottom, typically where keyboard would be.
        .onAppear {
            isInputActive = true
        }
    }
}

// Helper to apply corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#if DEBUG
struct ContentView2_Previews: PreviewProvider {
    static var previews: some View {
        ContentView2()
            .previewDisplayName("ContentView2 Light")
        ContentView2()
            .preferredColorScheme(.dark)
            .previewDisplayName("ContentView2 Dark")
    }
}
#endif 