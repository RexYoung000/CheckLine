import SwiftUI
import PhotosUI

struct NativeWishListView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var agentDraftAvailable = false
    @State private var draftKind = "wishCreate"
    @State private var completed = false
    @State private var rows = false
    @State private var adding = false
    @State private var balance = false
    @State private var expanded: Wish?
    @State private var redeeming: Wish?
    @State private var pricing: Wish?
    private var completedCount: Int { workspace.ledger.wishes.values.filter { $0.state == .completed }.count }
    private var wishes: [Wish] {
        workspace.ledger.wishes.values.filter { $0.state == (completed ? .completed : .active) }
            .sorted { lhs,rhs in
                let a=lhs.completedAt ?? lhs.createdAt,b=rhs.completedAt ?? rhs.createdAt
                return a == b ? lhs.id.uuidString < rhs.id.uuidString : a>b
            }
    }

    var body: some View {
        WalletRootPage(tab: .wishes,title: String(localized: "wallet.wishes.title"),workspace: workspace,onAdd: { draftKind="wishCreate"; adding=true }) {
            VStack(spacing: 20) {
                Button { balance=true } label: {
                    let layout=typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading,spacing: 12)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline,spacing: 10))
                    layout {
                        Text(String(localized: "v1.wish.balance")).font(.subheadline).fixedSize(horizontal: false,vertical: true)
                        HStack(alignment: .firstTextBaseline,spacing: 10) {
                            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                            Text(MoneyFormat.string(workspace.wallet.balance,currencyCode: workspace.ledger.walletSettings.walletCurrencyCode)).font(.title.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                            if typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                            Image(systemName: "chevron.right").font(.system(size: 15,weight: .medium))
                        }
                    }.frame(maxWidth: .infinity,alignment: .leading).padding(.horizontal,22).padding(.vertical,23).modifier(NativeGlassCard())
                }.buttonStyle(.plain).accessibilityIdentifier("native.wish.balance")
                if agentDraftAvailable {
                    Button(String(localized: "native.agent.resumeWish")) { draftKind="agentWishCreate"; adding=true }
                        .font(.subheadline).frame(maxWidth: .infinity,alignment: .leading).padding(14).walletSurface(radius: 18)
                }
                HStack(spacing: 14) {
                    Picker(String(localized: "wallet.wishes.title"),selection: $completed) {
                        Text(String(localized: "native.wish.unrealized")).tag(false)
                        Text(String(localized: "native.wish.realized")).tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("native.wish.tabs")
                    Button { rows.toggle() } label: { Image(systemName: rows ? "rectangle.grid.1x2" : "list.bullet").font(.system(size: 19)).frame(width: 44,height: 44) }.accessibilityLabel(String(localized: "native.layout"))
                }
                if wishes.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: completed ? "checkmark.seal" : "heart").font(.system(size: 42,weight: .ultraLight)).foregroundStyle(PaperTheme.accent)
                        Text(String(localized: completed ? "native.wish.realizedEmpty" : "native.wish.empty")).font(.headline)
                        if !completed {
                            Button(String(localized: "wallet.wishes.add")) { adding=true }.buttonStyle(PaperSolidButtonStyle()).accessibilityIdentifier("wallet.wishes.empty.add")
                        }
                    }.padding(.vertical,36)
                }
                LazyVStack(spacing: 20) {
                    ForEach(wishes) { wish in
                        NativeWishCard(workspace: workspace,wish: wish,row: rows,onExpand: { expanded=wish },onRedeem: { redeeming=wish },onPrice: { pricing=wish })
                    }
                }
            }.frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $adding, onDismiss: refreshWishDraft) { CreateWishSheet(workspace: workspace,draftKind: draftKind) }
        .sheet(isPresented: $balance,onDismiss: { chrome?.isShowingDetail=false }) { WishWalletSummaryView(workspace: workspace) }
        .sheet(item: $redeeming) { WishRedemptionView(workspace: workspace,wishID: $0.id).modifier(NativeDrawerStyle()) }
        .sheet(item: $pricing) { WishPriceSheet(workspace: workspace,wish: $0) }
        .fullScreenCover(item: $expanded,onDismiss: { chrome?.isShowingDetail=false }) { ExpandedWishView(workspace: workspace,wishID: $0.id) }
        .onChange(of: completedCount) { old,new in if new>old { completed=true } }
        .onAppear { refreshWishDraft(); if chrome?.wishesShowCompleted == true { completed=true } }
        .onChange(of: chrome?.wishesShowCompleted) { _,value in if value == true { completed=true } }
    }
    private func refreshWishDraft() {
        agentDraftAvailable = (try? workspace.draftStore.load(TaskDraft(kind: "agentWishCreate").key)) != nil
    }
}

