import Foundation

struct DialogueLine: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
} 