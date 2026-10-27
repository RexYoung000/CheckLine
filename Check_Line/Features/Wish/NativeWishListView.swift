import SwiftUI
import PhotosUI

struct NativeWishListView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var agentDraftAvailable = false
    @State private var draftKind = "wishCreate"
    @State private var completed = DesignPreviewData.isEnabled && DesignPreviewData.screen == "collection"
    @State private var rows = false
    @State private var adding = false
    @State private var balance = false
    @State private var expanded: Wish?
    @State private var redeeming: Wish?
    @State private var pricing: Wish?
    @State private var quoting: Wish?
    @State private var lastExpandedWishID: UUID?
    @State private var didOpenPreview = false
    @State private var didSelectCompletedPreview = false
    @AccessibilityFocusState private var focusedWishID: UUID?
    private var completedCount: Int { workspace.ledger.wishes.values.filter { $0.state == .completed }.count }
    private var isListExposed: Bool {
        expanded == nil && redeeming == nil && pricing == nil && quoting == nil && !adding && !balance
            && !workspace.showAgent && !workspace.showComposer
            && (chrome?.selectedTab ?? .wishes) == .wishes
            && chrome?.isSettingsPresented != true && chrome?.isSourcesPresented != true
            && chrome?.isAttentionPresented != true && chrome?.isShowingDetail != true
    }
    private var previewStartsOnBack: Bool {
        #if DEBUG
        DesignPreviewData.isEnabled && DesignPreviewData.screen == "wish-expanded"
        #else
        false
        #endif
    }
    private var wishes: [Wish] {
        workspace.ledger.wishes.values.filter { $0.state == (completed ? .completed : .active) }
            .sorted { lhs, rhs in
                let a = lhs.completedAt ?? lhs.createdAt, b = rhs.completedAt ?? rhs.createdAt
                return a == b ? lhs.id.uuidString < rhs.id.uuidString : a > b
            }
    }

    var body: some View {
        WalletRootPage(tab: .wishes, title: String(localized: "wallet.wishes.title"), workspace: workspace, onAdd: { draftKind = "wishCreate"; adding = true }) {
            VStack(spacing: 17) {
                balanceBar
                if agentDraftAvailable {
                    Button(String(localized: "native.agent.resumeWish")) { draftKind = "agentWishCreate"; adding = true }
                        .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(14).walletSurface(radius: 18)
                }
                HStack(spacing: 10) {
                    Picker(String(localized: "wallet.wishes.title"), selection: $completed) {
                        Text(String(localized: "native.wish.unrealized")).tag(false)
                        Text(String(localized: "native.wish.realized")).tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("native.wish.tabs")
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { rows.toggle() }
                    } label: {
                        Image(systemName: rows ? "square.grid.2x2" : "list.bullet").font(.system(size: 18)).frame(width: 44, height: 44)
                            .background(PaperTheme.card.opacity(0.68), in: RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(.plain).foregroundStyle(PaperTheme.ink)
                        .accessibilityLabel(String(localized: "native.layout"))
                        .accessibilityValue(String(localized: rows ? "native.wish.rows" : "native.wish.cards"))
                        .accessibilityIdentifier("native.wish.layout")
                }
                if wishes.isEmpty { emptyState }
                wishGrid
            }.frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .blur(radius: expanded == nil || reduceTransparency ? 0 : 8)
        .allowsHitTesting(expanded == nil)
        .accessibilityHidden(expanded != nil)
        .sheet(isPresented: $adding, onDismiss: refreshWishDraft) { CreateWishSheet(workspace: workspace, draftKind: draftKind) }
        .sheet(isPresented: $balance, onDismiss: { chrome?.isShowingDetail = false }) { WishWalletSummaryView(workspace: workspace) }
        .sheet(item: $redeeming) { WishRedemptionView(workspace: workspace, wishID: $0.id).modifier(NativeDrawerStyle()) }
        .sheet(item: $pricing) { WishPriceSheet(workspace: workspace, wish: $0) }
        .sheet(item: $quoting) { WishReferenceQuoteView(workspace: workspace, wish: $0) }
        .fullScreenCover(item: $expanded, onDismiss: {
            chrome?.isShowingDetail = false
            focusedWishID = lastExpandedWishID
        }) { ExpandedWishView(workspace: workspace, wishID: $0.id, startFlipped: previewStartsOnBack).presentationBackground(.clear) }
        .onChange(of: expanded?.id) { _, value in if value != nil { chrome?.isShowingDetail = true } }
        .onChange(of: completedCount) { old, new in if new > old { completed = true } }
        .onAppear {
            refreshWishDraft()
            if chrome?.wishesShowCompleted == true { completed = true }
        }
        .task(id: chrome?.selectedTab) { await applyWishPreviewIfNeeded() }
        .onChange(of: chrome?.wishesShowCompleted) { _, value in if value == true { completed = true } }
    }

    private var balanceBar: some View {
        Button { balance = true } label: {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            layout {
                Text(String(localized: "v1.wish.balance")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(MoneyFormat.string(workspace.wallet.balance, currencyCode: workspace.ledger.walletSettings.walletCurrencyCode))
                        .font(.system(size: typeSize.isAccessibilitySize ? 27 : 25, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
                        .foregroundStyle(PaperTheme.ink)
                    if typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(PaperTheme.muted)
                }
            }
            .padding(.horizontal, 19).padding(.vertical, typeSize.isAccessibilitySize ? 15 : 0)
            .frame(maxWidth: .infinity, minHeight: 54)
            .walletSurface(radius: 20)
        }.buttonStyle(.plain).accessibilityIdentifier("native.wish.balance")
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: completed ? "checkmark.seal" : "heart").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(PaperTheme.accent)
            Text(String(localized: completed ? "native.wish.realizedEmpty" : "native.wish.empty")).font(.headline)
            if !completed {
                Button(String(localized: "wallet.wishes.add")) { adding = true }.buttonStyle(PaperSolidButtonStyle()).accessibilityIdentifier("wallet.wishes.empty.add")
            }
        }.padding(.vertical, 36)
    }

    @ViewBuilder private var wishGrid: some View {
        LazyVStack(spacing: 14) {
            if rows || typeSize.isAccessibilitySize {
                ForEach(wishes) { wish in card(wish, row: rows, wide: !rows) }
            } else {
                ForEach(Array(stride(from: 0, to: wishes.count, by: 2)), id: \.self) { index in
                    if index + 1 < wishes.count {
                        HStack(spacing: 14) {
                            card(wishes[index]).frame(maxWidth: .infinity)
                            card(wishes[index + 1]).frame(maxWidth: .infinity)
                        }
                    } else { card(wishes[index], wide: true) }
                }
            }
        }
    }
    private func card(_ wish: Wish, row: Bool = false, wide: Bool = false) -> some View {
        NativeWishCard(workspace: workspace, wish: wish, row: row, wide: wide,
                       isActive: isListExposed,
                       onExpand: { lastExpandedWishID = wish.id; focusedWishID = nil; expanded = wish }, onRedeem: { redeeming = wish }, onPrice: { pricing = wish }, onQuote: { quoting = wish })
            .accessibilityFocused($focusedWishID, equals: wish.id)
    }
    private func refreshWishDraft() { agentDraftAvailable = (try? workspace.draftStore.load(TaskDraft(kind: "agentWishCreate").key)) != nil }
    private func applyWishPreviewIfNeeded() async {
        #if DEBUG
        guard DesignPreviewData.isEnabled, chrome?.selectedTab == .wishes else { return }
        let collection = DesignPreviewData.screen == "collection"
        guard (collection && !didSelectCompletedPreview) || (previewStartsOnBack && !didOpenPreview && expanded == nil) else { return }
        // TabView may mount the wishes page while another tab still owns the
        // presentation context. Wait until its selected layout has been applied.
        await Task.yield()
        do { try await Task.sleep(for: .milliseconds(120)); try Task.checkCancellation() } catch { return }
        guard chrome?.selectedTab == .wishes else { return }
        if collection, !didSelectCompletedPreview {
            completed = true
            didSelectCompletedPreview = true
            return
        }
        guard previewStartsOnBack, !didOpenPreview, expanded == nil,
              let wish = workspace.ledger.wishes.values.first(where: { $0.symbolName == "headphones" && $0.state == .active }) else { return }
        didOpenPreview = true
        lastExpandedWishID = wish.id
        expanded = wish
        #endif
    }
}

/// A single continuous angle owns the front, back, drag and spring settling.
/// Child actions do not flip the card; the empty face is the flip target.
struct NativeWishCard: View {
    @Bindable var workspace: CheckLineWorkspace
    let wish: Wish
    var row = false
    var wide = false
    var expanded = false
    var expandedHeight: CGFloat?
    var isActive = true
    var startFlipped = false
    var onExpand: () -> Void
    var onRedeem: () -> Void
    var onPrice: () -> Void
    var onQuote: () -> Void = {}
    @State private var angle = 0.0
    @State private var targetAngle = 0.0
    @State private var turnTask: Task<Void, Never>?
    @State private var dragBase: Double?
    @State private var lastDragEnd = Date.distantPast
    @State private var tilt = CGSize.zero
    @State private var glare = UnitPoint(x: 0.25, y: 0.15)
    @State private var turning = false
    @State private var appliedInitialFace = false
    @State private var measuredActionsHeight: CGFloat = 0
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    private var cover: WishCover { workspace.wishCovers.cover(for: wish.id, fallback: wish.symbolName) }
    private var flipped: Bool { cos(angle * .pi / 180) < 0 }
    private var coverage: WishCoverage { workspace.wishCoverage(for: wish) }
    private var canRedeem: Bool { coverage.canRedeem }
    private var ratio: CGFloat? { coverage.progress.map { CGFloat(NSDecimalNumber(decimal: $0).doubleValue) } }
    private var role: WishMaterialRole { wish.state == .completed ? .collection : .unfulfilled }
    private var photoFill: Bool { cover.layout == .fill && cover.imageData != nil }
    private var showsQuoteControl: Bool {
        wish.state == .active && (wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode) != workspace.ledger.walletSettings.walletCurrencyCode
    }
    private var backSpacing: CGFloat { expanded ? 18 : 8 }
    private var backPadding: CGFloat { expanded ? 24 : 14 }
    private var minimumActionsHeight: CGFloat {
        let extraCount = (coverage.state == .unpriced ? 1 : 0) + (showsQuoteControl ? 1 : 0)
        return (expanded ? 50 : 44) + CGFloat(extraCount) * (44 + backSpacing)
    }
    private var actionsHeight: CGFloat { max(minimumActionsHeight, measuredActionsHeight) }
    private var actionExclusionHeight: CGFloat { actionsHeight + backPadding + backSpacing }
    private func pose(back: Bool = false) -> CGSize {
        guard !reduceMotion else { return .zero }
        return CGSize(width: tilt.width + angle - (back ? 180 : 0), height: tilt.height)
    }
    private var height: CGFloat {
        let base: CGFloat
        if expanded { base = max(typeSize.isAccessibilitySize ? 420 : 354, expandedHeight ?? 0) }
        else if typeSize.isAccessibilitySize { base = row ? 210 : 270 }
        else { base = row ? 118 : wide ? 158 : 198 }
        guard !row, wish.state == .active else { return base }
        let readoutHeight: CGFloat = expanded ? 80 : 44
        return max(base, actionsHeight + readoutHeight + backPadding * 2 + backSpacing * 3)
    }
    private var displayedPrice: (amount: Decimal, currencyCode: String)? {
        if wish.state == .completed,
           let redemption = workspace.ledger.redemptions.values.first(where: { $0.wishID == wish.id && $0.state == .completed }) {
            return (redemption.actualAmount, redemption.currencyCode)
        }
        guard let amount = wish.targetAmount else { return nil }
        return (amount, wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode)
    }

    var body: some View {
        Group {
            if row {
                Button(action: onExpand) { collectionRow }.buttonStyle(.plain)
                    .accessibilityLabel(wish.name)
                    .accessibilityValue(rowAccessibilityValue)
                    .accessibilityIdentifier("native.wish.card.\(wish.id)")
            } else { turningCard }
        }
    }

    private var rowAccessibilityValue: String {
        var parts = [String(localized: wish.state == .completed ? "native.wish.realized" : "native.wish.unrealized")]
        if let price = displayedPrice { parts.append(MoneyFormat.string(price.amount, currencyCode: price.currencyCode)) }
        if wish.state != .completed {
            if let percent = coverage.displayPercent { parts.append((Double(percent) / 100).formatted(.percent.precision(.fractionLength(0)))) }
            else { parts.append(String(localized: coverage.state == .needsQuote ? "native.wish.noRate" : "native.wish.noPrice")) }
        }
        return parts.joined(separator: " ")
    }

    private var turningCard: some View {
        GeometryReader { proxy in
            ZStack {
                // A settled face owns a flat native hit plane. Keeping the back
                // inside two 180-degree 3D transforms can inverse-map a button
                // tap onto the transparent flip target on iPhone and iPad.
                if reduceMotion || (!turning && dragBase == nil) {
                    if flipped { back } else { front }
                } else {
                    front.modifier(WishFlipFace(angle: angle, back: false))
                        .allowsHitTesting(false).accessibilityHidden(true)
                    back.modifier(WishFlipFace(angle: angle, back: true))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.height)), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.width)), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .scaleEffect(dragBase == nil || reduceMotion ? 1 : 1.025)
            .shadow(color: PaperTheme.accent.opacity(dragBase == nil ? 0.08 : 0.18), radius: dragBase == nil ? 10 : 18,
                    x: -tilt.width * 0.7, y: 6 + abs(tilt.height) * 0.5)
            .simultaneousGesture(flipGesture(width: proxy.size.width))
            .onContinuousHover { phase in
                guard isActive, !reduceMotion, dragBase == nil, !flipped else { return }
                switch phase {
                case .active(let point):
                    glare = UnitPoint(x: point.x / max(1, proxy.size.width), y: point.y / max(1, proxy.size.height))
                    tilt = CGSize(width: (glare.x - 0.5) * 10, height: (0.5 - glare.y) * 10)
                case .ended: withAnimation(.easeOut(duration: 0.2)) { tilt = .zero }
                }
            }
        }
        .frame(height: height)
        .contentShape(RoundedRectangle(cornerRadius: 25))
        .overlay(alignment: .topTrailing) {
            if !expanded {
                Button(action: onExpand) {
                    CheckLineIcon(symbol: "arrow.up.left.and.arrow.down.right", size: 14)
                        .frame(width: 44, height: 44)
                        .background(cover.layout == .fill && cover.imageData != nil && !flipped ? .black.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 15))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).frame(width: 44, height: 44).contentShape(Rectangle()).padding(3)
                    .foregroundStyle(cover.layout == .fill && cover.imageData != nil && !flipped ? .white : PaperTheme.accent)
                    .accessibilityLabel(String(localized: "native.wish.expand")).accessibilityIdentifier("native.wish.expand")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(wish.name)
        .accessibilityValue(String(localized: flipped ? "native.wish.back" : "native.wish.front"))
        .accessibilityAction(named: String(localized: "native.wish.flip")) { flip() }
        .accessibilityIdentifier("native.wish.card.\(wish.id)")
        .onAppear {
            guard !appliedInitialFace else { return }
            appliedInitialFace = true
            if startFlipped { angle = 180; targetAngle = 180 }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { turnTask?.cancel(); turning = false; dragBase = nil; tilt = .zero; angle = targetAngle }
        }
        .onChange(of: reduceMotion) { _, _ in turnTask?.cancel(); turning = false; dragBase = nil; tilt = .zero; angle = targetAngle }
        .onChange(of: isActive) { _, value in if !value { turnTask?.cancel(); turning = false; dragBase = nil; tilt = .zero; angle = targetAngle } }
        .onDisappear { turnTask?.cancel(); turning = false; dragBase = nil; tilt = .zero; angle = targetAngle }
        .onPreferenceChange(WishActionHeightPreference.self) { value in
            if abs(value - measuredActionsHeight) > 0.5 { measuredActionsHeight = value }
        }
    }

    private var collectionRow: some View {
        ZStack {
            WishCardBackdrop(role: role, radius: 23, photoFill: photoFill)
            if role == .unfulfilled, let ratio {
                NativeLiquidSurface(progress: ratio, horizontal: true, active: isActive, horizontalAmount: 1).opacity(0.38)
            }
            if photoFill {
                WishCoverArtwork(cover: cover, row: true, materialRole: role)
            }
            HStack(spacing: 12) {
                if !photoFill {
                    WishCoverArtwork(cover: cover, materialRole: role).frame(width: 64, height: 76)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(wish.name).font(.headline).lineLimit(2)
                    if let price = displayedPrice {
                        Text(MoneyFormat.string(price.amount, currencyCode: price.currencyCode)).font(.title3.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    } else { Text(String(localized: "native.wish.noPrice")).font(.caption) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 14)).frame(width: 30, height: 44)
            }.padding(.horizontal, 15).padding(.vertical, 13)
            if role == .unfulfilled && !photoFill { WishGlassPane(radius: 23) }
        }
        .foregroundStyle(photoFill ? .white : WishMaterialPalette.ink)
        .frame(height: height).clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    private var front: some View {
        ZStack(alignment: .topLeading) {
            WishCoverArtwork(cover: cover, row: row || wide, large: expanded, materialRole: role)
            if role == .unfulfilled && !photoFill { WishGlassPane(radius: expanded ? 32 : 25, glare: glare) }
            VStack(alignment: .leading, spacing: 8) {
                Text(wish.name).font(expanded ? .title2.weight(.semibold) : row || wide ? .headline : .system(size: 14, weight: .semibold))
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, expanded ? 0 : 23)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline) {
                    if let price = displayedPrice {
                        Text(MoneyFormat.string(price.amount, currencyCode: price.currencyCode))
                            .font(.system(size: expanded ? 36 : row ? 24 : 23, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
                    }
                    Spacer(minLength: 2)
                    if wish.state == .completed {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(PaperTheme.accent)
                            .accessibilityLabel(String(localized: "wallet.wishes.completed"))
                    }
                }
            }.padding(expanded ? 26 : 16).allowsHitTesting(false)
            Color.clear.contentShape(Rectangle()).onTapGesture { flip() }
        }
        .background(WishCardBackdrop(role: role, radius: expanded ? 32 : 25, pose: pose(), glare: glare, photoFill: photoFill))
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 32 : 25, style: .continuous))
        .foregroundStyle(photoFill ? .white : WishMaterialPalette.ink)
        .accessibilityHidden(flipped)
    }

    private var back: some View {
        ZStack {
            if wish.state != .completed {
                NativeLiquidSurface(progress: ratio ?? 0, horizontal: row, active: flipped && isActive && ratio != nil, horizontalAmount: row ? 1 : 0)
                    .opacity(0.42)
                WishGlassPane(radius: expanded ? 32 : 25, glare: glare)
            }
            VStack(spacing: 0) {
                Color.clear.contentShape(Rectangle())
                    .frame(height: wish.state == .completed ? height : max(0, height - actionExclusionHeight))
                    .onTapGesture { flip() }
                Spacer(minLength: 0)
            }
            if wish.state == .completed { achievedBack }
            else { standingBack }
        }
        .background(WishCardBackdrop(role: role, radius: expanded ? 32 : 25, pose: pose(back: true), glare: glare))
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 32 : 25, style: .continuous))
        .foregroundStyle(WishMaterialPalette.ink)
        .accessibilityHidden(!flipped)
    }

    private var standingBack: some View {
        VStack(spacing: backSpacing) {
            Spacer(minLength: 0)
            progressReadout.font(.system(size: expanded ? 65 : wide ? 42 : 36, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading).allowsHitTesting(false)
            Spacer(minLength: 0)
            actionControls
        }.padding(backPadding)
    }

    private var actionControls: some View {
        VStack(spacing: backSpacing) {
            redeemButton
            if coverage.state == .unpriced { priceButton }
            if showsQuoteControl { quoteButton }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: WishActionHeightPreference.self, value: proxy.size.height)
            }.allowsHitTesting(false)
        }
    }

    @ViewBuilder private var progressReadout: some View {
        if let percent = coverage.displayPercent {
            Text(Double(percent) / 100, format: .percent.precision(.fractionLength(0))).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        } else {
            Text(String(localized: coverage.state == .needsQuote ? "native.wish.noRate" : "native.wish.noPrice"))
                .font(expanded ? .title3 : .subheadline).foregroundStyle(WishMaterialPalette.meta).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var redeemButton: some View {
        Button(String(localized: "native.wish.redeem")) { if isActive && canRedeem && !turning && dragBase == nil { onRedeem() } }
            .font(.system(size: expanded ? 16 : 13, weight: .semibold))
            .foregroundStyle(canRedeem ? PaperTheme.primaryInk : PaperTheme.muted).frame(maxWidth: .infinity, minHeight: expanded ? 50 : 44)
            .background(canRedeem ? PaperTheme.primary : PaperTheme.card, in: RoundedRectangle(cornerRadius: expanded ? 18 : 14))
            .overlay { if canRedeem { WishRedeemEdgeGlow(radius: expanded ? 18 : 14,active: flipped && !turning && isActive) } }
            .buttonStyle(.plain).disabled(!isActive || !canRedeem || turning || dragBase != nil)
            .accessibilityHint(String(localized: canRedeem ? "wallet.wishes.redemption" : coverage.state == .needsQuote ? "native.wish.noRate" : coverage.state == .unpriced ? "native.wish.noPrice" : "native.wish.coverageRequired"))
            .accessibilityIdentifier("native.wish.redeem")
    }
    private var priceButton: some View {
        Button(String(localized: "native.wish.setPrice"), action: onPrice)
            .font(.caption).foregroundStyle(PaperTheme.accent).frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.plain).disabled(!isActive || turning || dragBase != nil).accessibilityIdentifier("native.wish.fillPrice")
    }
    private var quoteButton: some View {
        Button(String(localized: "native.wish.checkRate"), action: onQuote)
            .font(.caption).foregroundStyle(PaperTheme.accent).frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.plain).disabled(!isActive || turning || dragBase != nil).accessibilityIdentifier("native.wish.checkRate")
    }
    private var achievedBack: some View {
        VStack(alignment: .leading, spacing: row ? 6 : 14) {
            Text(String(localized: "native.wish.realized")).font(.caption).foregroundStyle(PaperTheme.accent)
            if let price = displayedPrice {
                Text(MoneyFormat.string(price.amount, currencyCode: price.currencyCode))
                    .font(.system(size: expanded ? 37 : 26, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            }
            if let date = wish.completedAt { Text(date, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(WishMaterialPalette.meta) }
            if let redemption = workspace.ledger.redemptions.values.first(where: { $0.wishID == wish.id && $0.state == .completed }),
               let entry = workspace.ledger.walletEntries[redemption.walletEntryID] {
                Text(String(localized: "wallet.exchange.walletChange") + " " + MoneyFormat.string(entry.walletSignedAmount, currencyCode: entry.walletCurrencyCode))
                    .font(expanded ? .subheadline : .caption2).foregroundStyle(WishMaterialPalette.meta)
                if expanded, entry.conversion.kind != .identity { WalletConversionDetails(entry: entry) }
            }
        }.padding(expanded ? 26 : 17).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).allowsHitTesting(false)
    }

    private func flipGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard isActive, !reduceMotion else { return }
                // The lower action strip is excluded from the flip recognizer.
                if dragBase == nil {
                    guard !flipped || wish.state == .completed || value.startLocation.y < height - actionExclusionHeight else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.1 else { return }
                    turnTask?.cancel()
                    dragBase = angle
                    turning = true
                }
                angle = (dragBase ?? angle) + Double(value.translation.width / max(1, width)) * 180
                tilt = CGSize(width: 0, height: min(3, max(-3, -value.translation.height / 16)))
                glare = UnitPoint(x: min(1, max(0, 0.5 + value.translation.width / max(1, width))), y: 0.3)
            }
            .onEnded { value in
                guard dragBase != nil else { return }
                dragBase = nil; lastDragEnd = Date()
                let projected = Double((value.predictedEndTranslation.width - value.translation.width) / max(1, width)) * 180
                let nearest = (angle / 180).rounded() * 180
                let target = min(nearest + 180, max(nearest - 180, ((angle + projected * 0.55) / 180).rounded() * 180))
                settle(target, velocity: projected * 2.4)
            }
    }
    private func flip() {
        guard isActive, Date().timeIntervalSince(lastDragEnd) > 0.25 else { return }
        let base = (targetAngle / 180).rounded() * 180
        settle(cos(base * .pi / 180) < 0 ? base - 180 : base + 180)
    }
    private func settle(_ target: Double, velocity: Double = 0) {
        turnTask?.cancel()
        targetAngle = target
        turning = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { tilt = .zero }
        if reduceMotion { withAnimation(.easeOut(duration: 0.1)) { angle = target }; turning = false }
        else {
            // Integrating the visible angle makes a running flip interruptible at
            // the actual finger-down angle, rather than the previous target.
            turnTask = Task { @MainActor in
                var speed = min(1400, max(-1400, velocity))
                for _ in 0..<150 {
                    guard !Task.isCancelled else { return }
                    let dt = 1.0 / 60
                    speed += (175 * (target - angle) - 23 * speed) * dt
                    angle += speed * dt
                    if abs(target - angle) < 0.025 && abs(speed) < 0.06 { break }
                    do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                angle = target
                turning = false
            }
        }
        PaperHaptics.selection()
    }
}

