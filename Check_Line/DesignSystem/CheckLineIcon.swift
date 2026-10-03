import SwiftUI

/// Display aliases keep existing persisted wish symbols and domain projections unchanged.
struct CheckLineIcon: View {
    var symbol: String
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let asset = CheckLineIconAssets.names[symbol] {
                Image(asset).renderingMode(.template).resizable().scaledToFit()
            } else {
                Image(systemName: symbol).font(.system(size: size))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CheckLineIconLabel: View {
    var title: String
    var symbol: String
    var size: CGFloat

    init(_ title: String, symbol: String, size: CGFloat = 20) {
        self.title = title
        self.symbol = symbol
        self.size = size
    }

    var body: some View {
        Label { Text(title) } icon: { CheckLineIcon(symbol: symbol, size: size) }
    }
}

// Keep a native Text/Image label so menus and toolbars can extract the command.
extension Button where Label == SwiftUI.Label<Text, Image> {
    init(_ title: String, iconSymbol: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) {
            SwiftUI.Label { Text(title) } icon: {
                Image(uiImage: CheckLineIconAssets.templateImage(for: iconSymbol))
                    .renderingMode(.template)
            }
        }
    }
}
