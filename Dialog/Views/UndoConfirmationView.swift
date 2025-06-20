import SwiftUI
import UIKit

// MARK: - Undo Confirmation View
struct UndoConfirmationView: View {
    let actionDescription: String
    let onUndo: () -> Void
    let onDismiss: () -> Void
    
    private var buttonText: String {
        return actionDescription == "Redo" ? "Redo" : "Undo"
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(buttonText) {
                onUndo()
            }
            .font(.system(.body, design: .default, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black)
            .cornerRadius(8)
            
            Spacer()
        }
        .padding(.horizontal)
        .onAppear {
            // Add haptic feedback when showing undo/redo option
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Undo Toast Modifier
struct UndoToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let actionDescription: String
    let onUndo: () -> Void
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    UndoConfirmationView(
                        actionDescription: actionDescription,
                        onUndo: {
                            onUndo()
                            isPresented = false
                        },
                        onDismiss: {
                            isPresented = false
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        // Auto-dismiss after 5 seconds for undo, 4 seconds for redo (faster for redo)
                        let dismissTime: Double = actionDescription == "Redo" ? 4.0 : 5.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + dismissTime) {
                            if isPresented {
                                isPresented = false
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
    }
}

extension View {
    func undoToast(
        isPresented: Binding<Bool>,
        actionDescription: String,
        onUndo: @escaping () -> Void
    ) -> some View {
        self.modifier(UndoToastModifier(
            isPresented: isPresented,
            actionDescription: actionDescription,
            onUndo: onUndo
        ))
    }
} 