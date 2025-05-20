import SwiftUI

struct MainMenuView: View {
    @StateObject private var viewModel = DialogueScenesViewModel()
    @State private var showingNewSceneSheet = false
    @State private var newSceneTitle = ""
    @State private var navigationPath = NavigationPath()
    @State private var renamingScene: DialogueScene? = nil
    @State private var renameTitle: String = ""
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(viewModel.scenes) { scene in
                            NavigationLink(value: scene.id) {
                                VStack(alignment: .leading) {
                                    Text(scene.title)
                                        .font(.headline)
                                    Text("\(scene.dialogues.count) " + NSLocalizedString("Lines", comment: "Number of lines in a scene"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onLongPressGesture {
                                renamingScene = scene
                                renameTitle = scene.title
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteScene(viewModel.scenes[index])
                            }
                        }
                    }
                }
                
                Button(action: {
                    // Use localized default title
                    let defaultTitle = NSLocalizedString("untitled", comment: "Default scene title")
                    let scene = DialogueScene(title: defaultTitle)
                    viewModel.scenes.append(scene)
                    viewModel.updateScene(scene)
                    // Navigate to the new scene
                    navigationPath.append(scene.id)
                }) {
                    Label("Add Dialogue Scene", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 100)
            }
            .navigationTitle("Dialogue Scenes")
            .navigationDestination(for: UUID.self) { sceneID in
                if let scene = viewModel.scenes.first(where: { $0.id == sceneID }) {
                    DialogueSceneView(
                        scene: scene,
                        onSceneUpdate: { updatedScene in
                            viewModel.updateScene(updatedScene)
                        }
                    )
                }
            }
            .alert("Rename Scene", isPresented: Binding<Bool>(
                get: { renamingScene != nil },
                set: { if !$0 { renamingScene = nil } }
            ), actions: {
                TextField("New title", text: $renameTitle)
                Button("Cancel", role: .cancel) { renamingScene = nil }
                Button("Save") {
                    if let scene = renamingScene, !renameTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        viewModel.renameScene(id: scene.id, newTitle: renameTitle)
                    }
                    renamingScene = nil
                }
            }, message: {
                Text("Enter a new name for the scene.")
            })
        }
    }
}

#Preview {
    MainMenuView()
} 
