import SwiftUI

/// Native counterpart of the approved R34 CircularGallery / DomeGallery chooser.
/// Browsing only changes local focus. The selected budget changes at `onChoose`.
struct CartridgeLibraryView: View {
    @Bindable var workspace: CheckLineWorkspace
    var onChoose: (HomeBudgetCardModel) -> Void
    var onClose: () -> Void
    var onReturnProgress: ((CGFloat) -> Void)? = nil
    var presentationProgress: CGFloat = 1
    var transportsFocusedCard = false
    var onArcPresentation: ((Bool, HomeBudgetCardModel?) -> Void)? = nil

    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var layout: LibraryLayout = .arc
    @State private var searching = false
    @State private var query = ""
    @State private var initialSelectedID: UUID?
    @State private var arcPosition: CGFloat = 0
    @State private var domePosition = CGPoint.zero
    @State private var domeInitialized = false
    @State private var dragOrigin: CGPoint?
    @State private var arcDragAxis: LibraryDragAxis?
    @State private var openedID: UUID?
    @State private var lastDragEnd = Date.distantPast
    @State private var inertia: Task<Void, Never>?
    @State private var returnDistance: CGFloat = 0
    @FocusState private var searchFocused: Bool

    private var staticMode: Bool { reduceMotion || voiceOver || typeSize.isAccessibilitySize }
    private var returnTravel: CGFloat { reduceMotion ? 0 : (1 - min(1, max(0, presentationProgress))) * 140 }
    private var cards: [HomeBudgetCardModel] {
        let source = workspace.cards
        guard let initialSelectedID, let current = source.first(where: { $0.id == initialSelectedID }) else { return source }
        return [current] + source.filter { $0.id != initialSelectedID }
    }
    private var filteredCards: [HomeBudgetCardModel] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? cards : cards.filter { $0.name.localizedCaseInsensitiveContains(text) }
    }

    var body: some View {
        GeometryReader { proxy in
            let footerHeight: CGFloat = 64
            VStack(spacing: 0) {
                header.opacity(Double(presentationProgress))
                if searching { searchField.opacity(Double(presentationProgress)) }
                Group {
                    if searching || staticMode { accessibleGrid.opacity(Double(presentationProgress)) }
                    else if layout == .arc { arcScene }
                    else { domeScene }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityElement(children: .contain)
                .accessibilityLabel(layoutTitle)
                .accessibilityIdentifier("native.library.surface")
                .accessibilityValue(layoutTitle)
                returnGrip
                    .frame(height: footerHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .foregroundStyle(PaperTheme.ink)
            .overlay(alignment: .bottom) {
                if layout == .dome || searching || staticMode {
                HStack(spacing: 0) {
                    Color.clear.frame(width: 22).contentShape(Rectangle()).gesture(returnGesture)
                    Spacer(minLength: 0).allowsHitTesting(false)
                    Color.clear.frame(width: 22).contentShape(Rectangle()).gesture(returnGesture)
                }.frame(height: max(0, proxy.size.height - 58)).accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("native.budget.library")
        .onAppear { initialSelectedID = workspace.selectedBudgetID; publishArcPresentation() }
        .onChange(of: Int(arcPosition.rounded())) { _, _ in publishArcPresentation() }
        .onChange(of: layout) { _, _ in publishArcPresentation() }
        .onChange(of: searching) { _, _ in publishArcPresentation() }
        .onDisappear { stopInertia() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stopInertia(); dragOrigin = nil } }
        .onChange(of: reduceMotion) { _, _ in stopInertia() }
        .onChange(of: cards.map(\.id)) { _, _ in
            stopInertia()
            if let openedID, !cards.contains(where: { $0.id == openedID }) { self.openedID = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(String(localized: "native.library")).font(.headline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                stopInertia(); openedID = nil; searchFocused = false
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.23)) {
                    searching = false
                    layout = layout == .arc ? .dome : .arc
                }
            } label: {
                Image(systemName: layout == .arc ? "square.grid.2x2" : "rectangle.stack")
                    .font(.system(size: 18, weight: .regular)).frame(width: 44, height: 44)
            }
            .accessibilityLabel(String(localized: "native.layout"))
            .accessibilityValue(layoutTitle)
            .accessibilityIdentifier("native.library.layout")
            Button {
                stopInertia(); openedID = nil
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { searching.toggle() }
                searchFocused = searching
            } label: { Image(systemName: "magnifyingglass").font(.system(size: 19)).frame(width: 44, height: 44) }
                .accessibilityLabel(String(localized: "native.search"))
                .accessibilityIdentifier("native.library.search")
            Button { close() } label: { Image(systemName: "chevron.up").font(.system(size: 16, weight: .medium)).frame(width: 44, height: 44) }
                .accessibilityLabel(String(localized: "native.returnBudget"))
                .accessibilityIdentifier("native.library.close")
        }
        .buttonStyle(.plain)
        .foregroundStyle(PaperTheme.accent)
        .padding(.leading, 22).padding(.trailing, 12)
        .frame(minHeight: 52)
    }

    private var searchField: some View {
        TextField(String(localized: "native.search"), text: $query)
            .font(.body).textInputAutocapitalization(.never).autocorrectionDisabled()
            .focused($searchFocused).submitLabel(.search)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(PaperTheme.card.opacity(0.65), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
            .padding(.horizontal, 22).padding(.vertical, 8)
            .accessibilityIdentifier("native.library.searchField")
    }

    private var accessibleGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 270 : 145), spacing: 14)], spacing: 14) {
                ForEach(filteredCards) { card in
                    Button { choose(card) } label: {
                        CartridgeLibraryCard(card: card, expenses: BudgetPresentation.expenses(card, in: workspace.ledger), compact: false)
                            .frame(minHeight: typeSize.isAccessibilitySize ? 230 : 177)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cardLabel(card))
                    .accessibilityIdentifier("native.library.card.\(card.id.uuidString)")
                }
            }.padding(22)
            if filteredCards.isEmpty {
                Text(String(localized: "native.library.noMatch")).foregroundStyle(PaperTheme.muted).padding(28)
            }
        }.scrollDismissesKeyboard(.interactively)
    }

    private var arcScene: some View {
        GeometryReader { proxy in
            let width = min(356, proxy.size.width * 0.82)
            let height = min(width * 0.75, proxy.size.height * 0.74)
            let cardWidth = min(width, height * 4 / 3)
            let pitch = cardWidth * 0.75
            let middle = Int(arcPosition.rounded())
            let slots = cards.count > 1 ? Array((middle - 3)...(middle + 3)) : cards.isEmpty ? [] : [0]
            ZStack {
                ForEach(slots, id: \.self) { slot in
                    let index = wrappedIndex(slot, count: cards.count)
                    let card = cards[index]
                    let delta = CGFloat(slot) - arcPosition
                    let x = delta * pitch
                    let radius = max(proxy.size.width * 1.25, 520)
                    let reach = min(abs(x), radius * 0.82)
                    let y = -(radius - sqrt(radius * radius - reach * reach))
                    let angle = -atan2(x, radius) * 180 / .pi
                    let centered = abs(delta) < 0.51
                    Button {
                        guard Date().timeIntervalSince(lastDragEnd) > 0.18 else { return }
                        if centered { choose(card) }
                        else { focusArc(slot) }
                    } label: {
                        CartridgeLibraryCard(card: card, expenses: BudgetPresentation.expenses(card, in: workspace.ledger), compact: false)
                            .frame(width: cardWidth, height: height)
                            // Move only the artwork. The enclosing scene and its
                            // gesture owner stay still while the finger is down.
                            .mask {
                                Rectangle().opacity(centered && transportsFocusedCard ? 0 : 1)
                                    .transaction { $0.animation = nil }
                            }
                            .offset(y: returnTravel)
                            .opacity(Double(presentationProgress))
                            .contentShape(RoundedRectangle(cornerRadius: 26))
                    }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(cardLabel(card))
                        .accessibilityValue(String(localized: centered ? "native.library.focus" : "native.library.side"))
                        .accessibilityIdentifier("native.library.card.\(card.id.uuidString).slot.\(slot)")
                        .accessibilityHidden(abs(delta) > 1.5)
                        .scaleEffect(1 - min(0.24, abs(delta) * 0.085))
                        .rotationEffect(.degrees(Double(angle)))
                        .rotation3DEffect(.degrees(Double(-delta * 7)), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                        .opacity(max(0.1, 1 - Double(abs(delta)) * 0.55))
                        .blur(radius: centered ? 0 : min(1, abs(delta) * 0.5))
                        // Position the semantic Button itself, not only its painted
                        // GeometryReader label. Each slot owns its actual touch/AX frame.
                        .position(x: proxy.size.width / 2 + x,
                                  y: proxy.size.height / 2 + y + min(8, abs(delta) * 4))
                        .zIndex(20 - Double(abs(delta)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .highPriorityGesture(arcGesture(pitch: pitch))
            .accessibilityElement(children: .contain)
            .accessibilityScrollAction { edge in
                if edge == .trailing { focusArc(Int(arcPosition.rounded()) + 1) }
                if edge == .leading { focusArc(Int(arcPosition.rounded()) - 1) }
            }
            .mask { Rectangle().fill(.linearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.09), .init(color: .black, location: 0.91), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)) }
        }
    }

    private func arcGesture(pitch: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                if arcDragAxis == nil {
                    if abs(value.translation.width) > abs(value.translation.height) * 1.15 {
                        arcDragAxis = .horizontal
                        stopInertia(); dragOrigin = CGPoint(x: arcPosition, y: 0)
                    } else if value.translation.height > abs(value.translation.width) * 1.15 {
                        arcDragAxis = .returnToBudget
                    } else { return }
                }
                if arcDragAxis == .returnToBudget { trackReturn(value.translation) }
                else { arcPosition = (dragOrigin?.x ?? arcPosition) - value.translation.width / max(1, pitch) }
            }
            .onEnded { value in
                let axis = arcDragAxis
                arcDragAxis = nil
                if axis == .returnToBudget { finishReturn(value.translation); return }
                guard dragOrigin != nil else { return }
                dragOrigin = nil
                lastDragEnd = Date()
                let momentum = (value.predictedEndTranslation.width - value.translation.width) / max(1, pitch)
                let target = Int((arcPosition - min(1.65, max(-1.65, momentum * 0.42))).rounded())
                focusArc(target)
            }
    }

    private func focusArc(_ slot: Int) {
        guard !cards.isEmpty else { return }
        stopInertia()
        PaperHaptics.selection()
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88)) { arcPosition = CGFloat(slot) }
    }

    private var domeScene: some View {
        GeometryReader { proxy in
            let metrics = LibraryDomeMetrics(count: cards.count, size: proxy.size)
            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let place = metrics.position(index: index, offset: domePosition)
                    CartridgeLibraryCard(card: card, expenses: BudgetPresentation.expenses(card, in: workspace.ledger), compact: true)
                        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
                        .offset(y: returnTravel)
                        .rotation3DEffect(.degrees(place.angleY), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                        .rotation3DEffect(.degrees(place.angleX), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
                        .scaleEffect(place.scale)
                        .offset(x: place.x, y: place.y)
                        .opacity(place.opacity * Double(presentationProgress))
                        .zIndex(place.depth)
                        .allowsHitTesting(place.opacity > 0.2 && openedID == nil)
                        .onTapGesture {
                            guard Date().timeIntervalSince(lastDragEnd) > 0.18 else { return }
                            stopInertia()
                            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88)) { openedID = card.id }
                            PaperHaptics.selection()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(cardLabel(card))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("native.library.card.\(card.id.uuidString)")
                        .accessibilityHidden(place.opacity < 0.2 || openedID != nil)
                }
                if let openedID, let card = cards.first(where: { $0.id == openedID }) {
                    domeFocusedCard(card, size: proxy.size)
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                        .zIndex(100)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(domeGesture, including: openedID == nil ? .all : .subviews)
            .onAppear {
                guard !domeInitialized else { return }
                if !metrics.compact {
                    domePosition = CGPoint(x: CGFloat(metrics.columns - 1) * metrics.pitchX / 2,
                                           y: CGFloat(metrics.rows - 1) * metrics.pitchY / 2)
                }
                domeInitialized = true
            }
            .accessibilityElement(children: .contain)
            .accessibilityScrollAction { edge in
                stopInertia()
                withAnimation(.easeOut(duration: 0.2)) {
                    switch edge {
                    case .top: domePosition.y += metrics.pitchY
                    case .bottom: domePosition.y -= metrics.pitchY
                    case .leading: domePosition.x += metrics.pitchX
                    case .trailing: domePosition.x -= metrics.pitchX
                    @unknown default: break
                    }
                }
            }
            .mask {
                Rectangle().fill(.linearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.08), .init(color: .black, location: 0.9), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            }
        }
    }

    private var domeGesture: some Gesture {
        DragGesture(minimumDistance: 7, coordinateSpace: .global)
            .onChanged { value in
                guard openedID == nil else { return }
                if dragOrigin == nil { stopInertia(); dragOrigin = domePosition }
                let start = dragOrigin ?? domePosition
                domePosition = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
            }
            .onEnded { value in
                guard dragOrigin != nil else { return }
                dragOrigin = nil; lastDragEnd = Date()
                let velocity = CGPoint(x: min(13, max(-13, (value.predictedEndTranslation.width - value.translation.width) * 0.09)),
                                       y: min(13, max(-13, (value.predictedEndTranslation.height - value.translation.height) * 0.09)))
                runInertia(velocity)
            }
    }

    private func domeFocusedCard(_ card: HomeBudgetCardModel, size: CGSize) -> some View {
        ZStack {
            PaperTheme.canvas.opacity(0.86)
            VStack(spacing: 24) {
                CartridgeLibraryCard(card: card, expenses: BudgetPresentation.expenses(card, in: workspace.ledger), compact: false)
                    .frame(width: min(340, size.width * 0.84), height: min(255, size.width * 0.63))
                HStack(spacing: 12) {
                    Button(String(localized: "native.library.useCard")) { choose(card) }
                        .buttonStyle(PaperSolidButtonStyle(background: PaperTheme.accent))
                        .accessibilityIdentifier("native.library.useCard")
                    Button(String(localized: "action.back")) {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { openedID = nil }
                    }.buttonStyle(PaperQuietButtonStyle())
                }.padding(.horizontal, 28)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var returnGrip: some View {
        ZStack {
            Color.clear.contentShape(Rectangle())
            Button { close() } label: {
                Image(systemName: "chevron.down").font(.system(size: 19, weight: .medium))
                    .foregroundStyle(PaperTheme.accent.opacity(0.72))
                    .opacity(Double(presentationProgress))
                    .frame(width: 52, height: 52).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .offset(y: min(10, returnDistance * 0.13))
                .accessibilityLabel(String(localized: "native.returnBudget"))
                .accessibilityIdentifier("native.library.returnButton")
            HStack {
                Spacer()
                Text(String(format: String(localized: "native.cardCount"), cards.count))
                    .font(.caption).foregroundStyle(PaperTheme.muted.opacity(0.7))
                    .opacity(Double(presentationProgress))
            }.padding(.horizontal, 24).allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(returnGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "native.returnBudget"))
        .accessibilityHint(String(localized: "native.library.dragReturn"))
        .accessibilityAction { close() }
        .accessibilityIdentifier("native.library.return")
    }

    private var returnGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) * 1.2 else { return }
                trackReturn(value.translation)
            }
            .onEnded { value in finishReturn(value.translation) }
    }

    private func trackReturn(_ translation: CGSize) {
        stopInertia()
        returnDistance = min(180, max(0, translation.height))
        onReturnProgress?(returnDistance / 180)
    }

    private func finishReturn(_ translation: CGSize) {
        lastDragEnd = Date()
        let committed = translation.height > 64 && translation.height > abs(translation.width) * 1.2
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88)) {
            returnDistance = 0
            if committed { close() } else { onReturnProgress?(0) }
        }
    }

    private func runInertia(_ initialVelocity: CGPoint) {
        stopInertia()
        guard !reduceMotion, scenePhase == .active else { return }
        inertia = Task { @MainActor in
            var velocity = initialVelocity
            while !Task.isCancelled && hypot(velocity.x, velocity.y) > 0.15 {
                velocity.x *= 0.89; velocity.y *= 0.89
                domePosition.x += velocity.x; domePosition.y += velocity.y
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
        }
    }

    private func stopInertia() { inertia?.cancel(); inertia = nil }
    private func publishArcPresentation() {
        let card = cards.isEmpty ? nil : cards[wrappedIndex(Int(arcPosition.rounded()), count: cards.count)]
        onArcPresentation?(layout == .arc && !searching && !staticMode, card)
    }
    private var layoutTitle: String { String(localized: layout == .arc ? "native.library.arc" : "native.library.dome") }
    private func close() { stopInertia(); searchFocused = false; onClose() }
    private func choose(_ card: HomeBudgetCardModel) { stopInertia(); searchFocused = false; onChoose(card) }
    private func wrappedIndex(_ index: Int, count: Int) -> Int { guard count > 0 else { return 0 }; return ((index % count) + count) % count }
    private func cardLabel(_ card: HomeBudgetCardModel) -> String {
        card.name + ", " + MoneyFormat.string(BudgetPresentation.remaining(card), currencyCode: card.currencyCode)
    }
}