struct NativeWishCard: View {
    @Bindable var workspace: CheckLineWorkspace
    let wish: Wish
    var row = false
    var onExpand: ()->Void
    var onRedeem: ()->Void
    var onPrice: ()->Void
    @State private var flipped = false
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    private var cover: WishCover { workspace.wishCovers.cover(for: wish.id,fallback: wish.symbolName) }
    private var ratio: CGFloat? {
        guard let amount=wish.targetAmount,amount>0, (wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode)==workspace.ledger.walletSettings.walletCurrencyCode else { return nil }
        return CGFloat(NSDecimalNumber(decimal: min(1,max(0,workspace.wallet.balance/amount))).doubleValue)
    }
    var body: some View {
        ZStack {
            if reduceMotion {
                if flipped { back } else { front }
            } else {
                front.modifier(WishFlipFace(angle: flipped ? 180 : 0,back: false))
                back.modifier(WishFlipFace(angle: flipped ? 180 : 0,back: true))
            }
        }
        .frame(height: typeSize.isAccessibilitySize ? (row ? 210 : 340) : (row ? 118 : 278))
        .contentShape(RoundedRectangle(cornerRadius: 28))
        .onTapGesture { withAnimation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.58,dampingFraction: 0.82)) { flipped.toggle() } }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: String(localized: "native.wish.flip")) { flipped.toggle() }
        .accessibilityIdentifier("native.wish.card.\(wish.id)")
    }

    private var front: some View {
        ZStack(alignment: .topLeading) {
            WishCoverArtwork(cover: cover,row: row)
            VStack(alignment: .leading,spacing: 12) {
                HStack(alignment: .top) {
                    Text(wish.name).font(row ? .headline : .title3.weight(.semibold)).lineLimit(2)
                    Spacer(minLength: 10)
                    Button(action: onExpand) { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 13)).frame(width: 44,height: 44).background(.ultraThinMaterial,in: Circle()) }
                        .accessibilityLabel(String(localized: "native.wish.expand")).accessibilityIdentifier("native.wish.expand")
                }
                Spacer(minLength: 0)
                HStack {
                    if let price=displayedPrice {
                        Text(MoneyFormat.string(price.amount,currencyCode: price.currencyCode)).font(row ? .subheadline.weight(.medium) : .title2.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    }
                    Spacer()
                    if wish.state == .completed { Image(systemName: "checkmark.seal.fill").foregroundStyle(PaperTheme.accent).accessibilityLabel(String(localized: "wallet.wishes.completed")) }
                }
            }.padding(row ? 14 : 20)
        }.modifier(NativeGlassCard()).foregroundStyle(cover.layout == .fill && cover.imageData != nil ? .white : PaperTheme.ink)
            .accessibilityHidden(flipped)
    }

    private var displayedPrice: (amount: Decimal,currencyCode: String)? {
        if wish.state == .completed,
           let redemption=workspace.ledger.redemptions.values.first(where: { $0.wishID==wish.id && $0.state == .completed }) {
            return (redemption.actualAmount,redemption.currencyCode)
        }
        guard let amount=wish.targetAmount else { return nil }
        return (amount,wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode)
    }
    private var back: some View {
        ZStack {
            if wish.state != .completed { NativeLiquidSurface(progress: ratio ?? 0,horizontal: row,active: flipped) }
            VStack(spacing: row ? 6 : 18) {
                if wish.state == .completed {
                    Image(systemName: "checkmark.seal").font(.title2).foregroundStyle(PaperTheme.accent)
                    if let date=wish.completedAt { Text(date,format: .dateTime.year().month().day()).font(.subheadline) }
                    if let price=displayedPrice { Text(MoneyFormat.string(price.amount,currencyCode: price.currencyCode)).font(.title2).monospacedDigit() }
                } else {
                    if let ratio { Text(ratio,format: .percent.precision(.fractionLength(0))).font(.system(size: row ? 26 : 54,weight: .medium,design: .rounded)).monospacedDigit() }
                    else { Text(String(localized: wish.targetAmount == nil ? "native.wish.noPrice" : "native.wish.noRate")).font(.subheadline).foregroundStyle(PaperTheme.muted) }
                    if !row { Spacer(minLength: 0) }
                    Button(String(localized: "native.wish.redeem"),action: onRedeem)
                        .buttonStyle(PaperSolidButtonStyle(enabled: wish.targetAmount != nil)).disabled(wish.targetAmount == nil)
                        .accessibilityIdentifier("native.wish.redeem")
                    if wish.targetAmount == nil {
                        Button(String(localized: "native.wish.setPrice"),action: onPrice).font(.caption).frame(minHeight: 30)
                            .accessibilityIdentifier("native.wish.fillPrice")
                    }
                }
            }.padding(row ? 12 : 24).padding(.top,row ? 0 : 24)
        }.modifier(NativeGlassCard()).foregroundStyle(PaperTheme.ink)
            .accessibilityHidden(!flipped)
    }
}

