import SwiftUI

struct RootCreateButton: View {
    var showsClose: Bool
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            PaperHaptics.light()
            action()
        } label: {
            Image(systemName: showsClose ? "xmark" : "plus")
                .font(.system(size: PaperTheme.Dock.icon, weight: .semibold))
                .foregroundStyle(PaperTheme.ink)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .frame(width: PaperTheme.Dock.control, height: PaperTheme.Dock.control)
                .contentShape(Circle())
                .paperGlass(.circle, interactive: true)
        }
        .buttonStyle(PaperCirclePressStyle())
        .frame(width: PaperTheme.Dock.control, height: PaperTheme.Dock.control)
        .accessibilityLabel(
            Text(showsClose ? String(localized: "v1.shell.close") : String(localized: "v1.shell.create"))
        )
        .accessibilityIdentifier("root.createAction")
    }
}
