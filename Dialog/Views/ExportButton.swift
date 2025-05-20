import SwiftUI

struct ExportButton: View {
    let dialogue: [DialogueLine]
    let sceneTitle: String
    
    var body: some View {
        ShareLink(
            item: try! FDXExportService.exportToFDX(dialogue: dialogue, sceneTitle: sceneTitle),
            preview: SharePreview("\(sceneTitle).fdx")
        ) {
            Label("Export to Final Draft", systemImage: "square.and.arrow.up")
        }
    }
}

#Preview {
    ExportButton(
        dialogue: [
            DialogueLine(speaker: "Alice", text: "Hello, how are you?"),
            DialogueLine(speaker: "Bob", text: "I'm doing great, thanks!")
        ],
        sceneTitle: "SampleScene"
    )
} 