import SwiftUI

struct CartridgeBudgetHomeView: View {
    @Bindable var workspace: CheckLineWorkspace
    @Environment(\.shellChrome) private var chrome
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var stage: BudgetStage = .dashboard
    @State private var stageTransitioning = false
    @State private var stageTransitionID = UUID()
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.34,dampingFraction: 0.88))) private var holderDrag = CGSize.zero
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.28,dampingFraction: 0.8))) private var cardDrag = CGSize.zero
    @State private var inserted = true
    @State private var insertionDate: Date? = Date()
    @State private var receiptPosition = 0
    @State private var showUnbudgeted = false
    @State private var showArchive = false
    @State private var detail: BudgetSheetSelection?
    @State private var selectedExpense: Expense?
    @State private var spherical = false
    @State private var libraryOffset: CGFloat = 0
    @GestureState private var libraryDrag = CGSize.zero
    @State private var switchDirection = 1
    @State private var search = ""
    @State private var searching = false
    private var card: HomeBudgetCardModel? { workspace.selectedCard }
    private var position: CGFloat { stage.position(translation: holderDrag) }
    private var recordProgress: CGFloat { max(0,-position) }
    private var libraryProgress: CGFloat { max(0,position) }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperTheme.canvas.ignoresSafeArea()
                GeometryReader { proxy in
                    if let card { budgetStage(card, size: proxy.size) }
                    else {
                        VStack(spacing: 24) {
                            WalletEmptyBudgetCard { workspace.openComposer(.budget) }
                            Button(String(localized: "wallet.empty.manual")) { workspace.openComposer(.budget) }.buttonStyle(PaperQuietButtonStyle())
                            if workspace.ledger.budgets.values.contains(where: { $0.state == .archived }) { Button(String(localized: "ui.directory.archived")) { showArchive=true }.frame(minHeight: 44) }
                        }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity,maxHeight: .infinity)
                    }
                }
            }
            .safeAreaInset(edge: .top,spacing: 0) { header }
            .safeAreaInset(edge: .bottom,spacing: 0) { Color.clear.frame(height: WalletTabTransition.usesSystemBar ? 8 : 88) }
            .toolbar(.hidden,for: .navigationBar)
            .toolbar(WalletTabTransition.usesSystemBar ? .visible : .hidden,for: .tabBar)
            .toolbar(.hidden,for: .bottomBar)
            .sheet(item: $detail, onDismiss: { chrome?.isShowingDetail = false }) { selected in
                BudgetDetailSheet(workspace: workspace,budgetID: selected.budgetID,initialSection: selected.section).modifier(NativeDrawerStyle())
            }
            .sheet(item: $selectedExpense) { expense in
                NavigationStack { WalletExpenseDetail(workspace: workspace,expenseID: expense.id) }.modifier(NativeDrawerStyle())
            }
            .sheet(isPresented: $showUnbudgeted,onDismiss: { chrome?.isShowingDetail=false }) {
                NavigationStack { UnbudgetedRecordsView(workspace: workspace).navigationDestination(for: BudgetWorkspaceRoute.self) { BudgetWorkspaceDestination(workspace: workspace,route: $0) }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "action.close")) { showUnbudgeted=false } } } }.modifier(NativeDrawerStyle())
            }
            .sheet(isPresented: $showArchive,onDismiss: { chrome?.isShowingDetail=false }) { ArchivedBudgetSheet(workspace: workspace) }
            .onAppear { chrome?.isShowingDetail = false }
            .onChange(of: card?.id) { _,_ in receiptPosition = 0; insert(haptic: false) }
            .onChange(of: chrome?.workspaceRequest?.id) { _,_ in
                guard let chrome, let request = chrome.workspaceRequest else { return }
                switch request.route {
                case .budget(let id,_,let section): detail = BudgetSheetSelection(budgetID: id,section: section)
                case .expense(let id): selectedExpense = workspace.ledger.expenses[id]
                case .unbudgeted: showUnbudgeted=true
                }
                chrome.workspaceRequest = nil
            }
        }
    }

    private var header: some View {
        HStack {
            Text(String(localized: "tab.budgets")).font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { workspace.openComposer(.budget) } label: { Image(systemName: "plus").frame(width: 44,height: 44).paperGlass(.circle,interactive: true) }
                .accessibilityLabel(String(localized: "v1.budget.create")).accessibilityIdentifier("wallet.header.create")
            Button { chrome?.isSettingsPresented = true } label: { Image(systemName: "gearshape").frame(width: 44,height: 44).paperGlass(.circle,interactive: true) }
                .accessibilityLabel(String(localized: "tab.settings")).accessibilityIdentifier("wallet.profile")
        }.font(.title3).foregroundStyle(PaperTheme.ink).padding(.horizontal,22).padding(.vertical,8).frame(maxWidth: 604).frame(maxWidth: .infinity)
    }

    private func budgetStage(_ card: HomeBudgetCardModel,size: CGSize) -> some View {
        let height = max(400,size.height)
        let width = min(560,size.width)
        let cardHeight: CGFloat = min(typeSize.isAccessibilitySize ? 325 : 266,height*0.43)
        let pocketTop = cardHeight-10
        let records = BudgetPresentation.expenses(card,in: workspace.ledger)
        return ZStack(alignment: .top) {
            if recordProgress > 0 {
                ScrollView {
                    VStack(alignment: .leading,spacing: 12) {
                        if records.isEmpty { Text(String(localized: "wallet.records.empty")).foregroundStyle(PaperTheme.muted).padding(.vertical,32) }
                        ForEach(recordDays(records),id: \.self) { day in
                            Text(day,format: .dateTime.month().day()).font(.caption).foregroundStyle(PaperTheme.muted).padding(.top,10)
                            ForEach(records.filter { Calendar.current.isDate($0.occurredAt,inSameDayAs: day) }) { expense in
                                Button { selectedExpense = expense } label: { WalletReceiptCard(expense: expense,depth: 0).padding(.vertical,7).walletSurface(radius: 22) }.buttonStyle(.plain)
                            }
                        }
                    }.padding(.horizontal,22).padding(.top,94).padding(.bottom,100)
                }.opacity(Double(recordProgress)).offset(y: (1-recordProgress)*65)
                    .accessibilityIdentifier("native.budget.records")
            }
            if libraryProgress > 0 { library(size: CGSize(width: width,height: height)).opacity(Double(libraryProgress)).offset(y: (1-libraryProgress)*(-55)) }

            // The entire pocket retreats to the bottom while the selected content occupies the center.
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    WalletCardholderSurface(opening: 1)
                    if recordProgress < 0.8 && libraryProgress < 0.8 {
                        summary(card).frame(height: max(0,lerp(height-pocketTop,82,max(recordProgress,libraryProgress))-44)).padding(.horizontal,22).padding(.top,44)
                            .opacity(Double((1-recordProgress)*(1-libraryProgress)))
                    }
                    // Explicit border targets sit above the inner scroll view. Its pan recognizer
                    // must not swallow drags that begin on the holder's empty frame.
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 44).contentShape(Rectangle()).gesture(holderGesture)
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 25).contentShape(Rectangle()).gesture(holderGesture)
                            Spacer(minLength: 0).allowsHitTesting(false)
                            Color.clear.frame(width: 25).contentShape(Rectangle()).gesture(holderGesture)
                        }
                        Color.clear.frame(height: 32).contentShape(Rectangle()).gesture(holderGesture)
                    }
                    HStack {
                        levelButton(symbol: "chevron.up",enabled: stage != .records) { setStage(stage == .library ? .dashboard : .records) }
                        Spacer()
                        levelButton(symbol: "chevron.down",enabled: stage != .library) { setStage(stage == .records ? .dashboard : .library) }
                    }.padding(.horizontal,10).padding(.top,4)
                }
            }
            .frame(width: width,height: lerp(height-pocketTop,82,max(recordProgress,libraryProgress)))
            .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "native.holder"))
            .accessibilityIdentifier("native.holder.surface")
            .accessibilityValue(stageTransitioning ? String(localized: "native.holder.moving") : String(localized: "native.holder.ready"))
            .accessibilityActions {
                Button(String(localized: "native.records")) { setStage(.records) }
                Button(String(localized: "native.library")) { setStage(.library) }
                Button(String(localized: "native.returnBudget")) { setStage(.dashboard) }
            }
            .offset(y: lerp(pocketTop,height-78,max(recordProgress,libraryProgress)))
            .zIndex(2)

            if libraryProgress < 0.9 {
                ZStack(alignment: .bottomLeading) {
                    if workspace.cards.count > 1 && recordProgress < 0.3 {
                        RoundedRectangle(cornerRadius: 28).fill(PaperTheme.accent.opacity(0.15)).padding(.horizontal,8).rotationEffect(.degrees(-2.5)).offset(y: -8)
                    }
                    cartridge(card,compact: recordProgress)
                        .id(card.id)
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .offset(x: CGFloat(switchDirection)*45,y: -10).combined(with: .opacity),removal: .offset(x: CGFloat(-switchDirection)*260,y: -18).combined(with: .opacity)))
                    if recordProgress < 0.1 {
                        Button { workspace.openComposer(.record,budgetID: card.id) } label: {
                            Image(systemName: "plus").font(.title2).frame(width: 48,height: 48)
                                .background(.white.opacity(0.16),in: Circle()).overlay(Circle().stroke(.white.opacity(0.6),lineWidth: 1))
                        }.buttonStyle(.plain).padding(20).accessibilityLabel(String(localized: "capture.title")).accessibilityIdentifier("wallet.home.capture")
                    }
                }
                .frame(width: width-40,height: lerp(cardHeight,62,recordProgress))
                .rotationEffect(.degrees(Double(cardDrag.width/25)))
                .offset(x: cardDrag.width*0.7,y: lerp(inserted ? 8 : -22,8,recordProgress)+min(0,cardDrag.height)*0.65)
                .scaleEffect(1-libraryProgress*0.07)
                .opacity(Double(1-libraryProgress))
                .zIndex(1 + Double(recordProgress)*3)
                .contentShape(RoundedRectangle(cornerRadius: 28))
                .onTapGesture {
                    guard !stageTransitioning else { return }
                    if stage == .records { return }
                    if inserted { open(card,.overview) } else { insert() }
                }
                .highPriorityGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in if stage == .dashboard { eject() } })
                .simultaneousGesture(DragGesture(minimumDistance: 14)
                    .updating($cardDrag) { value,state,_ in
                        if stage == .dashboard { state = value.translation }
                    }.updating($holderDrag) { value,state,_ in
                        if stage == .records { state = value.translation }
                    }.onEnded { value in
                        if stage == .records { setStage(stage.destination(translation: value.translation,predicted: value.predictedEndTranslation)); return }
                        guard stage == .dashboard else { return }
                        if abs(value.translation.width) > 55 && abs(value.translation.width) > abs(value.translation.height) { changeCard(value.translation.width < 0 ? 1 : -1) }
                        else if value.translation.height < -45 { eject() }
                    })
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("wallet.home.card")
                .accessibilityActions {
                    Button(String(localized: "wallet.card.details")) { open(card,.overview) }
                    Button(String(localized: "wallet.card.next")) { changeCard(1) }
                    Button(String(localized: "native.eject")) { eject() }
                }
                .overlay(alignment: .bottomTrailing) {
                    if recordProgress == 0, let insertionDate {
                        ClickImpact(startedAt: insertionDate).offset(x: -15,y: 0).allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(width: width,height: height,alignment: .top).frame(maxWidth: .infinity)
        .clipped()
        .transaction { if reduceMotion { $0.disablesAnimations = true; $0.animation = nil } }
        .animation(reduceMotion ? nil : .spring(response: 0.36,dampingFraction: 0.88),value: stage)
        .animation(reduceMotion ? nil : .spring(response: 0.27,dampingFraction: 0.72),value: inserted)
    }

    private func cartridge(_ card: HomeBudgetCardModel,compact: CGFloat) -> some View {
        ZStack {
            NativeLiquidSurface(progress: CGFloat(BudgetPresentation.fill(card)),horizontal: compact > 0.65,burstAt: insertionDate,active: inserted)
            if compact > 0.7 {
                HStack {
                    Text(card.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(MoneyFormat.string(BudgetPresentation.remaining(card),currencyCode: card.currencyCode)).font(.title3.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                }.padding(.horizontal,20)
            } else {
                VStack(alignment: .leading,spacing: 8) {
                    Text(card.name).font(.title2.weight(.semibold)).lineLimit(2)
                    if card.periodState == .pendingSettlement { Text(String(localized: "budget.settling.section")).font(.caption).foregroundStyle(PaperTheme.accent) }
                    else { Text(card.periodStart,format: .dateTime.month().day()).font(.caption).foregroundStyle(PaperTheme.muted) }
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing,spacing: 5) {
                            Text(String(localized: BudgetPresentation.remaining(card) >= 0 ? "v1.card.remaining" : card.snapshot.certainOverrunAmount > 0 ? "wallet.overrun" : "wallet.possibleOverrun")).font(.caption)
                            BudgetRemainingAmountText(card: card,change: workspace.remainingAmountChange,context: RemainingMotionContext(isHomeCurrent: true,isExposed: stage == .dashboard),exposesAmount: true)
                                .font(.system(size: 44,weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
                        }
                    }
                }.padding(22)
            }
        }.modifier(NativeGlassCard()).foregroundStyle(PaperTheme.ink)
    }

    private func summary(_ card: HomeBudgetCardModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Button { open(card,.overview) } label: {
                        VStack(alignment: .leading,spacing: 14) {
                            summaryLabel("v1.card.used")
                            ContactAmountText(value: BudgetPresentation.used(card),currency: card.currencyCode,contact: insertionDate).font(.title2.weight(.medium)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                            BudgetMiniBars(card: card,ledger: workspace.ledger).frame(height: 38)
                        }.padding(17).frame(maxWidth: .infinity,alignment: .leading).walletSurface()
                            .overlay { ComponentLightSweep(startedAt: insertionDate) }
                    }
                    Button { open(card,.calendar) } label: {
                        VStack(alignment: .leading,spacing: 14) {
                            HStack { Text(card.periodStart,format: .dateTime.month(.wide)); Spacer(); Image(systemName: "arrow.up.right").font(.caption) }.font(.caption).foregroundStyle(PaperTheme.muted)
                            HStack(alignment: .bottom,spacing: 6) {
                                MiniBudgetCalendar(card: card,ledger: workspace.ledger).frame(maxWidth: 74)
                                Spacer(minLength: 0)
                                VStack(alignment: .trailing,spacing: 4) {
                                    if let end=card.periodEnd {
                                        Text(max(0,Calendar.current.dateComponents([.day],from: Calendar.current.startOfDay(for: Date()),to: end).day ?? 0),format: .number).font(.title.weight(.medium)).monospacedDigit()
                                        Text(String(localized: "wallet.daysLeft")).font(.caption2)
                                    } else { Image(systemName: "infinity").font(.title2); Text(String(localized: "wallet.noDeadline")).font(.caption2) }
                                }
                            }.frame(height: 65)
                        }.padding(17).frame(maxWidth: .infinity,alignment: .leading).walletSurface()
                            .overlay { ComponentLightSweep(startedAt: insertionDate) }
                    }
                }.buttonStyle(.plain).fixedSize(horizontal: false,vertical: true)
                let pending = BudgetPresentation.pendingCount(card,in: workspace.ledger)
                if pending > 0 {
                    Button { open(card,.pending) } label: {
                        HStack { Text(String(format: String(localized: "wallet.pending.count"),pending)); Spacer(); Text(MoneyFormat.string(card.snapshot.pendingAmount,currencyCode: card.currencyCode)).monospacedDigit(); Image(systemName: "chevron.right") }.font(.subheadline).padding(12)
                    }.buttonStyle(.plain)
                }
                let unbudgeted=workspace.ledger.expenses.values.filter { $0.attributionState == .unbudgeted && $0.wishRedemptionID == nil }.count
                if unbudgeted>0 {
                    Button { showUnbudgeted=true } label: { HStack { Text(String(localized: "v1.unbudgeted")); Spacer(); Text(unbudgeted,format: .number); Image(systemName: "chevron.right") }.font(.subheadline).padding(12) }.buttonStyle(.plain)
                }
                HStack {
                    Text(String(localized: "wallet.home.recent")).font(.headline)
                    Text("\(BudgetPresentation.expenses(card,in: workspace.ledger).count)").font(.caption).foregroundStyle(PaperTheme.muted)
                    Spacer()
                    Button { setStage(.records) } label: { Image(systemName: "arrow.up.right").frame(width: 44,height: 44) }.accessibilityLabel(String(localized: "wallet.records.all"))
                }
                WalletReceiptStack(rows: BudgetPresentation.expenses(card,in: workspace.ledger),position: $receiptPosition) { selectedExpense = $0 }
                if BudgetPresentation.expenses(card,in: workspace.ledger).isEmpty { Text(String(localized: "wallet.records.empty")).font(.subheadline).foregroundStyle(PaperTheme.muted).padding(14) }
            }.padding(.bottom,20)
        }.scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(PaperTheme.ink)
    }

    private func summaryLabel(_ key: String.LocalizationValue) -> some View {
        HStack { Text(String(localized: key)); Spacer(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(PaperTheme.muted) }.font(.caption).foregroundStyle(PaperTheme.muted)
    }

    private func library(size: CGSize) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(localized: "native.library")).font(.headline)
                Spacer()
                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.4)) { spherical.toggle() } } label: { Image(systemName: spherical ? "rectangle.stack" : "square.grid.2x2").frame(width: 44,height: 44) }.accessibilityLabel(String(localized: "native.layout"))
                if workspace.ledger.budgets.values.contains(where: { $0.state == .archived }) { Button { showArchive=true } label: { Image(systemName: "archivebox").frame(width: 44,height: 44) }.accessibilityLabel(String(localized: "ui.directory.archived")) }
                Button { searching.toggle() } label: { Image(systemName: "magnifyingglass").frame(width: 44,height: 44) }.accessibilityLabel(String(localized: "native.search"))
                Button { setStage(.dashboard) } label: { Image(systemName: "xmark").frame(width: 44,height: 44) }.accessibilityLabel(String(localized: "action.close"))
            }.padding(.horizontal,22)
            if searching { TextField(String(localized: "native.search"),text: $search).padding(12).walletSurface(radius: 14).padding(.horizontal,22) }
            let cards = workspace.cards.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            if spherical {
                sphericalCards(cards,size: size)
            } else {
                GeometryReader { proxy in
                    let center = CGFloat(selectedIndex(in: cards)) - (libraryDrag.width/150)
                    ZStack {
                        ForEach(Array(cards.enumerated()),id: \.element.id) { index,item in
                            let d = CGFloat(index)-center
                            if abs(d) < 2.4 {
                                libraryCard(item)
                                    .frame(width: proxy.size.width*0.76,height: min(242,proxy.size.height*0.72))
                                    .scaleEffect(1-min(0.35,abs(d)*0.16))
                                    .rotation3DEffect(.degrees(Double(-d*17)),axis: (x: 0,y: 1,z: 0),perspective: 0.5)
                                    .rotationEffect(.degrees(Double(d*6)))
                                    .offset(x: d*proxy.size.width*0.6,y: abs(d)*20)
                                    .opacity(max(0.08,1-Double(abs(d))*0.58)).blur(radius: abs(d) < 0.5 ? 0 : 0.8)
                                    .zIndex(10-Double(abs(d)))
                                    .onTapGesture { choose(item) }
                            }
                        }
                    }.frame(maxWidth: .infinity,maxHeight: .infinity)
                }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 12)
                    .updating($libraryDrag) { value,state,_ in if abs(value.translation.width)>abs(value.translation.height) { state=value.translation } }
                    .onEnded { value in
                        if abs(value.translation.width)>45 && abs(value.translation.width)>abs(value.translation.height) {
                            let i = selectedIndex(in: cards), n = cards.count
                            if n>0 { workspace.selectedBudgetID=cards[(i+(value.translation.width<0 ? 1 : -1)+n)%n].id }
                        }
                    })
            }
            Image(systemName: "chevron.down").foregroundStyle(PaperTheme.accent).frame(maxWidth: .infinity,minHeight: 60).contentShape(Rectangle()).gesture(returnGesture).accessibilityHidden(true)
            Text(String(format: String(localized: "native.cardCount"),cards.count)).font(.caption).foregroundStyle(PaperTheme.muted)
        }.padding(.bottom,98).frame(height: size.height)
            .simultaneousGesture(returnGesture)
            .accessibilityIdentifier("native.budget.library")
    }

    private func sphericalCards(_ cards: [HomeBudgetCardModel],size: CGSize) -> some View {
        GeometryReader { proxy in
            let columns = max(2,Int(ceil(Double(cards.count)/3)))
            let rows = min(3,max(1,cards.count))
            let cardWidth = min(190,proxy.size.width*0.47)
            let stride = cardWidth+20
            ZStack {
                ForEach(Array(cards.enumerated()),id: \.element.id) { index,item in
                    let row = index%rows, column = index/rows
                    let span = CGFloat(columns)*stride
                    let raw = CGFloat(column)*stride+libraryOffset+libraryDrag.width
                    let wrap = VisualLoop.wrap(raw,span: span)
                    let angle = wrap/max(1,span)*Double.pi*0.62
                    let x = sin(angle)*min(span/1.8,proxy.size.width*0.78)
                    libraryCard(item).frame(width: cardWidth,height: 137)
                        .scaleEffect(1-abs(wrap/max(1,span))*0.3)
                        .rotation3DEffect(.degrees(Double(-wrap/stride)*13),axis: (x: 0,y: 1,z: 0))
                        .offset(x: x,y: CGFloat(row-rows/2)*152+abs(wrap/span)*24)
                        .opacity(0.1+0.9*pow(max(0,1-Double(abs(wrap/span))*2),0.6))
                        .onTapGesture { choose(item) }
                }
            }.frame(maxWidth: .infinity,maxHeight: .infinity)
        }.clipped().contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 12)
            .updating($libraryDrag) { value,state,_ in if abs(value.translation.width)>abs(value.translation.height) { state=value.translation } }
            .onEnded { value in if abs(value.translation.width)>abs(value.translation.height) { libraryOffset += value.translation.width } })
    }

    private func libraryCard(_ card: HomeBudgetCardModel) -> some View {
        VStack(alignment: .leading,spacing: 12) {
            Text(card.name).font(.headline).lineLimit(1)
            Spacer(minLength: 0)
            Text(MoneyFormat.string(BudgetPresentation.remaining(card),currencyCode: card.currencyCode)).font(.title2.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
            HStack(spacing: -7) {
                let expenses = BudgetPresentation.expenses(card,in: workspace.ledger)
                ForEach(Array(expenses.prefix(3))) { expense in
                    Image(systemName: BudgetPresentation.symbol(for: expense)).font(.caption2).frame(width: 25,height: 25).background(PaperTheme.card,in: Circle()).overlay(Circle().stroke(.white.opacity(0.7),lineWidth: 1))
                }
                if expenses.count>3 { Text("+\(expenses.count-3)").font(.caption2).padding(6).background(PaperTheme.card,in: Capsule()) }
                Spacer(minLength: 8)
                Text(MoneyFormat.string(-BudgetPresentation.used(card),currencyCode: card.currencyCode)).font(.caption2).monospacedDigit().lineLimit(1)
            }
        }.padding(18).modifier(NativeGlassCard(radius: 22)).foregroundStyle(PaperTheme.ink)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
    }
    private var holderGesture: some Gesture {
        DragGesture(minimumDistance: 12).updating($holderDrag) { value,state,_ in state=value.translation }.onEnded { value in
            setStage(stage.destination(translation: value.translation,predicted: value.predictedEndTranslation))
        }
    }
    private var returnGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .updating($holderDrag) { value,state,_ in if stage == .library && abs(value.translation.height)>abs(value.translation.width)*1.25 { state=value.translation } }
            .onEnded { value in if abs(value.translation.height)>65 && abs(value.translation.height)>abs(value.translation.width)*1.25 { setStage(.dashboard) } }
    }
    private func levelButton(symbol: String,enabled: Bool,action: @escaping ()->Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13,weight: .semibold)).frame(width: 44,height: 44).background(PaperTheme.card.opacity(0.38),in: Circle()) }
            .buttonStyle(.plain).foregroundStyle(PaperTheme.accent).opacity(enabled ? 1 : 0.25).disabled(!enabled)
            .accessibilityLabel(String(localized: symbol == "chevron.up" ? "native.records" : "native.library"))
            .accessibilityIdentifier(symbol == "chevron.up" ? "native.holder.up" : "native.holder.down")
    }
    private func recordDays(_ expenses: [Expense]) -> [Date] { Array(Set(expenses.map { Calendar.current.startOfDay(for: $0.occurredAt) })).sorted(by: >) }
    private func selectedIndex(in cards: [HomeBudgetCardModel]) -> Int { cards.firstIndex { $0.id == workspace.selectedBudgetID } ?? 0 }
    private func setStage(_ value: BudgetStage) {
        guard stage != value else { return }
        let transitionID=UUID()
        stageTransitionID=transitionID
        stageTransitioning = !reduceMotion
        withAnimation(reduceMotion ? nil : .spring(response: 0.38,dampingFraction: 0.88),completionCriteria: .logicallyComplete) {
            stage=value
        } completion: {
            if stageTransitionID == transitionID { stageTransitioning=false }
        }
    }
    private func choose(_ card: HomeBudgetCardModel) { workspace.selectedBudgetID=card.id; setStage(.dashboard); insert() }
    private func open(_ card: HomeBudgetCardModel,_ section: BudgetDetailSection) {
        guard !stageTransitioning else { return }
        detail=BudgetSheetSelection(budgetID: card.id,section: section)
    }
    private func eject() { inserted=false; PaperHaptics.light() }
    private func insert(haptic: Bool = true) { inserted=true; insertionDate=Date(); if haptic { PaperHaptics.light() } }
    private func changeCard(_ direction: Int) {
        let cards=workspace.cards, n=cards.count; guard n>1 else { return }
        let index=cards.firstIndex { $0.id==workspace.selectedBudgetID } ?? 0
        PaperHaptics.light()
        switchDirection = direction
        withAnimation(reduceMotion ? nil : .spring(response: 0.28,dampingFraction: 0.8)) { workspace.selectedBudgetID=cards[(index+direction+n)%n].id }
    }
    private func lerp(_ a: CGFloat,_ b: CGFloat,_ t: CGFloat) -> CGFloat { a+(b-a)*t }
}

