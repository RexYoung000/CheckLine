import SwiftData
import SwiftUI

struct CheckLineRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workspace: CheckLineWorkspace?

    var body: some View {
        Group {
            if let workspace, workspace.storageLoadFailed == false {
                CheckLineShellView(workspace: workspace)
            } else if workspace?.storageLoadFailed == true {
                StorageUnavailableView()
            } else {
                ProgressView()
                    .tint(PaperTheme.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PaperTheme.canvas.ignoresSafeArea())
                    .onAppear {
                        workspace = CheckLineWorkspace(context: modelContext)
                    }
            }
        }
    }
}
