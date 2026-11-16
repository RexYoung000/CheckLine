import Foundation

/// Saved settlement and its exact wallet impact for the current app session.
nonisolated struct SettlementOutcomeReceipt: Equatable, Sendable {
    let title: String
    let settlement: Settlement
    let periodStart: Date
    let periodEnd: Date?
    let walletCurrency: String
    let before: WalletProjection
    let after: WalletProjection

    var originalAmount: Decimal { settlement.baseSurplus }
    var originalCurrency: String { settlement.currencyCode }
    var recoveryBefore: Decimal { before.recoveryGap }
    var recoveryAfter: Decimal { after.recoveryGap }
    var net: Decimal { after.balance - before.balance }
}