private struct BudgetSheetSelection: Identifiable {
    let id=UUID()
    let budgetID: UUID
    let section: BudgetDetailSection
}

private struct ClickImpact: View {
    var startedAt: Date
    @State private var playing = false
    @Environment(\.walletReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30,paused: !playing)) { clock in
            let t=clock.date.timeIntervalSince(startedAt)
            if t>=0 && t<0.53 && playing && !reduceMotion {
                Text("CLICK").font(.system(size: 20,weight: .black,design: .rounded)).italic()
                    .foregroundStyle(PaperTheme.accent)
                    .padding(.horizontal,11).padding(.vertical,5)
                    .background(PaperTheme.card,in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(PaperTheme.accent.opacity(0.4),lineWidth: 1.5))
                    .rotationEffect(.degrees(-11))
                    .scaleEffect(t<0.08 ? 0.7+t*5 : 1.1-max(0,t-0.08)*0.25)
                    .opacity(t<0.32 ? 1 : (0.53-t)/0.21)
            }
        }.accessibilityHidden(true).task(id: startedAt) {
            let remaining=max(0,0.53-Date().timeIntervalSince(startedAt))
            playing=remaining>0 && !reduceMotion
            do { try await Task.sleep(for: .seconds(remaining));try Task.checkCancellation();playing=false } catch { }
        }
    }
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
