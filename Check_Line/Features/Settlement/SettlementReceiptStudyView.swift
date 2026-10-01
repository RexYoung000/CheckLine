#if DEBUG
import SwiftUI

/// Presentation study only. Fixtures never invoke settlement or mutate a ledger.
struct SettlementReceiptStudyView: View {
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var overrun = false
    @State private var feed: CGFloat = 0
    @State private var printing = false
    @State private var replayID = UUID()
    @State private var paperID = UUID()
    @State private var showingStudy = true
    @State private var viewedResults: Set<Bool> = []
    @State private var detailsExpanded = false
    @State private var showingWallet = false

    private var staticPresentation: Bool { reduceMotion || voiceOver }
    private var result: ReceiptFixture { overrun ? .overrun : .surplus }

    var body: some View {
        NavigationStack {
            Group {
                if showingStudy {
                    ScrollView {
                        VStack(spacing: 20) {
                            heading
                            printer
                        }
                        .frame(maxWidth: 400)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) { controls }
                } else {
                    budgetPreview
                }
            }
            .background(PaperTheme.canvas)
            .foregroundStyle(PaperTheme.ink)
            .navigationTitle(String(localized: showingStudy ? "receipt.study.title" : "receipt.study.budgetPreview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showingStudy && !showingWallet {
                    ToolbarItem(placement: .topBarTrailing) { studyOptions }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { returnToBudget() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel(Text("action.close"))
                            .accessibilityIdentifier("receipt.close")
                    }
                }
            }
            .navigationDestination(isPresented: $showingWallet) { walletPreview }
        }
        .tint(PaperTheme.accent)
        .task(id: replayID) {
            guard showingStudy, printing, !staticPresentation else { return }
            // A replay cancels this task and resets presentation without queuing another feed.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.35)) { feed = 1 }
            try? await Task.sleep(for: .milliseconds(1_350))
            guard !Task.isCancelled else { return }
            printing = false
        }
        .onAppear { presentResult() }
        .onDisappear { finishImmediately() }
        .onChange(of: staticPresentation) { _, _ in finishImmediately() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishImmediately() }
        }
    }

    private var heading: some View {
        VStack(spacing: 8) {
            Label("receipt.study.completed", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PaperTheme.accent)
            Text("wallet.demo.daily").font(PaperTheme.Typography.cardName)
            Text(period)
                .font(.caption)
                .foregroundStyle(PaperTheme.muted)
            Text(overrun ? "wallet.settlement.overrun" : "wallet.settlement.surplus")
                .font(.subheadline).foregroundStyle(PaperTheme.muted)
                .padding(.top, 4)
            Text(money(result.difference))
                .font(PaperTheme.Typography.remaining.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("receipt.amount")
        }
        .accessibilityElement(children: .contain)
    }

    private var period: String {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))!
        return "\(start.formatted(.dateTime.year().month().day())) – \(end.formatted(.dateTime.month().day()))"
    }

    private var printer: some View {
        let progress = feed
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(PaperTheme.accent).frame(width: 5, height: 5).accessibilityHidden(true)
                Text("CheckLine")
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .tracking(1.2)
                    .accessibilityHidden(true)
                Spacer()
                Text(printing ? "receipt.study.printing" : "receipt.study.ready")
                    .font(.caption)
                    .accessibilityIdentifier("receipt.status")
            }
            .foregroundStyle(PaperTheme.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(PaperTheme.pocket, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))

            receipt
                .padding(.horizontal, 10)
                .visualEffect { content, geometry in
                    content.offset(y: -geometry.size.height * (1 - progress))
                }
                .id(paperID)
                .clipped()
                .overlay(alignment: .top) {
                    ZStack(alignment: .top) {
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 22)
                            .padding(.horizontal, 10)
                            .opacity(0.08 + Double(1 - progress) * 0.12)
                        Capsule().fill(Color.black.opacity(0.78)).frame(height: 5)
                            .padding(.horizontal, 5).offset(y: -2)
                    }
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }
        }
        .accessibilityElement(children: .contain)
    }

    private var receipt: some View {
        VStack(spacing: 0) {
            sectionTitle("receipt.study.movements")
            VStack(spacing: 12) {
                row(overrun ? "receipt.study.walletDeducted" : "receipt.study.recoveryFilled", money(result.firstMovement))
                row(overrun ? "receipt.study.recoveryAdded" : "receipt.study.walletAdded", money(result.secondMovement))
            }.padding(.vertical, 14)
            rule
            sectionTitle("receipt.study.after").padding(.top, 16)
            VStack(spacing: 12) {
                row("receipt.study.wallet", money(result.walletAfter))
                    .accessibilityIdentifier("receipt.walletAfter")
                row("receipt.study.recovery", money(result.recoveryAfter))
                    .accessibilityIdentifier("receipt.recoveryAfter")
            }.padding(.vertical, 14)
            rule
            Button {
                finishImmediately()
                withAnimation(staticPresentation ? nil : PaperTheme.Motion.panel) {
                    detailsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(detailsExpanded ? "receipt.study.hideDetails" : "receipt.study.showDetails")
                    Spacer(minLength: 8)
                    Image(systemName: detailsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .font(.subheadline)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(PaperTheme.accent)
            .accessibilityIdentifier("receipt.details")
            .accessibilityValue(Text(detailsExpanded ? "receipt.study.expanded" : "receipt.study.collapsed"))
            if detailsExpanded {
                VStack(spacing: 12) {
                    row("receipt.study.limit", money(3_000)).accessibilityIdentifier("receipt.limitRow")
                    row("wallet.settlement.confirmed", money(result.spent)).accessibilityIdentifier("receipt.spentRow")
                }.padding(.bottom, 12)
            }
            Text("receipt.study.paperNote")
                .font(.caption).foregroundStyle(PaperTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(PaperTheme.card)
        .clipShape(ReceiptPaper())
        .shadow(color: PaperTheme.shadow.opacity(0.55), radius: 9, y: 5)
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.caption.weight(.medium)).foregroundStyle(PaperTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var rule: some View {
        Rectangle().fill(PaperTheme.stroke).frame(height: 1)
            .overlay {
                GeometryReader { proxy in
                    Path { path in
                        path.move(to: .zero); path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
                    }.stroke(PaperTheme.card, style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }
            }.accessibilityHidden(true)
    }

    private func row(_ key: LocalizedStringKey, _ value: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Text(key).font(.subheadline).foregroundStyle(PaperTheme.muted)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(value).font(.system(.subheadline, design: .monospaced).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button("receipt.study.returnBudget") { returnToBudget() }
                .buttonStyle(PaperSolidButtonStyle())
                .accessibilityIdentifier("receipt.returnBudget")
            Button("wallet.settlement.viewWishes") {
                finishImmediately()
                showingWallet = true
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("receipt.viewWallet")
            if staticPresentation {
                Label(voiceOver ? "receipt.study.voiceOver" : "receipt.study.static", systemImage: "figure.stand")
                    .font(.caption).foregroundStyle(PaperTheme.muted)
                    .accessibilityIdentifier("receipt.static")
            }
            Text("receipt.study.disclaimer")
                .font(.caption).foregroundStyle(PaperTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(PaperTheme.canvas)
    }

    private var studyOptions: some View {
        Menu {
            if !staticPresentation {
                Button("receipt.study.replay", systemImage: "arrow.clockwise") { replay() }
                    .accessibilityIdentifier("receipt.replay")
                Button("receipt.study.showAll") { finishImmediately() }
                    .accessibilityIdentifier("receipt.finish")
            }
            Picker("receipt.study.scenario", selection: $overrun) {
                Text("receipt.study.surplusExample").tag(false)
                Text("receipt.study.overrunExample").tag(true)
            }
        } label: { Image(systemName: "ellipsis") }
        .accessibilityLabel(Text("receipt.study.options"))
        .accessibilityIdentifier("receipt.options")
        .onChange(of: overrun) { _, _ in
            detailsExpanded = false
            presentResult()
        }
    }

    private var budgetPreview: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.text").font(.largeTitle).foregroundStyle(PaperTheme.accent)
            Text("wallet.demo.daily").font(PaperTheme.Typography.title)
            Text(period).font(.subheadline).foregroundStyle(PaperTheme.muted)
            Label("receipt.study.completed", systemImage: "checkmark.circle")
                .foregroundStyle(PaperTheme.accent)
            Button("receipt.study.open") {
                showingStudy = true
                presentResult()
            }
            .buttonStyle(PaperSolidButtonStyle())
            .accessibilityIdentifier("receipt.open")
            Text("receipt.study.disclaimer").font(.caption).foregroundStyle(PaperTheme.muted)
            Spacer()
        }.frame(maxWidth: 400).padding(24).frame(maxWidth: .infinity)
    }

    private var walletPreview: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("receipt.study.wallet").font(PaperTheme.Typography.title)
                Text(money(result.walletAfter)).font(PaperTheme.Typography.remaining).monospacedDigit()
                    .accessibilityIdentifier("receipt.walletPreviewAmount")
                row("receipt.study.recovery", money(result.recoveryAfter))
                Text("receipt.study.paperNote").font(.subheadline).foregroundStyle(PaperTheme.muted)
                Text("receipt.study.disclaimer").font(.caption).foregroundStyle(PaperTheme.muted)
                Button("receipt.study.backToReceipt") { showingWallet = false }
                    .buttonStyle(PaperSolidButtonStyle())
                    .accessibilityIdentifier("receipt.backFromWallet")
            }.frame(maxWidth: 400).padding(24).frame(maxWidth: .infinity)
        }
        .background(PaperTheme.canvas)
        .foregroundStyle(PaperTheme.ink)
        .navigationTitle(String(localized: "receipt.study.walletPreview"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func returnToBudget() {
        finishImmediately()
        showingStudy = false
    }

    private func presentResult() {
        let isFirstView = viewedResults.insert(overrun).inserted
        if isFirstView { replay() }
        else { finishImmediately() }
    }

    private func replay() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            feed = staticPresentation ? 1 : 0
            printing = !staticPresentation
            paperID = UUID()
            replayID = UUID()
        }
    }

    private func finishImmediately() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            feed = 1
            printing = false
            // Feed's model value is already 1 during animation. Replacing the paper
            // cancels its in-flight presentation immediately at the final position.
            paperID = UUID()
        }
        // Cancel an in-flight timer. The task's guard prevents a new animation while closed.
        replayID = UUID()
    }

    private func money(_ amount: Decimal) -> String { MoneyFormat.string(amount, currencyCode: "CNY") }
}

private struct ReceiptFixture {
    let spent: Decimal
    let difference: Decimal
    let firstMovement: Decimal
    let secondMovement: Decimal
    let walletAfter: Decimal
    let recoveryAfter: Decimal
    static let surplus = Self(spent: 2_468, difference: 532, firstMovement: 120, secondMovement: 412, walletAfter: 1_092, recoveryAfter: 0)
    static let overrun = Self(spent: 3_240, difference: 240, firstMovement: 160, secondMovement: 80, walletAfter: 0, recoveryAfter: 80)
}

/// A restrained perforated edge; content keeps its regular reading order.
private struct ReceiptPaper: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 5))
        let teeth = max(1, Int(rect.width / 12))
        let width = rect.width / CGFloat(teeth)
        for index in (0..<teeth).reversed() {
            path.addLine(to: CGPoint(x: CGFloat(index) * width + width / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: CGFloat(index) * width, y: rect.maxY - 5))
        }
        path.addLine(to: .zero)
        path.closeSubpath()
        return path
    }
}
#endif
