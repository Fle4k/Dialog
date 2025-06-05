import SwiftUI
import UIKit

// MARK: - Undo Confirmation View
struct UndoConfirmationView: View {
    let actionDescription: String
    let onUndo: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Undo")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(actionDescription)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button("UNDO") {
                    onUndo()
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.primary)
        .cornerRadius(12)
        .shadow(radius: 8)
        .onTapGesture {
            onDismiss()
        }
        .onAppear {
            // Add haptic feedback when showing undo option
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
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
                        // Auto-dismiss after 4 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
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