private enum LibraryLayout: String { case arc, dome }
private enum LibraryDragAxis { case horizontal, returnToBudget }

/// Uniform periodic surface, matching the R34 source's pitch and independent X/Y wrap.
/// Low counts deliberately occupy multiple rows, rather than a single ribbon.
struct LibraryDomeMetrics {
    var count: Int
    var size: CGSize
    var compact: Bool { count <= 8 }
    var columns: Int {
        guard count > 0 else { return 1 }
        if compact { return count <= 4 ? max(1, Int(ceil(Double(count) / 2))) : count <= 6 ? 2 : 3 }
        return [8, 6, 5, 4, 3, 2].first { count % $0 == 0 && CGFloat($0) <= sqrt(CGFloat(count) * 1.7) } ?? min(count, 4)
    }
    var rows: Int { max(1, Int(ceil(CGFloat(count) / CGFloat(columns)))) }
    var cardWidth: CGFloat { min(148, max(126, size.width * 0.35)) }
    var cardHeight: CGFloat { cardWidth * 0.75 }
    var pitchX: CGFloat { compact ? cardWidth + 29 : max(CGFloat(columns) * (cardWidth + 29), size.width + 224) / CGFloat(columns) }
    var pitchY: CGFloat { compact ? cardHeight + 25 : max(CGFloat(rows) * (cardHeight + 25), size.height + 104) / CGFloat(rows) }
    var periodX: CGFloat { compact ? ceil((size.width + 224) / pitchX) * pitchX : CGFloat(columns) * pitchX }
    var periodY: CGFloat { compact ? ceil((size.height + 104) / pitchY) * pitchY : CGFloat(rows) * pitchY }