private struct WishActionHeightPreference: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct WishFlipFace: AnimatableModifier {
    var angle: Double
    var back: Bool
    var animatableData: Double { get { angle } set { angle = newValue } }
    func body(content: Content) -> some View {
        let rearVisible = cos(angle * .pi / 180) < 0
        return content.rotation3DEffect(.degrees(back ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .opacity(rearVisible == back ? 1 : 0)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
            .allowsHitTesting(rearVisible == back)
    }
}

private struct WishRedeemEdgeGlow: View {
    var radius: CGFloat
    var active = true
    @State private var visible = false
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || !visible || !active || scenePhase != .active)) { clock in
            let phase = reduceMotion ? 0 : clock.date.timeIntervalSinceReferenceDate / 3.2 * 360
            RoundedRectangle(cornerRadius: radius).strokeBorder(AngularGradient(colors: [.white.opacity(0.1), .white.opacity(0.13), Color(red: 0.78, green: 0.93, blue: 1), .white.opacity(0.95), .white.opacity(0.12), .white.opacity(0.08)], center: .center, angle: .degrees(phase)), lineWidth: 1.5)
                .shadow(color: PaperTheme.accent.opacity(0.28), radius: 4)
        }.allowsHitTesting(false).accessibilityHidden(true).onAppear { visible = true }.onDisappear { visible = false }
    }
}

