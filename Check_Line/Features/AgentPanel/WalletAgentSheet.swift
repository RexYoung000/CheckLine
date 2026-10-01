import SwiftUI

struct WalletAgentSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    var body: some View { CreateComposerSheet(workspace: workspace) }
}