    func position(index: Int, offset: CGPoint) -> LibraryDomePosition {
        let column = index % columns
        let row = index / columns
        let rowColumns = compact ? min(columns, count - row * columns) : columns
        let x = wrap((CGFloat(column) - CGFloat(rowColumns - 1) / 2) * pitchX + offset.x, period: periodX)
        let y = wrap((CGFloat(row) - CGFloat(rows - 1) / 2) * pitchY + offset.y, period: periodY)
        let radius = max(500, size.width * 1.25)
        let ax = x / radius, ay = y / radius
        let edgeX = (size.width / 2 + 85 - abs(x)) / 100
        let edgeY = (size.height / 2 + 90 - abs(y)) / 110
        let opacity = max(0, min(1, edgeX, edgeY))
        let visible = abs(ax) < 1.35 && abs(ay) < 1.25
        let depth = cos(ax) * cos(ay)
        let rise = y > size.height / 2 - 85 ? (1 - opacity) * 15 : 0
        return LibraryDomePosition(x: radius * sin(ax) * cos(ay), y: radius * sin(ay) + rise,
                                   angleX: Double(-ay * 180 / .pi), angleY: Double(ax * 180 / .pi),
                                   scale: 0.82 + max(0, depth) * 0.18,
                                   opacity: visible ? Double(opacity) : 0, depth: Double(depth) * 100)
    }
    private func wrap(_ value: CGFloat, period: CGFloat) -> CGFloat {
        let positive = (value + period / 2).truncatingRemainder(dividingBy: period)
        return (positive < 0 ? positive + period : positive) - period / 2
    }
}

