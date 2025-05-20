import Foundation
import UIKit

struct RTFExportService {
    static func generateRTF(dialogue: [DialogueLine]) -> Data {
        let attributedString = NSMutableAttributedString()
        
        for line in dialogue {
            // Add speaker name in bold and centered
            let speakerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let speakerString = NSAttributedString(
                string: line.speaker + "\n",
                attributes: speakerAttributes
            )
            attributedString.append(speakerString)
            
            // Add dialogue text in regular font and centered
            let dialogueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let dialogueString = NSAttributedString(
                string: line.text + "\n\n",
                attributes: dialogueAttributes
            )
            attributedString.append(dialogueString)
        }
        
        return try! attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
    
    static func exportToRTF(dialogue: [DialogueLine], sceneTitle: String) throws -> URL {
        let rtfData = generateRTF(dialogue: dialogue)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sceneTitle).rtf")
        try rtfData.write(to: url)
        return url
    }
} 