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
                    ContentUnavailableView {
                        Label("receipt.study.title", systemImage: "doc.text")
                    } description: {
                        Text("receipt.study.disclaimer")
                    } actions: {
                        Button("receipt.study.open") { showingStudy = true; replay() }
                            .buttonStyle(PaperSolidButtonStyle())
                            .frame(maxWidth: 320)
                            .accessibilityIdentifier("receipt.open")
                    }
                }
            }
            .background(PaperTheme.canvas)
            .foregroundStyle(PaperTheme.ink)
            .navigationTitle(String(localized: "receipt.study.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        finishImmediately()
                        showingStudy = false
                    } label: { Image(systemName: "xmark") }
                    .accessibilityLabel(Text("action.close"))
                    .accessibilityIdentifier("receipt.close")
                }
            }
        }
        .tint(PaperTheme.accent)
        .task(id: replayID) {
            guard showingStudy, printing, !staticPresentation else { return }
            // A replay cancels this task and resets presentation without queuing another feed.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 1.35)) { feed = 1 }
            try? await Task.sleep(for: .milliseconds(1_350))
            guard !Task.isCancelled else { return }
            printing = false
        }
        .onAppear { replay() }
        .onDisappear { finishImmediately() }
        .onChange(of: staticPresentation) { _, _ in finishImmediately() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finishImmediately() }
        }
    }

    private var heading: some View {
        VStack(spacing: 8) {
            Label("receipt.study.completed", systemImage: "checkmark.circle")
                .font(PaperTheme.Typography.title)
                .foregroundStyle(PaperTheme.accent)
            Text(period)
                .font(PaperTheme.Typography.meta)
                .foregroundStyle(PaperTheme.muted)
        }
        .accessibilityElement(children: .combine)
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
                Circle().fill(PaperTheme.accent).frame(width: 5, height: 5)
                Text("CheckLine")
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .tracking(1.2)
                Spacer()
                Text(printing ? "receipt.study.printing" : "receipt.study.ready")
                    .font(.caption)
                    .accessibilityIdentifier("receipt.status")
            }
            .foregroundStyle(PaperTheme.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(PaperTheme.pocket, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
            .accessibilityHidden(true)

            receipt
                .padding(.horizontal, 10)
                .visualEffect { content, geometry in
                    content.offset(y: -geometry.size.height * (1 - progress))
                }
                .id(paperID)
                .clipped()
                .overlay(alignment: .top) {
                    Capsule().fill(Color.black.opacity(0.78)).frame(height: 5)
                        .padding(.horizontal, 5).offset(y: -2)
                        .accessibilityHidden(true)
                }
        }
        .accessibilityElement(children: .contain)
    }

    private var receipt: some View {
        VStack(spacing: 0) {
            VStack(spacing: 7) {
                Text("wallet.demo.daily")
                    .font(PaperTheme.Typography.cardName)
                Text("receipt.study.periodResult")
                    .font(.caption).foregroundStyle(PaperTheme.muted)
                Text(overrun ? "wallet.settlement.overrun" : "wallet.settlement.surplus")
                    .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    .padding(.top, 12)
                Text(money(result.difference))
                    .font(PaperTheme.Typography.remaining.weight(.semibold))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("receipt.amount")
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)
            rule
            VStack(spacing: 12) {
                row("receipt.study.limit", money(3_000))
                row("wallet.settlement.confirmed", money(result.spent))
            }.padding(.vertical, 14)
            rule
            VStack(spacing: 12) {
                row(overrun ? "receipt.study.walletDeducted" : "receipt.study.recoveryFilled", money(result.firstMovement))
                row(overrun ? "receipt.study.recoveryAdded" : "receipt.study.walletAdded", money(result.secondMovement))
            }.padding(.vertical, 14)
            rule
            VStack(spacing: 12) {
                row("wallet.settlement.walletAfter", money(result.walletAfter))
                row("wallet.settlement.recoveryAfter", money(result.recoveryAfter))
            }.padding(.top, 18)
            Text("receipt.study.paperNote")
                .font(.caption).foregroundStyle(PaperTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background(PaperTheme.card)
        .clipShape(ReceiptPaper())
        .overlay(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.10), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 18).accessibilityHidden(true)
        }
        .shadow(color: PaperTheme.shadow.opacity(0.55), radius: 9, y: 5)
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
            Picker("receipt.study.scenario", selection: $overrun) {
                Text("receipt.study.surplusExample").tag(false)
                Text("receipt.study.overrunExample").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("receipt.scenario")
            .onChange(of: overrun) { _, _ in replay() }

            if staticPresentation {
                Label(voiceOver ? "receipt.study.voiceOver" : "receipt.study.static", systemImage: "figure.stand")
                    .font(.subheadline).foregroundStyle(PaperTheme.muted)
                    .accessibilityIdentifier("receipt.static")
            } else {
                HStack(spacing: 16) {
                    Button("receipt.study.replay", systemImage: "arrow.clockwise") { replay() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("receipt.replay")
                    Button("receipt.study.showAll") { finishImmediately() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("receipt.finish")
                }.buttonStyle(.bordered)
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