struct LibraryDomePosition {
    var x: CGFloat
    var y: CGFloat
    var angleX: Double
    var angleY: Double
    var scale: CGFloat
    var opacity: Double
    var depth: Double
}

/// Glass card content is shared by both layouts; monetary values remain Decimal.
struct CartridgeLibraryCard: View {
    var card: HomeBudgetCardModel
    var expenses: [Expense]
    var compact: Bool

    var body: some View {
        GeometryReader { proxy in
            let small = compact || proxy.size.width < 220
            let inset: CGFloat = small ? 12 : 20
            ZStack {
                CartridgeLibraryWater(level: CGFloat(BudgetPresentation.fill(card)))
                    .fill(LinearGradient(colors: [PaperTheme.waterTop.opacity(0.8), PaperTheme.waterBottom.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: small ? 5 : 10) {
                    Text(card.name).font(.system(size: small ? 13 : 19, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 2)
                    Text(MoneyFormat.string(BudgetPresentation.remaining(card), currencyCode: card.currencyCode))
                        .font(.system(size: small ? 23 : 38, weight: .medium)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.38).frame(maxWidth: .infinity, alignment: .trailing)
                    HStack(spacing: 3) {
                        symbolCollection(small: small).fixedSize(horizontal: true,vertical: false)
                        Spacer(minLength: 2)
                        Text(MoneyFormat.string(-BudgetPresentation.used(card), currencyCode: card.currencyCode))
                            .font(.system(size: small ? 9 : 12, weight: .medium)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .padding(.horizontal, small ? 5 : 8).padding(.vertical, small ? 4 : 6)
                            .background(PaperTheme.card.opacity(0.44), in: Capsule())
                    }
                }.padding(inset)
            }
            .modifier(NativeGlassCard(radius: small ? 18 : 27))
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: small ? 16 : 25).trim(from: 0.49, to: 0.89)
                    .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .padding(5).allowsHitTesting(false)
            }
        }
        .foregroundStyle(PaperTheme.ink)
        .accessibilityElement(children: .ignore)
    }

    private func symbolCollection(small: Bool) -> some View {
        HStack(spacing: small ? -5 : -7) {
            ForEach(Array(expenses.prefix(3))) { expense in
                CheckLineIcon(symbol: BudgetPresentation.symbol(for: expense), size: small ? 8 : 11)
                    .frame(width: small ? 17 : 25, height: small ? 17 : 25)
                    .background(PaperTheme.card.opacity(0.85), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.75), lineWidth: 0.8))
            }
            if expenses.count > 3 {
                Text("+\(expenses.count - 3)")
                    .font(.system(size: small ? 8 : 10, weight: .medium)).monospacedDigit()
                    .padding(.horizontal, small ? 5 : 7).frame(height: small ? 17 : 25)
                    .background(PaperTheme.card.opacity(0.9), in: Capsule())
            }
        }.accessibilityHidden(true)
    }
}

private struct CartridgeLibraryWater: Shape {
    var level: CGFloat
    func path(in rect: CGRect) -> Path {
        guard level > 0 else { return Path() }
        let y = rect.height * (1 - min(1, level))
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addCurve(to: CGPoint(x: rect.width, y: y), control1: CGPoint(x: rect.width * 0.35, y: y - 10), control2: CGPoint(x: rect.width * 0.62, y: y + 10))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
