import UIKit

enum AmountKeyboard {
    /// The iPad decimal popover blocks actions outside itself; use its docked numeric layout.
    @MainActor static var type: UIKeyboardType {
        UIDevice.current.userInterfaceIdiom == .pad ? .numbersAndPunctuation : .decimalPad
    }
}