struct WishCoverArtwork: View {
    var cover: WishCover
    var row = false
    var large = false
    var turn = 0.0
    var artworkOpacity = 1.0
    var materialRole: WishMaterialRole = .unfulfilled
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { proxy in
            if cover.layout != .none {
                if cover.imageData != nil, cover.layout != .symbol, let image {
                    if cover.layout == .fill {
                        let scale = max(proxy.size.width / max(1, image.size.width), proxy.size.height / max(1, image.size.height))
                        let width = image.size.width * scale, height = image.size.height * scale
                        Image(uiImage: image).resizable().frame(width: width, height: height)
                            .position(x: proxy.size.width / 2 + (0.5 - cover.focusX) * (width - proxy.size.width),
                                      y: proxy.size.height / 2 + (0.5 - cover.focusY) * (height - proxy.size.height))
                            .overlay(LinearGradient(colors: [.black.opacity(0.37), .clear, .black.opacity(0.42)], startPoint: .top, endPoint: .bottom))
                            .opacity(artworkOpacity)
                    } else {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: artSize(proxy.size) * 1.2, height: artSize(proxy.size) * 1.12)
                            .clipShape(RoundedRectangle(cornerRadius: large ? 24 : 17))
                            .overlay(RoundedRectangle(cornerRadius: large ? 24 : 17).strokeBorder(.white.opacity(0.65), lineWidth: 1))
                            .rotationEffect(.degrees(-7)).shadow(color: .black.opacity(0.1), radius: 12, y: 7)
                            .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.5).opacity(artworkOpacity)
                            .position(artCenter(proxy.size))
                    }
                } else if cover.layout == .symbol {
                    let size = artSize(proxy.size)
                    CheckLineIcon(symbol: cover.symbol, size: size * 0.68)
                        .foregroundStyle(materialRole == .collection ? WishMaterialPalette.ink : Color.paper(light: 0x176A91, dark: 0xF2F3F5))
                        .frame(width: size, height: size)
                        .background(LinearGradient(colors: [WishMaterialPalette.mount, WishMaterialPalette.mount.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: size * 0.26))
                        .overlay(RoundedRectangle(cornerRadius: size * 0.26).strokeBorder(LinearGradient(colors: [WishMaterialPalette.edge.opacity(0.65), .black.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
                        .rotationEffect(.degrees(-8)).shadow(color: .black.opacity(0.16), radius: 6, x: 2, y: 4)
                        .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.5).opacity(artworkOpacity)
                        .position(artCenter(proxy.size))
                }
            }
        }.clipped().allowsHitTesting(false).accessibilityHidden(true)
            .onChange(of: cover.imageData, initial: true) { _, data in image = data.flatMap { UIImage(data: $0) } }
    }
    private func artSize(_ size: CGSize) -> CGFloat {
        if large { return min(132, size.width * 0.38) }
        return row ? min(88, size.height * 0.57) : min(82, size.width * 0.43)
    }
    private func artCenter(_ size: CGSize) -> CGPoint { CGPoint(x: size.width * (row ? 0.77 : 0.53), y: size.height * (row ? 0.52 : 0.53)) }
}

struct ExpandedWishView: View {
    @Bindable var workspace: CheckLineWorkspace
    let wishID: UUID
    var startFlipped = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var redeem = false
    @State private var price = false
    @State private var coverEditor = false
    @State private var quote = false
    var body: some View {
        ZStack {
            WishFocusScrim(onTap: { dismiss() })
            GeometryReader { proxy in
                if let wish = workspace.ledger.wishes[wishID] {
                    let spacious = proxy.size.width > 600
                    NativeWishCard(workspace: workspace, wish: wish, expanded: true,
                                   expandedHeight: spacious ? min(540, max(354, proxy.size.height - 44)) : nil,
                                   isActive: !redeem && !price && !coverEditor && !quote,
                                   startFlipped: startFlipped,
                                   onExpand: {}, onRedeem: { redeem = true }, onPrice: { price = true }, onQuote: { quote = true })
                        .frame(width: min(spacious ? 640 : 368, max(0, proxy.size.width - 44)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .sheet(isPresented: $redeem, onDismiss: {
                            if workspace.ledger.wishes[wishID]?.state == .completed { dismiss() }
                        }) { WishRedemptionView(workspace: workspace, wishID: wishID).modifier(NativeDrawerStyle()) }
                        .sheet(isPresented: $price) { WishPriceSheet(workspace: workspace, wish: wish) }
                        .sheet(isPresented: $quote) { WishReferenceQuoteView(workspace: workspace, wish: wish) }
                }
            }
        }
        .sheet(isPresented: $coverEditor) { WishCoverPicker(store: workspace.wishCovers, wishID: wishID, name: workspace.ledger.wishes[wishID]?.name ?? "") }
        .safeAreaInset(edge: .top) {
            HStack {
                Button { coverEditor = true } label: { Image(systemName: "photo").frame(width: 44, height: 44).background(PaperTheme.card.opacity(reduceTransparency ? 1 : 0.88), in: Circle()) }
                    .accessibilityLabel(String(localized: "native.cover.title")).accessibilityIdentifier("native.wish.cover.edit")
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44).background(PaperTheme.card.opacity(reduceTransparency ? 1 : 0.88), in: Circle()) }
                    .accessibilityLabel(String(localized: "action.close"))
            }.foregroundStyle(PaperTheme.ink).padding(.horizontal, 22).padding(.vertical, 10)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "wallet.wishes.title"))
        .accessibilityIdentifier("native.wish.expanded")
        .accessibilityAction(.escape) { dismiss() }
    }
}

