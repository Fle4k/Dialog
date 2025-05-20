import Foundation

enum FDXExportError: Error {
    case exportFailed
}

struct FDXExportService {
    static func generateFDX(dialogue: [DialogueLine]) -> String {
        let header = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="Screenplay" Version="1">
            <Content>
        """
        
        let footer = """
            </Content>
        </FinalDraft>
        """
        
        let content = dialogue.map { line in
            """
                <Paragraph Type="Character"><Text>\(line.speaker.uppercased())</Text></Paragraph>
                <Paragraph Type="Dialogue"><Text>\(line.text)</Text></Paragraph>
            """
        }.joined(separator: "\n")
        
        return header + "\n" + content + "\n" + footer
    }
    
    static func exportToFDX(dialogue: [DialogueLine], sceneTitle: String) throws -> URL {
        let fdxContent = generateFDX(dialogue: dialogue)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sceneTitle).fdx")
        try fdxContent.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
} 