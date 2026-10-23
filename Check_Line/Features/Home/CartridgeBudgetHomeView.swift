import SwiftUI

/// Native presentation of the approved R34 machine. The contact clock owns every
/// decorative reaction; inserting/ejecting never changes a budget or a record.
struct CartridgeBudgetHomeView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var stage: BudgetStage = .dashboard
    @State private var layerPosition: CGFloat = 0
    @State private var stageTransitioning = false
    @State private var stageTransitionID = UUID()
    @State private var holderDragOrigin: CGFloat?
    @State private var cardDrag = CGSize.zero
    @State private var cardDragAxis: CartridgeDragAxis?
    @State private var cardInputIsActive = false
    @State private var cardPressDidFire = false
    @State private var cardPressTask: Task<Void, Never>?
    @State private var phase: CartridgeConnection = .connected
    @State private var cardLift: CGFloat = 8
    @State private var cardScale: CGFloat = 1
    @State private var impactCompression: CGFloat = 1
    @State private var holderImpact: CGFloat = 0
    @State private var contactDate: Date?
    @State private var motionTask: Task<Void, Never>?
    @State private var motionID = UUID()
    @State private var internalSelection: UUID?
    @State private var flyingCard: HomeBudgetCardModel?
    @State private var flightPose = CartridgeFlightPose()
    @State private var stackOrder: [UUID] = []
    @State private var lastCardGesture = Date.distantPast
    @State private var receiptPosition = 0
    @State private var receiptPositions: [UUID: Int] = [:]
    @State private var recordScrollPositions: [UUID: RecordListReadingPosition] = [:]
    @State private var showUnbudgeted = false
    @State private var showArchive = false
    @State private var detail: BudgetSheetSelection?
    @State private var selectedExpense: Expense?
    @State private var deletingExpense: ExpenseDeletionSelection?
    @State private var availabilityDate = Date()
    @State private var libraryUsesArc = true
    @State private var libraryFocusedCard: HomeBudgetCardModel?
    @State private var libraryIsMounted = false

    private var card: HomeBudgetCardModel? { workspace.selectedCard }
    private var recordProgress: CGFloat { max(0, -layerPosition) }
    private var libraryProgress: CGFloat { max(0, layerPosition) }
    private var connected: Bool { phase == .connected || phase == .charging }
    private var gestureIsActive: Bool { holderDragOrigin != nil || cardDragAxis != nil }
    private var frontMovement: CGSize {
        guard stage == .dashboard else { return CGSize(width: cardDrag.width * 0.55, height: 0) }
        if cardDragAxis == .horizontal {
            let lift = min(1, abs(cardDrag.width) / 70)
            return CGSize(width: bounded(cardDrag.width, -320, 320), height: -lift * (connected ? 64 : 0) + bounded(cardDrag.height * 0.2, -15, 15))
        }
        return CGSize(width: 0, height: bounded(cardDrag.height, -104, 40))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperTheme.canvas.ignoresSafeArea()
                GeometryReader { proxy in
                    if let card { budgetStage(card, size: proxy.size, origin: proxy.frame(in: .global).origin) }
                    else { emptyHome }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: WalletTabTransition.usesSystemBar ? 8 : 88) }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(WalletTabTransition.usesSystemBar ? .visible : .hidden, for: .tabBar)
            .toolbar(.hidden, for: .bottomBar)
            .sheet(item: $detail, onDismiss: { chrome?.detailDidDismiss(workspace: workspace) }) { selected in
                BudgetDetailSheet(workspace: workspace, budgetID: selected.budgetID, initialSection: selected.section).modifier(NativeDrawerStyle())
            }
            .sheet(item: $selectedExpense) { expense in
                NavigationStack { WalletExpenseDetail(workspace: workspace, expenseID: expense.id) }.modifier(NativeDrawerStyle())
            }
            .sheet(item: $deletingExpense) { selection in
                ExpenseDeletionReviewView(workspace: workspace, expenseID: selection.id)
            }
            .sheet(isPresented: $showUnbudgeted, onDismiss: { chrome?.isShowingDetail = false }) {
                NavigationStack {
                    UnbudgetedRecordsView(workspace: workspace)
                        .navigationDestination(for: BudgetWorkspaceRoute.self) { BudgetWorkspaceDestination(workspace: workspace, route: $0) }
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { showUnbudgeted = false } } }
                }.modifier(NativeDrawerStyle())
            }
            .sheet(isPresented: $showArchive, onDismiss: { chrome?.isShowingDetail = false }) { ArchivedBudgetSheet(workspace: workspace) }
            .onAppear { availabilityDate = Date(); chrome?.isShowingDetail = false; synchronizeStack() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in availabilityDate = Date() }
            .onDisappear { settlePresentation() }
            .onChange(of: card?.id) { old, current in
                // An internal switch already captured the outgoing position before
                // selecting the next card. Its new position must not replace it.
                if internalSelection != current, let old { receiptPositions[old] = receiptPosition }
                receiptPosition = current.flatMap { receiptPositions[$0] } ?? 0
                synchronizeStack()
                if internalSelection == current { internalSelection = nil }
                else { settlePresentation(); phase = .connected; cardLift = 8; contactDate = nil }
            }
            .onChange(of: workspace.cards.map(\.id)) { _, _ in synchronizeStack() }
            .onChange(of: scenePhase) { _, value in
                if value != .active { settlePresentation() }
                else { availabilityDate = Date() }
            }
            .onChange(of: reduceMotion) { _, value in if value { settlePresentation() } }
            .onChange(of: chrome?.workspaceRequest?.id) { _, _ in
                guard let chrome, let request = chrome.workspaceRequest else { return }
                switch request.route {
                case .budget(let id, _, let section): detail = BudgetSheetSelection(budgetID: id, section: section)
                case .expense(let id): selectedExpense = workspace.ledger.expenses[id]
                case .unbudgeted: showUnbudgeted = true
                }
                chrome.workspaceRequest = nil
            }
        }
    }

    private var emptyHome: some View {
        VStack(spacing: 24) {
            WalletEmptyBudgetCard { workspace.openComposer(.budget) }
            Button(String(localized: "wallet.empty.manual")) { workspace.openComposer(.budget) }.buttonStyle(PaperQuietButtonStyle())
            if workspace.ledger.budgets.values.contains(where: { $0.state == .archived }) {
                Button(String(localized: "ui.directory.archived")) { showArchive = true }.frame(minHeight: 44)
            }
        }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Text(String(localized: "tab.budgets")).font(.system(size: 29, weight: .bold)).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { workspace.openComposer(.budget) } label: { Image(systemName: "plus").frame(width: 44, height: 44).paperGlass(.circle, interactive: true) }
                .accessibilityLabel(String(localized: "v1.budget.create")).accessibilityIdentifier("wallet.header.create")
            Button { chrome?.isSettingsPresented = true } label: { Image(systemName: "gearshape").frame(width: 44, height: 44).paperGlass(.circle, interactive: true) }
                .accessibilityLabel(String(localized: "tab.settings")).accessibilityIdentifier("wallet.profile")
        }.font(.title3).foregroundStyle(PaperTheme.ink).padding(.horizontal, 23).padding(.vertical, 8).frame(maxWidth: 650).frame(maxWidth: .infinity)
    }

    private func budgetStage(_ card: HomeBudgetCardModel, size: CGSize, origin: CGPoint) -> some View {
        let width = min(650, size.width)
        let height = max(380, size.height)
        let cardWidth = width > 600 ? 410 : width - (width < 340 ? 38 : 46)
        let expandedHeight: CGFloat = typeSize.isAccessibilitySize ? 306 : 258
        let stageHeight = expandedHeight + 68
        let compactHeight: CGFloat = typeSize.isAccessibilitySize ? 88 : 68
        let morph = clamp((recordProgress - 0.2) / 0.8)
        let faceHeight = lerp(expandedHeight, compactHeight, morph)
        let faceTop = lerp(62, 12, recordProgress)
        let libraryHeight = max(260, height - 42)
        let librarySceneHeight = max(0, libraryHeight - 116)
        let libraryFaceHeight = min(min(356, width * 0.82) * 0.75, librarySceneHeight * 0.74)
        let libraryFaceWidth = min(min(356, width * 0.82), libraryFaceHeight * 4 / 3)
        let transport = libraryUsesArc && !reduceMotion && !typeSize.isAccessibilitySize ? libraryProgress : 0
        let libraryFaceTop = 52 + (librarySceneHeight - libraryFaceHeight) / 2
        let holderTop = lerp(stageHeight - 6, max(stageHeight - 6, height - 60), max(recordProgress, libraryProgress))
        let holderOpacity = 1 - Double(clamp(recordProgress * 1.85))
        return ZStack(alignment: .top) {
            if recordProgress > 0.001 {
            recordsLayer(card, top: lerp(164, compactHeight + 72, recordProgress), size: CGSize(width: width, height: height))
                .opacity(Double(clamp((recordProgress - 0.4) / 0.6)))
                .allowsHitTesting(stage == .records && !stageTransitioning && !gestureIsActive)
                .zIndex(0)
            }

            if libraryIsMounted || stage == .library || libraryProgress > 0.001 {
            CartridgeLibraryView(workspace: workspace, onChoose: { choose($0) }, onClose: { setStage(.dashboard) }, onReturnProgress: { progress in
                if stage == .library { layerPosition = 1 - progress }
            }, presentationProgress: libraryProgress,
               transportsFocusedCard: libraryUsesArc && (stageTransitioning || (transport > 0.001 && transport < 0.999)),
               onArcPresentation: { arc, focus in libraryUsesArc = arc; libraryFocusedCard = focus })
                .frame(width: width, height: libraryHeight)
                .allowsHitTesting(stage == .library && !stageTransitioning)
                .accessibilityHidden(stage != .library)
                .transition(.identity)
                .zIndex(1)
            }

            holderBack(width: width, height: max(210, height - stageHeight + 96))
                .allowsHitTesting(false)
                .offset(y: holderTop + 18)
                .opacity(holderOpacity)
                .zIndex(2)

            slotRecess(width: cardWidth - 78)
                .allowsHitTesting(false)
                .opacity(0.46 * (1 - Double(max(recordProgress, libraryProgress))))
                .offset(y: holderTop + 5)
                .zIndex(3)

            Group {
                rearStack(width: cardWidth, height: expandedHeight)
                    .offset(y: 62 - (reduceMotion ? 0 : libraryProgress * 74))
                    // Restore the stored cards only once the transported face
                    // covers their amounts, rather than showing them through it.
                    .opacity(Double(clamp(1 - recordProgress * 4) * clamp(1 - libraryProgress * 5)))
                    .zIndex(4)
                frontCard(card, width: lerp(cardWidth, libraryFaceWidth, transport),
                          height: lerp(faceHeight, libraryFaceHeight, transport), morph: morph, libraryStyle: transport)
                    .padding(.bottom, 68 * (1 - morph))
                    .mask {
                        // Mask before moving the card so the mask travels with
                        // its contents instead of clipping the lower edge.
                        Rectangle().opacity(!libraryUsesArc || libraryProgress < 0.999 || stageTransitioning ? 1 : 0)
                            .transaction { $0.animation = nil }
                    }
                    .scaleEffect(x: cardScale, y: cardScale * impactCompression, anchor: .top)
                    .rotationEffect(.degrees(cardDragAxis == .horizontal ? Double(bounded(cardDrag.width / 260, -1, 1)) * 6 : 0))
                    .rotation3DEffect(.degrees(cardDragAxis == .horizontal ? Double(bounded(cardDrag.width / 260, -1, 1)) * 12 : 0), axis: (x: 0, y: 1, z: 0))
                    .offset(x: frontMovement.width,
                            y: lerp(faceTop + cardLift * (1 - morph) + frontMovement.height, libraryFaceTop, transport))
                    .opacity(libraryUsesArc ? 1 : Double(1 - libraryProgress))
                    .allowsHitTesting(stage != .library && !stageTransitioning)
                    .accessibilityHidden(stage == .library)
                    .zIndex(5)
            }

            if let flyingCard {
                cartridgeFace(flyingCard, morph: 0, interactive: false)
                    .frame(width: cardWidth, height: expandedHeight)
                    .scaleEffect(flightPose.scale, anchor: .top)
                    .rotationEffect(.degrees(flightPose.rotation))
                    .offset(x: flightPose.x, y: 62 + flightPose.y)
                    .opacity(flightPose.opacity)
                    .zIndex(flightPose.behind ? 3.5 : 8)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }

            holderFront(card, width: width, height: max(230, height - stageHeight + 50))
                .offset(y: holderTop + holderImpact)
                .opacity(holderOpacity)
                .allowsHitTesting(libraryProgress < 0.01)
                .zIndex(6)

            if libraryProgress < 0.99 {
                levelControls(width: width)
                    .offset(y: lerp(stageHeight - 6, compactHeight + 20, recordProgress))
                    .opacity(Double(1 - libraryProgress))
                    .zIndex(10)
            }
            if let contactDate, recordProgress < 0.05, libraryProgress < 0.05 {
                CartridgeContactStamp(startedAt: contactDate)
                    .frame(width: 112, height: 42).offset(y: stageHeight - 12).zIndex(12)
            }
            frameDragRegions(width: width, height: height)
                .zIndex(9)
        }
        .frame(width: width, height: height, alignment: .top).frame(maxWidth: .infinity)
        .clipped()
        .simultaneousGesture(cardGesture(in: CGRect(x: origin.x + (size.width - cardWidth) / 2 + frontMovement.width,
                                                    y: origin.y + faceTop + cardLift * (1 - morph) + frontMovement.height,
                                                    width: cardWidth, height: faceHeight)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "native.holder"))
        .accessibilityIdentifier("native.holder.surface")
        .accessibilityValue(holderAccessibilityValue)
        .accessibilityActions {
            Button(String(localized: "native.records")) { if connected { setStage(.records) } }
            Button(String(localized: "native.library")) { setStage(.library) }
            Button(String(localized: "native.returnBudget")) { setStage(.dashboard) }
        }
        .transaction { if reduceMotion { $0.disablesAnimations = true; $0.animation = nil } }
    }

    private func frontCard(_ card: HomeBudgetCardModel, width: CGFloat, height: CGFloat, morph: CGFloat, libraryStyle: CGFloat = 0) -> some View {
        ZStack(alignment: .bottom) {
            CartridgeContactExtension().frame(width: max(80, width - 78), height: 68 * (1 - morph))
                .offset(y: 48 * (1 - morph)).opacity(Double(clamp(1 - recordProgress * 3) * (1 - libraryStyle)))
            cartridgeFace(card, morph: morph, interactive: true)
                .opacity(Double(1 - libraryStyle))
            CartridgeLibraryCard(card: libraryFocusedCard ?? card,
                                 expenses: BudgetPresentation.expenses(libraryFocusedCard ?? card, in: workspace.ledger), compact: false)
                .opacity(Double(libraryStyle)).allowsHitTesting(false).accessibilityHidden(true)
        }
        .frame(width: width, height: height)
        .contentShape(RoundedRectangle(cornerRadius: 27))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(card.name)
        .accessibilityValue(String(localized: phase.localization))
        .accessibilityIdentifier("wallet.home.card")
        .accessibilityAction { if connected { open(card, .overview) } else { insert() } }
        .accessibilityActions {
            Button(String(localized: "wallet.card.details")) { if connected { open(card, .overview) } else { insert() } }
            Button(String(localized: "wallet.card.next")) { changeCard(1) }
            Button(String(localized: "native.eject")) { eject() }
        }
    }

    private func cartridgeFace(_ card: HomeBudgetCardModel, morph: CGFloat, interactive: Bool) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                NativeLiquidSurface(progress: CGFloat(BudgetPresentation.fill(card)), burstAt: interactive ? contactDate : nil, active: interactive && libraryProgress < 0.5, horizontalAmount: morph)
                Text(card.name)
                    .font(.system(size: lerp(typeSize.isAccessibilitySize ? 22 : 24, 15, morph), weight: .semibold))
                    .lineLimit(morph > 0.6 ? 1 : 2)
                    .frame(maxWidth: geometry.size.width - lerp(44, 135, morph), alignment: .leading)
                    .offset(x: lerp(22, 18, morph), y: lerp(22, geometry.size.height * 0.5 - 10, morph))
                VStack(alignment: .leading, spacing: 3) {
                    if BudgetPresentation.isUpcoming(card, now: availabilityDate) {
                        Text(String(format: String(localized: "settlement.early.resumes"), card.periodStart.formatted(date: .abbreviated, time: .omitted)))
                    } else if card.periodState == .pendingSettlement { Text(String(localized: "budget.settling.section")) }
                    else {
                        HStack(spacing: 3) {
                            Text(card.periodStart, format: .dateTime.month().day())
                            if let end = card.periodEnd { Text(verbatim: "–"); Text(end, format: .dateTime.month().day()) }
                            Text(verbatim: "· " + card.currencyCode)
                        }
                    }
                }.font(.system(size: 11)).foregroundStyle(PaperTheme.muted)
                    .opacity(Double(clamp(1 - morph * 3))).offset(x: 22, y: typeSize.isAccessibilitySize ? 62 : 57)
                VStack(alignment: .trailing, spacing: 5 * (1 - morph)) {
                    Text(String(localized: BudgetPresentation.isUpcoming(card, now: availabilityDate) ? "settlement.early.nextLimit" : BudgetPresentation.remaining(card) >= 0 ? "v1.card.remaining" : card.snapshot.certainOverrunAmount > 0 ? "wallet.overrun" : "wallet.possibleOverrun"))
                        .font(.system(size: 12)).frame(height: 15 * (1 - morph)).clipped().opacity(Double(clamp(1 - morph * 4)))
                    if interactive {
                        ContactAmountText(value: BudgetPresentation.remaining(card), currency: card.currencyCode, contact: contactDate)
                            .font(.system(size: lerp(typeSize.isAccessibilitySize ? 38 : 48, 24, morph), weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    } else {
                        Text(MoneyFormat.string(BudgetPresentation.remaining(card), currencyCode: card.currencyCode))
                            .font(.system(size: 48, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
                .frame(width: geometry.size.width - 44, height: geometry.size.height, alignment: .bottomTrailing)
                .offset(x: 22, y: -lerp(28, (geometry.size.height - 29) / 2, morph))
                if interactive {
                    Button { workspace.openComposer(.record, budgetID: card.id) } label: {
                        Image(systemName: "plus").font(.system(size: 26, weight: .light)).frame(width: 48, height: 48)
                            .background(.white.opacity(0.13), in: Circle()).overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 0.8))
                    }.buttonStyle(.plain).offset(x: 22, y: geometry.size.height - 74)
                        .opacity(Double(clamp(1 - morph * 4))).allowsHitTesting(recordProgress < 0.05 && !stageTransitioning)
                        .accessibilityLabel(String(localized: "capture.title")).accessibilityIdentifier("wallet.home.capture")
                        .disabled(BudgetPresentation.isUpcoming(card, now: availabilityDate))
                }
            }.foregroundStyle(PaperTheme.ink)
        }.modifier(NativeGlassCard(radius: lerp(27, 25, morph)))
    }

    private func rearStack(width: CGFloat, height: CGFloat) -> some View {
        let all = workspace.cards
        let rear = stackOrder.compactMap { id in all.first { $0.id == id && id != card?.id } }
        return ZStack(alignment: .top) {
            ForEach(Array(rear.prefix(2).enumerated()), id: \.element.id) { index, item in
                let depth = CGFloat(index + 1)
                let lift = cardDragAxis == .horizontal ? min(1, abs(cardDrag.width) / 70) * 0.4 : 0
                let offset = cardLift - (depth - lift) * (connected ? 16 : 6)
                cartridgeFace(item, morph: 0, interactive: false)
                    .frame(width: width, height: height)
                    .scaleEffect(1 - (depth - lift) * 0.072, anchor: .top)
                    .offset(y: offset)
                    .opacity(flyingCard?.id == item.id ? 0 : 0.32)
                    .zIndex(Double(3 - index))
                    .accessibilityIdentifier("native.home.stack.back.\(index + 1)")
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }

    private func holderBack(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(LinearGradient(colors: [PaperTheme.cardholderSurface, PaperTheme.cardholderBottom.opacity(0.3), PaperTheme.canvas], startPoint: .top, endPoint: .bottom))
            .frame(width: width, height: height)
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func slotRecess(width: CGFloat) -> some View {
        Ellipse().fill(LinearGradient(colors: [PaperTheme.accent.opacity(0.85), PaperTheme.cardholderSurface], startPoint: .top, endPoint: .bottom))
            .frame(width: width, height: 7).overlay(Ellipse().stroke(.white.opacity(0.55), lineWidth: 0.5))
            .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func holderFront(_ card: HomeBudgetCardModel, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(LinearGradient(colors: [PaperTheme.cardholderSurface, PaperTheme.cardholderBottom.opacity(0.42), PaperTheme.canvas], startPoint: .top, endPoint: .bottom))
                .frame(height: max(0, height - 22)).offset(y: 22)
                .allowsHitTesting(false).accessibilityHidden(true)
            CartridgeFrontLip().fill(PaperTheme.cardholderSurface)
                .frame(height: 44).offset(y: -22)
                .overlay(alignment: .top) { CartridgeLipHighlight().stroke(.white.opacity(0.64), lineWidth: 0.7).frame(height: 44).offset(y: -22) }
                .allowsHitTesting(false).accessibilityHidden(true)
            summary(card).padding(.horizontal, 22).padding(.top, 36)
                .frame(height: height, alignment: .top)
                .opacity(Double(clamp(1 - recordProgress * 2.5) * (1 - libraryProgress)))
                .allowsHitTesting(recordProgress < 0.01 && libraryProgress < 0.01 && !stageTransitioning)
            Color.clear.frame(height: 36).contentShape(Rectangle()).gesture(holderGesture)
        }.frame(width: width, height: height, alignment: .top)
    }

    private func summary(_ card: HomeBudgetCardModel) -> some View {
        ScrollView {
            VStack(spacing: 11) {
                if typeSize.isAccessibilitySize { VStack(spacing: 13) { usedTile(card); periodTile(card) } }
                else { HStack(spacing: 13) { usedTile(card); periodTile(card) }.fixedSize(horizontal: false, vertical: true) }
                let pending = BudgetPresentation.pendingCount(card, in: workspace.ledger)
                if pending > 0, connected {
                    Button { open(card, .pending) } label: {
                        HStack { Text(String(format: String(localized: "wallet.pending.count"), pending)); Spacer(); Text(MoneyFormat.string(card.snapshot.pendingAmount, currencyCode: card.currencyCode)).monospacedDigit(); Image(systemName: "chevron.right") }.font(.subheadline).padding(12)
                    }.buttonStyle(.plain)
                }
                let unbudgeted = workspace.ledger.expenses.values.filter { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }.count
                if unbudgeted > 0, connected {
                    Button { showUnbudgeted = true } label: { HStack { Text(String(localized: "v1.unbudgeted")); Spacer(); Text(unbudgeted, format: .number); Image(systemName: "chevron.right") }.font(.subheadline).padding(12) }.buttonStyle(.plain)
                }
                HStack(spacing: 9) {
                    Text(String(localized: "wallet.home.recent")).font(.system(size: 14, weight: .semibold))
                    if connected { ContactNumberText(value: BudgetPresentation.expenses(card, in: workspace.ledger).count, contact: contactDate).font(.caption).foregroundStyle(PaperTheme.muted) }
                    else { Text(verbatim: "—").font(.caption).foregroundStyle(PaperTheme.muted) }
                    Spacer()
                    if connected {
                        Button { setStage(.records) } label: { Image(systemName: "arrow.up.right").frame(width: 44, height: 36) }.accessibilityLabel(String(localized: "wallet.records.all"))
                    }
                }.padding(.top, 1).contactEntrance(contactDate)
                if connected {
                    WalletReceiptStack(rows: BudgetPresentation.expenses(card, in: workspace.ledger), position: $receiptPosition, contact: contactDate, active: connected) { selectedExpense = $0 }
                    if BudgetPresentation.expenses(card, in: workspace.ledger).isEmpty { Text(String(localized: "wallet.records.empty")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(14) }
                } else { Color.clear.frame(height: 105).overlay { Text(String(localized: "native.card.detached")).font(.caption).foregroundStyle(PaperTheme.muted) } }
            }.padding(.bottom, 25)
        }.scrollBounceBehavior(.basedOnSize).foregroundStyle(PaperTheme.ink)
    }

    private func usedTile(_ card: HomeBudgetCardModel) -> some View {
        Button { open(card, .overview) } label: {
            VStack(alignment: .leading, spacing: 13) {
                summaryLabel("v1.card.used").contactEntrance(contactDate)
                Group {
                    if connected { ContactAmountText(value: BudgetPresentation.used(card), currency: card.currencyCode, contact: contactDate) }
                    else { Text(verbatim: "—").foregroundStyle(PaperTheme.muted) }
                }.font(.system(size: typeSize.isAccessibilitySize ? 32 : 27, weight: .medium)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                HStack(alignment: .bottom, spacing: 3) {
                    BudgetMiniBars(card: card, ledger: workspace.ledger).scaleEffect(x: 0.85, y: 0.6, anchor: .bottomLeading).frame(width: 74, height: 17).opacity(connected ? 0.65 : 0.16)
                    Spacer(minLength: 0)
                    Text(String(localized: "wallet.last7days")).font(.system(size: 9)).foregroundStyle(PaperTheme.muted)
                }.contactEntrance(contactDate)
            }.padding(16).frame(maxWidth: .infinity, minHeight: 113, alignment: .leading).walletSurface(radius: 24)
                .overlay { ComponentLightSweep(startedAt: contactDate, origin: .trailing) }
        }.buttonStyle(.plain).disabled(!connected).accessibilityIdentifier("native.home.summary.used")
    }

    private func periodTile(_ card: HomeBudgetCardModel) -> some View {
        Button { open(card, .calendar) } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Text(card.periodStart, format: .dateTime.month(.wide)); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 11)) }.font(.system(size: 12)).foregroundStyle(PaperTheme.muted).contactEntrance(contactDate)
                HStack(alignment: .bottom, spacing: 6) {
                    MiniBudgetCalendar(card: card, ledger: workspace.ledger).scaleEffect(0.9, anchor: .bottomLeading).frame(width: 60, height: 47).opacity(connected ? 0.65 : 0.16).contactEntrance(contactDate)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if !connected { Text(verbatim: "—").font(.system(size: 31, weight: .medium)).foregroundStyle(PaperTheme.muted) }
                        else if let end = card.periodEnd {
                            ContactNumberText(value: max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: end).day ?? 0), contact: contactDate).font(.system(size: 31, weight: .medium)).monospacedDigit()
                        } else { Image(systemName: "infinity").font(.title2) }
                        Text(String(localized: card.periodEnd == nil ? "wallet.noDeadline" : "wallet.daysLeft")).font(.system(size: 10)).foregroundStyle(PaperTheme.muted).contactEntrance(contactDate)
                    }
                }
            }.padding(16).frame(maxWidth: .infinity, minHeight: 113, alignment: .leading).walletSurface(radius: 24)
                .overlay { ComponentLightSweep(startedAt: contactDate, origin: .leading) }
        }.buttonStyle(.plain).disabled(!connected).accessibilityIdentifier("native.home.summary.period")
    }

    private func recordsLayer(_ card: HomeBudgetCardModel, top: CGFloat, size: CGSize) -> some View {
        let records = BudgetPresentation.expenses(card, in: workspace.ledger)
        return RememberedRecordList(position: Binding(get: { recordScrollPositions[card.id] }, set: { recordScrollPositions[card.id] = $0 })) { memory in
            List {
                if records.isEmpty {
                    Text(String(localized: "wallet.records.empty")).foregroundStyle(PaperTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 36)
                        .contentShape(Rectangle()).gesture(holderGesture)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                ForEach(recordDays(records), id: \.self) { day in
                    Text(day, format: .dateTime.month().day()).font(.caption).foregroundStyle(PaperTheme.muted).padding(.top, 10)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 23, bottom: 4, trailing: 23))
                    ForEach(records.filter { Calendar.current.isDate($0.occurredAt, inSameDayAs: day) }) { expense in
                        Button { selectedExpense = expense } label: {
                            HStack(spacing: 14) {
                                Text(expense.merchant ?? String(localized: "v1.card.record.untitled")).font(.system(size: 16,weight: .semibold)).lineLimit(2)
                                Spacer(minLength: 10)
                                Text((expense.kind == .refund ? "+" : "")+MoneyFormat.string(expense.originalAmount,currencyCode: expense.originalCurrencyCode))
                                    .font(.system(size: 16,weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                            }.foregroundStyle(PaperTheme.ink).padding(.horizontal,18).frame(maxWidth: .infinity,minHeight: 72).walletSurface(radius: 22)
                        }.buttonStyle(.plain).id(expense.id).accessibilityIdentifier("native.record.\(expense.id)")
                            .background(RecordListPositionProbe(memory: memory, id: expense.id).allowsHitTesting(false))
                            .listRowInsets(EdgeInsets(top: 6, leading: 23, bottom: 6, trailing: 23))
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // Preview is not deletion: a destructive swipe role
                                // optimistically removes the List cell before review.
                                Button { deletingExpense = ExpenseDeletionSelection(id: expense.id) } label: {
                                    Label(String(localized: "action.delete"), systemImage: "trash")
                                }.tint(.red).accessibilityIdentifier("expense.delete.swipe")
                            }
                    }
                }
            }.listStyle(.plain).scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
        }.id(card.id).scrollBounceBehavior(.basedOnSize).frame(width: size.width, height: max(80, size.height - top))
            .offset(y: top).accessibilityElement(children: .contain).accessibilityIdentifier("native.budget.records").accessibilityHidden(stage != .records)
    }

    private func levelControls(width: CGFloat) -> some View {
        HStack {
            if recordProgress > 0.6 {
                Text(String(localized: "native.records")).font(.system(size: 12, weight: .medium)).foregroundStyle(PaperTheme.muted).padding(.leading, 23)
                    .opacity(Double(clamp((recordProgress - 0.6) / 0.4)))
            } else {
                levelButton(symbol: "chevron.up", label: "native.records", enabled: connected) { setStage(.records) }
                    .opacity(Double(clamp(1 - recordProgress * 2)))
            }
            Spacer()
            levelButton(symbol: "chevron.down", label: recordProgress > 0.5 ? "native.returnBudget" : "native.library", enabled: true) {
                setStage(recordProgress > 0.5 ? .dashboard : .library)
            }
        }.padding(.horizontal, 5).frame(width: width, height: 44)
    }

    private func levelButton(symbol: String, label: String.LocalizationValue, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 34, height: 28)
                .background(PaperTheme.cardholderSurface.opacity(0.7), in: RoundedRectangle(cornerRadius: 13))
                .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.4), lineWidth: 0.6) }
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(PaperTheme.accent).disabled(!enabled).opacity(enabled ? 0.9 : 0.25)
            .accessibilityLabel(String(localized: label)).accessibilityIdentifier(symbol == "chevron.up" ? "native.holder.up" : "native.holder.down")
    }

    private func frameDragRegions(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: stage == .records ? 19 : 22).contentShape(Rectangle()).gesture(holderGesture)
            Spacer(minLength: 0).allowsHitTesting(false)
            Color.clear.frame(width: stage == .records ? 19 : 22).contentShape(Rectangle()).gesture(holderGesture)
        }.frame(width: width, height: max(0, height - 48)).allowsHitTesting(stage != .library)
    }

    private var holderGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) * 1.25 else { return }
                if holderDragOrigin == nil {
                    guard stage != .dashboard || connected || value.translation.height > 0 else { return }
                    stageTransitionID = UUID(); stageTransitioning = false; holderDragOrigin = layerPosition
                }
                guard let start = holderDragOrigin else { return }
                let travel: CGFloat = max(180, (typeSize.isAccessibilitySize ? 374 : 326) - 104)
                layerPosition = bounded(start + value.translation.height / travel, -1, 1)
            }
            .onEnded { value in
                guard let start = holderDragOrigin else { return }
                holderDragOrigin = nil; lastCardGesture = Date()
                guard abs(value.translation.height) >= 56 else { setStage(stage, force: true); return }
                let projected = layerPosition + bounded((value.predictedEndTranslation.height - value.translation.height) / 1500, -0.15, 0.15)
                let target: BudgetStage = start < -0.5 ? (projected > -0.45 ? .dashboard : .records) : projected < -0.55 ? .records : projected > 0.55 ? .library : .dashboard
                setStage(target, force: true)
            }
    }

    // This recognizer lives on the stationary stage, never on the transformed
    // card. One touch owns tap, hold and drag until release or cancellation.
    private func cardGesture(in hitFrame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if !cardInputIsActive {
                    guard stage != .library, !stageTransitioning, hitFrame.contains(value.startLocation) else { return }
                    let addButton = CGRect(x: hitFrame.minX + 14, y: hitFrame.maxY - 82, width: 64, height: 64)
                    guard stage != .dashboard || !addButton.contains(value.startLocation) else { return }
                    cardInputIsActive = true; cardPressDidFire = false
                    cardPressTask?.cancel()
                    if stage == .dashboard, connected {
                        cardPressTask = Task { @MainActor in
                            do { try await Task.sleep(for: .milliseconds(440)) } catch { return }
                            guard cardInputIsActive, cardDragAxis == nil, stage == .dashboard, connected else { return }
                            cardPressDidFire = true; lastCardGesture = Date(); eject()
                        }
                    }
                }
                if cardDragAxis == nil {
                    guard max(abs(value.translation.width), abs(value.translation.height)) >= 12 else { return }
                    cardPressTask?.cancel()
                    cardDragAxis = abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
                    if stage == .dashboard { cancelMotionForGesture() }
                    if stage == .records, cardDragAxis == .vertical { holderDragOrigin = layerPosition }
                }
                if stage == .records, cardDragAxis == .vertical {
                    layerPosition = bounded(-1 + max(0, value.translation.height) / 222, -1, 0)
                } else { cardDrag = value.translation }
            }
            .onEnded { value in
                guard cardInputIsActive else { return }
                cardInputIsActive = false; cardPressTask?.cancel()
                if cardDragAxis == nil {
                    guard !cardPressDidFire, Date().timeIntervalSince(lastCardGesture) > 0.35 else { return }
                    lastCardGesture = Date()
                    if stage == .dashboard, let card { connected ? open(card, .overview) : insert() }
                    return
                }
                let axis = cardDragAxis
                holderDragOrigin = nil; lastCardGesture = Date()
                if stage == .records, axis == .vertical {
                    setStage(value.translation.height > 70 ? .dashboard : .records, force: true)
                    withAnimation(motion(.settle)) { cardDrag = .zero }; cardDragAxis = nil
                    return
                }
                guard stage == .dashboard || stage == .records else { return }
                let flick = abs(value.velocity.width) > 650 && abs(value.translation.width) > 16 && value.velocity.width * value.translation.width > 0
                if axis == .horizontal, abs(value.translation.width) > 64 || flick { changeCard(value.translation.width < 0 ? 1 : -1) }
                else if axis == .vertical, connected, value.translation.height < -32 { eject() }
                else if axis == .vertical, !connected, value.translation.height > 28 { insert() }
                else { withAnimation(motion(.settle)) { cardDrag = .zero; cardScale = 1 } }
                cardDragAxis = nil
            }
    }

    private func summaryLabel(_ key: String.LocalizationValue) -> some View {
        HStack { Text(String(localized: key)); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 11)) }.font(.system(size: 12)).foregroundStyle(PaperTheme.muted)
    }
    private var holderAccessibilityValue: String {
        String(localized: stageTransitioning || gestureIsActive ? "native.holder.moving" : "native.holder.ready") + " · " + String(localized: stage == .records ? "native.records" : stage == .library ? "native.library" : "tab.budgets")
    }
    private func recordDays(_ expenses: [Expense]) -> [Date] { Array(Set(expenses.map { Calendar.current.startOfDay(for: $0.occurredAt) })).sorted(by: >) }
    private func synchronizeStack() {
        let ids = workspace.cards.map(\.id)
        stackOrder = stackOrder.filter { ids.contains($0) }
        stackOrder += ids.filter { !stackOrder.contains($0) }
        if let selected = card?.id { stackOrder.removeAll { $0 == selected }; stackOrder.insert(selected, at: 0) }
    }
    private func setStage(_ value: BudgetStage, force: Bool = false) {
        guard force || stage != value || abs(layerPosition - CGFloat(value.rawValue)) > 0.001 else { return }
        guard value != .records || connected else { return }
        if value == .library && stage != .library { libraryUsesArc = true; libraryFocusedCard = card }
        let transition = UUID(); stageTransitionID = transition
        if stage == .library || value == .library || libraryProgress > 0 { libraryIsMounted = true }
        stageTransitioning = !reduceMotion; holderDragOrigin = nil
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9), completionCriteria: .logicallyComplete) {
            stage = value; layerPosition = CGFloat(value.rawValue); cardDrag = .zero
        } completion: {
            if stageTransitionID == transition {
                stageTransitioning = false
                if value != .library { libraryIsMounted = false }
            }
        }
    }
    private func choose(_ value: HomeBudgetCardModel) {
        setStage(.dashboard)
        if value.id == card?.id { if !connected { insert() }; return }
        changeCard(1, selected: value)
    }
    private func open(_ card: HomeBudgetCardModel, _ section: BudgetDetailSection) {
        guard !stageTransitioning, connected else { return }
        settlePresentation(); detail = BudgetSheetSelection(budgetID: card.id, section: section)
    }
    private func cancelMotionForGesture() {
        motionTask?.cancel(); motionTask = nil; motionID = UUID(); flyingCard = nil
        if phase == .inserting || phase == .charging { phase = .connected; cardLift = 8 }
        else if phase == .changing || phase == .ejecting { phase = .detached; cardLift = -56 }
        contactDate = nil; cardScale = 1; impactCompression = 1; holderImpact = 0
    }
    private func settlePresentation() {
        cardPressTask?.cancel(); cardInputIsActive = false; cardPressDidFire = false
        cancelMotionForGesture(); holderDragOrigin = nil; cardDragAxis = nil; cardDrag = .zero
        layerPosition = CGFloat(stage.rawValue); stageTransitioning = false; stageTransitionID = UUID()
        libraryIsMounted = stage == .library
    }
    private func eject() {
        guard stage == .dashboard, connected else { return }
        motionTask?.cancel(); let token = UUID(); motionID = token
        phase = .ejecting; contactDate = nil; PaperHaptics.light()
        withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0.7, 0.3, 1, duration: 0.28)) { cardLift = -56; cardDrag = .zero; cardScale = 1 }
        motionTask = Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(280)) }
            guard !Task.isCancelled, motionID == token else { return }
            phase = .detached
        }
    }
    private func insert() {
        guard stage == .dashboard, !connected else { return }
        motionTask?.cancel(); let token = UUID(); motionID = token
        phase = .inserting; contactDate = nil
        withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0.6, 0.7, 1, duration: 0.18)) { cardLift = 8; cardDrag = .zero; cardScale = 1 }
        motionTask = Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(180)) }
            guard !Task.isCancelled, motionID == token else { return }
            phase = .charging; contactDate = reduceMotion ? nil : Date(); PaperHaptics.light()
            if !reduceMotion {
                withAnimation(.linear(duration: 0.018)) { impactCompression = 0.995; holderImpact = 0.9 }
                try? await Task.sleep(for: .milliseconds(18))
                guard !Task.isCancelled, motionID == token else { return }
                withAnimation(.linear(duration: 0.042)) { impactCompression = 1.001; holderImpact = -0.25 }
                try? await Task.sleep(for: .milliseconds(42))
                guard !Task.isCancelled, motionID == token else { return }
                withAnimation(.linear(duration: 0.08)) { impactCompression = 1; holderImpact = 0 }
                try? await Task.sleep(for: .milliseconds(740))
            }
            guard !Task.isCancelled, motionID == token else { return }
            phase = .connected; cardScale = 1; impactCompression = 1; holderImpact = 0
        }
    }
    private func changeCard(_ direction: Int, selected explicit: HomeBudgetCardModel? = nil) {
        let cards = workspace.cards
        guard let old = card, cards.count > 1, let index = cards.firstIndex(where: { $0.id == old.id }) else { withAnimation(motion(.settle)) { cardDrag = .zero }; return }
        let next = explicit ?? cards[(index + direction + cards.count) % cards.count]
        guard old.id != next.id else { return }
        motionTask?.cancel(); let token = UUID(); motionID = token
        receiptPositions[old.id] = receiptPosition; phase = .changing; contactDate = nil
        flyingCard = old; flightPose = CartridgeFlightPose(x: frontMovement.width, y: cardLift + frontMovement.height, rotation: Double(cardDrag.width / 260) * 6)
        internalSelection = next.id
        stackOrder.removeAll { $0 == next.id || $0 == old.id }; stackOrder.insert(next.id, at: 0); stackOrder.append(old.id)
        workspace.selectedBudgetID = next.id; receiptPosition = receiptPositions[next.id] ?? 0
        var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
        withTransaction(transaction) { cardLift = -8; cardScale = 0.928; cardDrag = .zero }
        PaperHaptics.light()
        if stage == .records {
            flyingCard = nil; phase = .connected; cardLift = 8; cardScale = 1
            return
        }
        withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0.7, 0.3, 1, duration: 0.14)) {
            cardLift = -56; cardScale = 1
            flightPose.x = CGFloat(-direction) * 420; flightPose.y = -75; flightPose.rotation = Double(-direction) * 9
        }
        motionTask = Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(140)) }
            guard !Task.isCancelled, motionID == token else { return }
            flightPose.behind = true
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.1)) {
                flightPose.x = 0; flightPose.y = -68; flightPose.rotation = 0; flightPose.scale = 0.856; flightPose.opacity = 0.32
            }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(100)) }
            guard !Task.isCancelled, motionID == token else { return }
            flyingCard = nil; phase = .detached; insert()
        }
    }
    private func motion(_ kind: CartridgeMotionKind) -> Animation? { reduceMotion ? nil : .spring(response: kind == .settle ? 0.24 : 0.3, dampingFraction: 0.84) }
    private func clamp(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }
    private func bounded(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat { min(maxValue, max(minValue, value)) }
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}

