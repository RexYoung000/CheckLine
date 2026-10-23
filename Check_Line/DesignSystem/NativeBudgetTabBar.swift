import SwiftUI
import UIKit

/// A real system tab bar, hosted at the dock's compact size. UIKit owns its
/// selection lens and touch tracking; SwiftUI only receives the selected page.
struct NativeBudgetTabBar: UIViewRepresentable {
    var selected: CheckLineAppTab
    var onSelect: (CheckLineAppTab) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIView(context: Context) -> UITabBar {
        let bar = UITabBar()
        bar.delegate = context.coordinator
        // This embedded bar has a phone-sized available width on iPad too.
        // Scope the compact trait to this control, not the page or the device.
        bar.traitOverrides.horizontalSizeClass = .compact
        bar.itemPositioning = .centered
        bar.itemWidth = 56
        bar.itemSpacing = 2
        bar.tintColor = UIColor(PaperTheme.accent)
        bar.unselectedItemTintColor = UIColor(PaperTheme.ink)
        bar.accessibilityIdentifier = "wallet.nativeTabBar"
        bar.items = [CheckLineAppTab.budgets, .wishes].enumerated().map { index, tab in
            let image = CheckLineIconAssets.templateImage(for: tab.systemImage).withRenderingMode(.alwaysTemplate)
            let item = UITabBarItem(title: nil, image: image, tag: index)
            item.accessibilityLabel = tab.title
            item.accessibilityIdentifier = "wallet.tab.\(tab.rawValue)"
            return item
        }
        bar.selectedItem = bar.items?[selected == .wishes ? 1 : 0]
        return bar
    }

    func updateUIView(_ bar: UITabBar, context: Context) {
        context.coordinator.onSelect = onSelect
        let index = selected == .wishes ? 1 : 0
        if bar.selectedItem?.tag != index { bar.selectedItem = bar.items?[index] }
    }

    final class Coordinator: NSObject, UITabBarDelegate {
        var onSelect: (CheckLineAppTab) -> Void
        init(onSelect: @escaping (CheckLineAppTab) -> Void) { self.onSelect = onSelect }
        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            onSelect(item.tag == 1 ? .wishes : .budgets)
        }
    }
}
