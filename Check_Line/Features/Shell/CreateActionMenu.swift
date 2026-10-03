import SwiftUI

struct CreateActionMenu: View {
    var onCreateBudget: () -> Void
    var onRecord: () -> Void
    var onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
                .background(.ultraThinMaterial)
                .opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityLabel(String(localized: "v1.shell.close"))

            VStack(alignment: .trailing, spacing: 10) {
                menuButton(String(localized: "v1.budget.create"), systemImage: "wallet.pass") {
                    onCreateBudget()
                }
                menuButton(String(localized: "v1.agent.collapsed"), systemImage: "square.and.pencil") {
                    onRecord()
                }
            }
            .padding(.trailing, PaperTheme.Dock.horizontalPadding)
            .padding(.bottom, PaperTheme.Dock.menuBottom)
            .modifier(PaperPlusSafeAreaPad())
            .frame(maxWidth: PaperTheme.Dock.maxWidth, alignment: .trailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .bottomTrailing)))
    }

    private func menuButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CheckLineIcon(symbol: systemImage)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(PaperTheme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: PaperTheme.Layout.minTap)
            .background(PaperTheme.card, in: Capsule())
            .shadow(color: PaperTheme.shadow, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PaperChipPressStyle())
        .accessibilityLabel(title)
    }
}