private enum CartridgeDragAxis { case horizontal, vertical }
private enum CartridgeMotionKind { case settle, stage }
private enum CartridgeConnection {
    case connected, detached, inserting, ejecting, changing, charging
    var localization: String.LocalizationValue {
        switch self {
        case .connected, .charging: "native.card.connected"
        case .detached, .ejecting: "native.card.detached"
        case .inserting: "native.card.inserting"
        case .changing: "native.card.changing"
        }
    }
}
private struct CartridgeFlightPose {
    var x: CGFloat = 0
    var y: CGFloat = 8
    var rotation: Double = 0
    var scale: CGFloat = 1
    var opacity: Double = 1
    var behind = false
}
private struct BudgetSheetSelection: Identifiable {
    let id = UUID()
    let budgetID: UUID
    let section: BudgetDetailSection
}

/// The lower translucent tail remains behind the physical mouth of the holder.
private struct CartridgeContactExtension: View {
    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 17, bottomTrailingRadius: 17)
            .fill(LinearGradient(colors: [PaperTheme.card.opacity(0.8), PaperTheme.accent.opacity(0.38), PaperTheme.waterBottom.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { UnevenRoundedRectangle(bottomLeadingRadius: 17, bottomTrailingRadius: 17).strokeBorder(.white.opacity(0.58), lineWidth: 0.8) }
            .shadow(color: PaperTheme.accent.opacity(0.12), radius: 6, y: 4)
            .accessibilityHidden(true)
    }
}
private struct CartridgeFrontLip: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 390, sy = rect.height / 44
        var p = Path(); p.move(to: CGPoint(x: 0, y: 4 * sy))
        p.addCurve(to: CGPoint(x: 75 * sx, y: 34 * sy), control1: CGPoint(x: 18 * sx, y: 2 * sy), control2: CGPoint(x: 28 * sx, y: 34 * sy))
        p.addLine(to: CGPoint(x: 315 * sx, y: 34 * sy))
        p.addCurve(to: CGPoint(x: 390 * sx, y: 4 * sy), control1: CGPoint(x: 362 * sx, y: 34 * sy), control2: CGPoint(x: 372 * sx, y: 2 * sy))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height)); p.addLine(to: CGPoint(x: 0, y: rect.height)); p.closeSubpath(); return p
    }
}
private struct CartridgeLipHighlight: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 390, sy = rect.height / 44
        var p = Path(); p.move(to: CGPoint(x: 0, y: 4 * sy))
        p.addCurve(to: CGPoint(x: 75 * sx, y: 34 * sy), control1: CGPoint(x: 18 * sx, y: 2 * sy), control2: CGPoint(x: 28 * sx, y: 34 * sy))
        p.addLine(to: CGPoint(x: 315 * sx, y: 34 * sy))
        p.addCurve(to: CGPoint(x: 390 * sx, y: 4 * sy), control1: CGPoint(x: 362 * sx, y: 34 * sy), control2: CGPoint(x: 372 * sx, y: 2 * sy)); return p
    }
}

