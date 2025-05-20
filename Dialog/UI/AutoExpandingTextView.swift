import SwiftUI

struct AutoExpandingTextView: UIViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    @Binding var dynamicHeight: CGFloat
    let maxLines: Int
    var availableWidth: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.returnKeyType = .send
        textView.text = text
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textView.textContainer.widthTracksTextView = true
        context.coordinator.widthConstraint = textView.widthAnchor.constraint(equalToConstant: availableWidth)
        context.coordinator.widthConstraint?.isActive = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if let widthConstraint = context.coordinator.widthConstraint, widthConstraint.constant != availableWidth {
            widthConstraint.constant = availableWidth
        }
        let lineHeight = uiView.font?.lineHeight ?? 20
        let maxHeight = lineHeight * CGFloat(maxLines) + 16 // 16 for insets
        let size = uiView.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
        let newHeight = min(size.height, maxHeight)
        if dynamicHeight != newHeight {
            DispatchQueue.main.async {
                dynamicHeight = newHeight
            }
        }
        uiView.isScrollEnabled = size.height > maxHeight
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoExpandingTextView
        var widthConstraint: NSLayoutConstraint?
        init(_ parent: AutoExpandingTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            let lineHeight = textView.font?.lineHeight ?? 20
            let maxHeight = lineHeight * CGFloat(parent.maxLines) + 16
            let size = textView.sizeThatFits(CGSize(width: parent.availableWidth, height: .greatestFiniteMagnitude))
            let newHeight = min(size.height, maxHeight)
            if parent.dynamicHeight != newHeight {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = newHeight
                }
            }
            textView.isScrollEnabled = size.height > maxHeight
        }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText string: String) -> Bool {
            if string == "\n" {
                self.parent.onCommit()
                return false
            }
            return true
        }
    }
} 