private struct WishFlipFace: AnimatableModifier {
    var angle: Double
    var back: Bool
    var animatableData: Double { get { angle } set { angle=newValue } }
    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(back ? 180 : 0),axis: (x: 0,y: 1,z: 0))
            .opacity(back ? (angle>=90 ? 1 : 0) : (angle<90 ? 1 : 0))
            .rotation3DEffect(.degrees(angle),axis: (x: 0,y: 1,z: 0),perspective: 0.5)
            .allowsHitTesting(back ? angle>=90 : angle<90)
    }
}

struct WishCoverArtwork: View {
    var cover: WishCover
    var row = false
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { proxy in
            if cover.imageData != nil,cover.layout != .symbol,let image {
                if cover.layout == .fill {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: proxy.size.width,height: proxy.size.height).clipped()
                        .overlay(LinearGradient(colors: [.black.opacity(0.42),.clear,.black.opacity(0.45)],startPoint: .top,endPoint: .bottom))
                } else {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: row ? 76 : 134,height: row ? 76 : 144).clipShape(RoundedRectangle(cornerRadius: 20))
                        .rotationEffect(.degrees(-7)).shadow(color: .black.opacity(0.1),radius: 12,y: 7)
                        .position(x: proxy.size.width*(row ? 0.73 : 0.64),y: proxy.size.height*0.57)
                }
            } else {
                Image(systemName: cover.symbol).symbolRenderingMode(.hierarchical)
                    .font(.system(size: row ? 35 : 72,weight: .light)).foregroundStyle(PaperTheme.accent)
                    .frame(width: row ? 70 : 128,height: row ? 70 : 134)
                    .background(.white.opacity(0.22),in: RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.45),lineWidth: 1))
                    .rotationEffect(.degrees(-8)).shadow(color: PaperTheme.accent.opacity(0.14),radius: 13,y: 9)
                    .position(x: proxy.size.width*(row ? 0.75 : 0.63),y: proxy.size.height*0.56)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
            .onChange(of: cover.imageData,initial: true) { _,data in image=data.flatMap { UIImage(data: $0) } }
    }
}

struct ExpandedWishView: View {
    @Bindable var workspace: CheckLineWorkspace
    let wishID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var redeem = false
    @State private var price = false
    @State private var coverEditor = false
    var body: some View {
        ZStack {
            Color(red: 0.12,green: 0.10,blue: 0.16).ignoresSafeArea()
            if let wish=workspace.ledger.wishes[wishID] {
                NativeWishCard(workspace: workspace,wish: wish,onExpand: { },onRedeem: { redeem=true },onPrice: { price=true })
                    .frame(maxWidth: 460).padding(24)
                    .sheet(isPresented: $redeem,onDismiss: {
                        // Close the enclosing large card only after the purchase sheet has left.
                        // This also handles a saved celebration dismissed by dragging the sheet.
                        if workspace.ledger.wishes[wishID]?.state == .completed { dismiss() }
                    }) { WishRedemptionView(workspace: workspace,wishID: wishID).modifier(NativeDrawerStyle()) }
                    .sheet(isPresented: $price) { WishPriceSheet(workspace: workspace,wish: wish) }
            }
        }.accessibilityIdentifier("native.wish.expanded")
        .sheet(isPresented: $coverEditor) { WishCoverPicker(store: workspace.wishCovers, wishID: wishID, name: workspace.ledger.wishes[wishID]?.name ?? "") }
        .safeAreaInset(edge: .top) {
            HStack { Button { coverEditor=true } label: { Image(systemName: "photo").frame(width: 44,height: 44).background(.white.opacity(0.12),in: Circle()) }.accessibilityLabel(String(localized: "native.cover.title")); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44,height: 44).background(.white.opacity(0.12),in: Circle()) }.foregroundStyle(.white).accessibilityLabel(String(localized: "action.close")) }.padding(18)
        }
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
                VStack(spacing: 24) {
                    Text(wish.name).font(.title2.weight(.semibold))
                    TextField("0",text: $amount).keyboardType(AmountKeyboard.type).font(.largeTitle).padding(20).walletSurface()
                        .focused($amountFocused).accessibilityLabel(String(localized: "native.wish.setPrice")).accessibilityIdentifier("native.wish.price.amount")
                    CurrencyMenuButton(currency: $currency,preferred: workspace.ledger.walletSettings.walletCurrencyCode)
                    if failed { Text(String(localized: "v1.banner.failed")).foregroundStyle(PaperTheme.accent) }
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    PaperSubmitBar(title: String(localized: "action.save"),enabled: MoneyFormat.parseAmount(amount) != nil) {
                        guard let value=MoneyFormat.parseAmount(amount) else { return }
                        do { try workspace.setWishPrice(wish.id,amount: value,currency: currency); dismiss() } catch { failed=true }
                    }.accessibilityIdentifier("native.wish.price.save").padding(.vertical,12).background(PaperTheme.canvas)
                }
                .navigationTitle(String(localized: "native.wish.setPrice")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(String(localized: "ui.keyboard.done")) { amountFocused=false } }
                }
                .background(PaperTheme.canvas.ignoresSafeArea())
        }.modifier(NativeDrawerStyle()).onAppear { currency=wish.currencyCode ?? workspace.ledger.walletSettings.walletCurrencyCode }
    }
}