private struct CartridgeContactStamp: View {
    let startedAt: Date
    var body: some View {
        ContactEffectTimeline(startedAt: startedAt, duration: 0.72) { t in
            let stamp = t < 0.054 ? (1.1 - t * 2.13, 0.82 + t * 4.16) : t < 0.166 ? (0.985 + min(1, (t - 0.054) / 0.112) * 0.015, 1.045 - min(1, (t - 0.054) / 0.112) * 0.045) : (1.0, 1.0)
            ZStack {
                CartridgeClickFrame().fill(PaperTheme.card.opacity(0.94))
                CartridgeClickFrame().stroke(PaperTheme.accent.opacity(0.74), lineWidth: 1.5)
                Path { p in p.move(to: CGPoint(x: 18, y: 12)); p.addLine(to: CGPoint(x: 96, y: 12)) }.stroke(.white.opacity(0.85), lineWidth: 1)
                Text(verbatim: "CLICK").font(.system(size: 19, weight: .heavy)).italic().tracking(0.7).padding(.top, 5).foregroundStyle(PaperTheme.accent)
                if t < 0.19 { CartridgeImpactTicks().stroke(PaperTheme.accent.opacity((1 - t / 0.19) * 0.85), style: StrokeStyle(lineWidth: 1.7, lineCap: .round)).scaleEffect(0.96 + t * 0.8) }
            }.rotationEffect(.degrees(-2)).scaleEffect(x: stamp.0, y: stamp.1, anchor: UnitPoint(x: 0.492, y: 0.042))
                .opacity(t < 0.562 ? 1 : max(0, (0.72 - t) / 0.158))
        }
    }
}
private struct CartridgeClickFrame: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x / 128 * r.width, y: y / 48 * r.height) }
        p.move(to: q(17, 10)); p.addQuadCurve(to: q(23, 8), control: q(18, 8)); p.addLine(to: q(51, 8)); p.addLine(to: q(63, 2)); p.addLine(to: q(65, 8)); p.addLine(to: q(116, 8)); p.addQuadCurve(to: q(121, 15), control: q(123, 8)); p.addLine(to: q(115, 40)); p.addQuadCurve(to: q(108, 45), control: q(114, 45)); p.addLine(to: q(11, 45)); p.addQuadCurve(to: q(6, 38), control: q(4, 45)); p.closeSubpath(); return p
    }
}
private struct CartridgeImpactTicks: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for (a, b) in [(CGPoint(x: -4, y: 7), CGPoint(x: 1, y: 11)), (CGPoint(x: -8, y: 23), CGPoint(x: -1, y: 23)), (CGPoint(x: -4, y: 38), CGPoint(x: 1, y: 34)), (CGPoint(x: 116, y: 8), CGPoint(x: 111, y: 12)), (CGPoint(x: 121, y: 24), CGPoint(x: 114, y: 23)), (CGPoint(x: 119, y: 38), CGPoint(x: 114, y: 33))] { p.move(to: a); p.addLine(to: b) }
        return p
    }
}

