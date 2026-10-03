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
            CheckLineIcon(symbol: showsClose ? "xmark" : "plus", size: PaperTheme.Dock.icon)
                .font(.system(size: PaperTheme.Dock.icon, weight: .semibold))
                .foregroundStyle(PaperTheme.ink)
                .contentTransition(reduceMotion ? .identity : .opacity)
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