struct WishCoverPicker: View {
    @Bindable var store: WishCoverStore
    let wishID: UUID
    var name: String
    @State private var cover = WishCover()
    @State private var photoMode = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var reading = false
    @State private var failed = false
    @State private var iconTurn = 0.0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.walletReduceMotion) private var reduceMotion
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack(alignment: .topLeading) {
                        WishCoverArtwork(cover: cover)
                        Text(name.isEmpty ? String(localized: "wallet.wishes.add") : name).font(.title3.weight(.semibold)).padding(22)
                    }.frame(height: 195).modifier(NativeGlassCard()).rotation3DEffect(.degrees(iconTurn),axis: (x: 0,y: 1,z: 0),perspective: 0.6)
                    Picker(String(localized: "native.cover.title"),selection: $photoMode) {
                        Text(String(localized: "native.cover.presets")).tag(false)
                        Text(String(localized: "native.cover.photos")).tag(true)
                    }.pickerStyle(.segmented)
                    if photoMode {
                        PhotosPicker(selection: $selectedPhoto,matching: .images) {
                            Label(String(localized: "native.cover.choose"),systemImage: "photo.on.rectangle").frame(maxWidth: .infinity,minHeight: 66).walletSurface()
                        }
                        if reading { ProgressView() }
                        Picker(String(localized: "native.cover.layout"),selection: $cover.layout) {
                            Text(String(localized: "native.cover.inset")).tag(WishCover.Layout.inset)
                            Text(String(localized: "native.cover.fill")).tag(WishCover.Layout.fill)
                        }.pickerStyle(.segmented)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(),spacing: 10),count: 4),spacing: 10) {
                            ForEach(WishCoverStore.symbols,id: \.self) { symbol in
                                Button {
                                    cover.symbol=symbol; cover.layout = .symbol
                                    if !reduceMotion { withAnimation(.spring(response: 0.4,dampingFraction: 0.8)) { iconTurn += 360 } }
                                } label: {
                                    Image(systemName: symbol).font(.system(size: 24,weight: .light)).frame(maxWidth: .infinity,minHeight: 64)
                                        .background(PaperTheme.accent.opacity(cover.layout == .symbol && cover.symbol==symbol ? 0.14 : 0.045),in: RoundedRectangle(cornerRadius: 18))
                                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(PaperTheme.accent.opacity(cover.symbol==symbol ? 0.5 : 0),lineWidth: 1))
                                }.accessibilityLabel(String(localized: String.LocalizationValue("native.icon."+symbol)))
                            }
                        }
                    }
                    if failed { Text(String(localized: "native.cover.failed")).font(.subheadline).foregroundStyle(PaperTheme.accent) }
                }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.background(PaperTheme.canvas.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    Button(String(localized: "native.cover.use")) {
                        do { try store.save(cover,for: wishID); dismiss() } catch { failed=true }
                    }.buttonStyle(PaperSolidButtonStyle(enabled: !reading)).disabled(reading).padding(22).background(PaperTheme.canvas)
                }
                .navigationTitle(String(localized: "native.cover.title")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { dismiss() } } }
        }.modifier(NativeDrawerStyle())
            .onAppear { cover=store.cover(for: wishID); photoMode=cover.layout != .symbol }
            .onChange(of: photoMode) { _,value in if value && cover.layout == .symbol { cover.layout = .inset }; if !value { cover.layout = .symbol } }
            .task(id: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                reading=true; failed=false
                defer { if selectedPhoto == item { reading=false } }
                do {
                    guard let data=try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                    let thumbnail=try await Task.detached { try WishCoverStore.thumbnail(data) }.value
                    try Task.checkCancellation()
                    guard selectedPhoto == item else { return }
                    cover.imageData=thumbnail
                    if photoMode && cover.layout == .symbol { cover.layout = .inset }
                } catch is CancellationError { }
                catch { if selectedPhoto == item { failed=true } }
            }
    }
}