/// A short, same-clock text entrance. No task survives a changed contact identity.
private struct CartridgeContactEntrance: ViewModifier {
    let startedAt: Date?
    @Environment(\.walletReduceMotion) private var reduceMotion
    @State private var visible = true
    func body(content: Content) -> some View {
        content.opacity(visible ? 1 : 0.12).offset(y: visible ? 0 : 6)
            .task(id: startedAt) {
                guard startedAt != nil, !reduceMotion, Date().timeIntervalSince(startedAt!) < 0.56 else { visible = true; return }
                var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
                withTransaction(transaction) { visible = false }
                guard !Task.isCancelled else { return }
                withAnimation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.56)) { visible = true }
            }
    }
}
private extension View {
    func contactEntrance(_ startedAt: Date?) -> some View { modifier(CartridgeContactEntrance(startedAt: startedAt)) }
}
private struct ArchivedBudgetSheet: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(workspace.ledger.budgets.values.filter { $0.state == .archived }.sorted { $0.sortIndex<$1.sortIndex }) { budget in
                        if let period=workspace.ledger.periods(forBudget: budget.id).last {
                            NavigationLink(value: BudgetWorkspaceRoute.budget(budget.id,period.id,.overview)) {
                                HStack { Text(budget.name).font(.headline);Spacer();Text(period.startDate,format: .dateTime.year().month().day()).font(.caption);Image(systemName: "chevron.right") }.padding(20).walletSurface()
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(22)
            }.background(PaperTheme.canvas.ignoresSafeArea())
                .navigationTitle(String(localized: "ui.directory.archived")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { dismiss() } } }
                .navigationDestination(for: BudgetWorkspaceRoute.self) { BudgetWorkspaceDestination(workspace: workspace,route: $0) }
        }.modifier(NativeDrawerStyle())
    }
}