struct WishPriceSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    let wish: Wish
    @State private var amount = ""
    @State private var currency = "CNY"
    @State private var failed = false
    @FocusState private var amountFocused: Bool
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text(wish.name).font(.title2.weight(.semibold))
                    Text(String(localized: "native.wish.setPrice")).font(.subheadline).foregroundStyle(PaperTheme.muted)
                    HStack(spacing: 10) {
                        TextField("0", text: $amount).keyboardType(AmountKeyboard.type).font(.system(size: 36, weight: .medium))
                            .focused($amountFocused).accessibilityLabel(String(localized: "native.wish.setPrice")).accessibilityIdentifier("native.wish.price.amount")
                            .frame(minHeight: 54).textFieldStyle(.plain)
                        CurrencyMenuButton(currency: $currency, preferred: workspace.ledger.walletSettings.walletCurrencyCode)
                    }.padding(18).background(PaperTheme.card, in: RoundedRectangle(cornerRadius: 24))
                        .paperFocusRing(amountFocused, radius: 24)
                    if failed { Text(String(localized: "v1.banner.failed")).foregroundStyle(PaperTheme.accent) }
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    PaperSubmitBar(title: String(localized: "action.save"), enabled: MoneyFormat.parseAmount(amount).map { $0 > 0 } ?? false) {
                        guard let value = MoneyFormat.parseAmount(amount), value > 0 else { return }
                        do { try workspace.setWishPrice(wish.id, amount: value, currency: currency); dismiss() } catch { failed = true }
                    }.accessibilityIdentifier("native.wish.price.save").padding(.vertical, 12).background(PaperTheme.canvas)
                }
                .navigationTitle(String(localized: "native.wish.setPrice")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(String(localized: "ui.keyboard.done")) { amountFocused = false } }
                }.background(PaperTheme.canvas.ignoresSafeArea())
        }.modifier(NativeDrawerStyle()).onAppear { currency = wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode }
    }
}

struct WishCoverPicker: View {
    @Bindable var store: WishCoverStore
    let wishID: UUID
    var name: String
    @State private var cover = WishCover()
    @State private var previewCover = WishCover()
    @State private var presetCover = WishCover()
    @State private var photoCover = WishCover(layout: .inset)
    @State private var photoMode = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoReadID = UUID()
    @State private var reading = false
    @State private var failed = false
    @State private var iconTurn = 0.0
    @State private var artOpacity = 1.0
    @State private var panStart: CGPoint?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    preview
                    Picker(String(localized: "native.cover.title"), selection: $photoMode) {
                        Text(String(localized: "native.cover.presets")).tag(false)
                        Text(String(localized: "native.cover.photos")).tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("native.cover.source")
                    if photoMode { photoOptions } else { presetOptions }
                    if failed { Text(String(localized: "native.cover.failed")).font(.subheadline).foregroundStyle(PaperTheme.accent) }
                }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.background(PaperTheme.canvas.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    Button(String(localized: "native.cover.use")) {
                        do { try store.save(cover, for: wishID); dismiss() } catch { failed = true }
                    }.buttonStyle(PaperSolidButtonStyle(enabled: !reading)).disabled(reading).padding(22).background(PaperTheme.canvas)
                        .accessibilityIdentifier("native.cover.save")
                }
                .navigationTitle(String(localized: "native.cover.title")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { dismiss() } } }
        }.modifier(NativeDrawerStyle())
            .onAppear {
                cover = store.cover(for: wishID); previewCover = cover
                photoMode = cover.layout == .inset || cover.layout == .fill
                if photoMode { photoCover = cover } else { presetCover = cover }
            }
            .onChange(of: photoMode) { _, value in
                cancelPhotoRead()
                if value {
                    if cover.layout == .symbol || cover.layout == .none { presetCover = cover }
                    cover = photoCover
                } else {
                    if cover.layout == .inset || cover.layout == .fill { photoCover = cover }
                    cover = presetCover
                }
            }
            .onChange(of: cover.layout) { old, new in if old != new && reading { cancelPhotoRead() } }
            .onDisappear { cancelPhotoRead() }
            .task(id: cover) { await updatePreview() }
            .task(id: selectedPhoto) { await readPhoto() }
    }

    private var preview: some View {
        ZStack(alignment: .topLeading) {
            WishCoverArtwork(cover: previewCover, row: true, turn: iconTurn, artworkOpacity: artOpacity)
            if !(previewCover.layout == .fill && previewCover.imageData != nil) { WishGlassPane(radius: 25) }
            Text(name.isEmpty ? String(localized: "wallet.wishes.add") : name)
                .font(.title3.weight(.semibold)).lineLimit(2).padding(21).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 100).allowsHitTesting(false)
        }
        .frame(height: 162)
        .background(WishCardBackdrop(radius: 25, photoFill: previewCover.layout == .fill && previewCover.imageData != nil))
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .foregroundStyle(previewCover.layout == .fill && previewCover.imageData != nil ? .white : WishMaterialPalette.ink)
        .contentShape(RoundedRectangle(cornerRadius: 25))
        .gesture(DragGesture(minimumDistance: 7).onChanged { value in
            guard photoMode, cover.layout == .fill, cover.imageData != nil else { return }
            if panStart == nil { panStart = CGPoint(x: cover.focusX, y: cover.focusY) }
            let initial = panStart ?? CGPoint(x: 0.5, y: 0.5)
            cover.focusX = min(1, max(0, initial.x - value.translation.width / 210))
            cover.focusY = min(1, max(0, initial.y - value.translation.height / 162))
            previewCover = cover
        }.onEnded { _ in panStart = nil })
        .accessibilityIdentifier("native.cover.preview")
    }

    private var presetOptions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 3 : 4), spacing: 10) {
            presetButton(nil)
            ForEach(WishCoverStore.symbols, id: \.self) { symbol in presetButton(symbol) }
        }
    }
    private func presetButton(_ symbol: String?) -> some View {
        let selected = symbol == nil ? cover.layout == .none : cover.layout == .symbol && cover.symbol == symbol
        let title = symbol.map { String(localized: String.LocalizationValue("native.icon." + $0)) } ?? String(localized: "native.cover.none")
        return Button {
            cancelPhotoRead()
            if let symbol { cover.symbol = symbol; cover.layout = .symbol }
            else { cover.layout = .none }
        } label: {
            VStack(spacing: 7) {
                if let symbol { CheckLineIcon(symbol: symbol, size: 25).frame(height: 30) }
                else { Image(systemName: "rectangle.slash").font(.system(size: 23, weight: .ultraLight)).frame(height: 30) }
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.65)
            }.foregroundStyle(selected ? PaperTheme.selectedInk : PaperTheme.ink).frame(maxWidth: .infinity, minHeight: 80)
                .background(selected ? PaperTheme.selectedFill : PaperTheme.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(selected ? PaperTheme.selectedStroke : .clear, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("native.cover.preset.\(symbol ?? "none")")
    }

    private var photoOptions: some View {
        VStack(spacing: 18) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(String(localized: "native.cover.choose"), systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 60).background(PaperTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 19))
            }.disabled(reading)
            if reading { ProgressView().accessibilityLabel(String(localized: "native.cover.reading")) }
            Picker(String(localized: "native.cover.layout"), selection: $cover.layout) {
                Text(String(localized: "native.cover.inset")).tag(WishCover.Layout.inset)
                Text(String(localized: "native.cover.fill")).tag(WishCover.Layout.fill)
            }.pickerStyle(.segmented)
            if cover.imageData != nil && cover.layout == .fill {
                Text(String(localized: "native.cover.dragPhoto")).font(.caption).foregroundStyle(PaperTheme.muted)
                VStack(alignment: .leading, spacing: 9) {
                    Slider(value: $cover.focusX, in: 0...1).accessibilityLabel(String(localized: "native.cover.horizontalFocus"))
                    Slider(value: $cover.focusY, in: 0...1).accessibilityLabel(String(localized: "native.cover.verticalFocus"))
                }.tint(PaperTheme.accent)
            }
            if cover.imageData != nil {
                Button(String(localized: "native.cover.removePhoto")) {
                    cancelPhotoRead(); cover.imageData = nil; photoCover.imageData = nil
                }.font(.subheadline).foregroundStyle(PaperTheme.accent).frame(minHeight: 44)
            }
        }
    }

    private func updatePreview() async {
        let next = cover
        guard previewCover != next else { return }
        // Crop changes are continuous; source / preset changes replace only artwork.
        let sameImage = previewCover.imageData == next.imageData && previewCover.layout == next.layout && previewCover.symbol == next.symbol
        if sameImage || reduceMotion { previewCover = next; iconTurn = 0; artOpacity = 1; return }
        let photo = next.layout == .fill || next.layout == .inset || previewCover.layout == .fill || previewCover.layout == .inset
        if photo {
            withAnimation(.easeIn(duration: 0.08)) { artOpacity = 0 }
            do { try await Task.sleep(for: .milliseconds(80)); try Task.checkCancellation() } catch { return }
            previewCover = next; iconTurn = 0
            withAnimation(.easeOut(duration: 0.12)) { artOpacity = 1 }
        } else {
            withAnimation(.easeIn(duration: 0.09)) { iconTurn = -90 }
            do { try await Task.sleep(for: .milliseconds(90)); try Task.checkCancellation() } catch { return }
            previewCover = next; iconTurn = 90
            withAnimation(.easeOut(duration: 0.15)) { iconTurn = 0; artOpacity = 1 }
        }
    }

    private func readPhoto() async {
        guard let item = selectedPhoto else { reading = false; return }
        let session = UUID()
        photoReadID = session
        reading = true; failed = false
        defer { if photoReadID == session { reading = false } }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
            let thumbnail = try await Task.detached { try WishCoverStore.thumbnail(data) }.value
            try Task.checkCancellation()
            guard photoReadID == session, selectedPhoto == item, photoMode else { return }
            if photoMode { photoCover = cover }
            photoCover.imageData = thumbnail; photoCover.focusX = 0.5; photoCover.focusY = 0.5
            if photoMode { cover = photoCover }
        } catch is CancellationError { }
        catch { if photoReadID == session && selectedPhoto == item { failed = true } }
    }
    private func cancelPhotoRead() { photoReadID = UUID(); selectedPhoto = nil; reading = false }
}
