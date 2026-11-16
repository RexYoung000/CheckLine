import DistortionWavesKit
import SwiftUI

@main
struct SettlementWaveStudyApp: App {
    var body: some Scene {
        WindowGroup { SettlementWaveStudy() }
    }
}

private struct SettlementWaveStudy: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var accepted = false
    @State private var saved = false
    @State private var finished = false
    @State private var waveID = UUID()
    @State private var source = CGRect.zero
    @State private var touch: (point: CGPoint, uptime: TimeInterval)?
    @State private var focus: CGPoint?
    @State private var failed = false
    @State private var failNextSave = ProcessInfo.processInfo.arguments.contains("--fail-first-save")

    private let space = "settlement-wave"
    private let sample = SampleSettlement()

    private var dark: Bool { colorScheme == .dark }
    private var reduceMotion: Bool {
        systemReduceMotion || ProcessInfo.processInfo.arguments.contains("--reduce-motion")
    }
    private var canvas: Color { dark ? Color(red: 0.045, green: 0.052, blue: 0.061) : Color(red: 0.97, green: 0.98, blue: 0.985) }
    private var ink: Color { dark ? .white : Color(red: 0.06, green: 0.08, blue: 0.10) }
    private var accent: Color { dark ? Color(red: 0.64, green: 0.87, blue: 0.97) : Color(red: 0.08, green: 0.38, blue: 0.51) }

    private var style: DistortionWaveStyle {
        var style = DistortionWaveStyle.vertical
        style.cornerRadius = widthClass == .regular ? 18 : 60
        return style
    }

    var body: some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            let needsScroll = dynamicTypeSize.isAccessibilitySize || geometry.size.height < 680
            Group {
                if needsScroll {
                    ScrollView { screen(result: saved, insets: insets, compact: true) }
                        .background(canvas)
                } else if reduceMotion {
                    ZStack {
                        screen(result: false, insets: insets)
                            .opacity(saved ? 0 : 1)
                            .allowsHitTesting(!saved)
                            .accessibilityHidden(saved)
                        screen(result: true, insets: insets, compact: true)
                            .opacity(saved ? 1 : 0)
                            .allowsHitTesting(saved)
                            .accessibilityHidden(!saved)
                    }
                    .animation(.easeInOut(duration: 0.25), value: saved)
                    .accessibilityRepresentation { screen(result: saved, insets: insets, compact: true) }
                } else {
                    DistortionWave(isRevealed: saved, source: source, focus: focus, style: style, onFinish: {
                        finished = saved
                    }) {
                        screen(result: false, insets: insets)
                            .accessibilityHidden(saved)
                    } revealed: {
                        screen(result: true, insets: insets)
                            .accessibilityHidden(!saved)
                    }
                    .id(waveID)
                    .accessibilityRepresentation { screen(result: saved, insets: insets) }
                }
            }
            .coordinateSpace(name: space)
            .ignoresSafeArea()
        }
        .foregroundStyle(ink)
    }

    private func screen(result: Bool, insets: EdgeInsets, compact: Bool = false) -> some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 22)
            summary(result: result)
            Spacer(minLength: 25)
            details
            if !result && failed {
                Text("示例结算未保存，请重试。")
                    .font(.footnote).foregroundStyle(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                    .accessibilityIdentifier("settlement.error")
            }
            Spacer(minLength: 22)
            footer(result: result, compact: compact)
        }
        .padding(.horizontal, 24)
        .padding(.top, insets.top + 12)
        .padding(.bottom, max(insets.bottom, 12) + 10)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(canvas)
    }

    private var header: some View {
        HStack {
            Text("本期结算").font(.subheadline.weight(.semibold))
            Spacer(minLength: 12)
            Text("CheckLine 试样").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func summary(result: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: result ? "checkmark" : "checklist")
                .font(.title3.weight(.semibold))
                .frame(width: 52, height: 52)
                .foregroundStyle(accent)
                .background(accent.opacity(dark ? 0.13 : 0.09), in: Circle())
                .overlay { Circle().strokeBorder(accent.opacity(0.18)) }
                .accessibilityHidden(true)
            Text(result ? "结算完成" : "日常预算")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(result ? "settlement.saved" : "settlement.review")
            Text(result ? sample.transfer : sample.surplus, format: .currency(code: "CNY").precision(.fractionLength(0)))
                .font(.system(size: 48, weight: .semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityIdentifier("settlement.amount")
            Text(result ? "已转入心愿钱包" : "本期结余")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var details: some View {
        VStack(spacing: 0) {
            line("周期") { Text("11 月 1 日至 11 月 12 日") }
            Divider()
            line("额度") { money(sample.limit) }
            Divider()
            line("已确认支出") { money(sample.spent) }
            Divider()
            line("补回待恢复差额") { money(sample.recovered) }
            Divider()
            line("转入心愿钱包") { money(sample.transfer) }
            Divider()
            line("结算后心愿余额") { money(sample.walletAfter) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.linearGradient(colors: [ink.opacity(0.075), ink.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(ink.opacity(0.09)) }
    }

    private func line<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(title).foregroundStyle(.secondary)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            value().fontWeight(.medium).monospacedDigit()
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func money(_ amount: Decimal) -> some View {
        Text(amount, format: .currency(code: "CNY").precision(.fractionLength(0)))
    }

    private func footer(result: Bool, compact: Bool) -> some View {
        VStack(spacing: 7) {
            if result {
                Color.clear.frame(height: 44).accessibilityHidden(true)
            } else {
                Button {
                    accepted.toggle()
                } label: {
                    Label("我接受当前数据，继续结算", systemImage: accepted ? "checkmark.circle.fill" : "circle")
                        .font(.footnote.weight(.medium))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(accepted ? .isSelected : [])
                .accessibilityIdentifier("settlement.accept")
            }
            if result {
                primary("再试一次", enabled: true, action: reset)
                    .disabled(!finished && !compact)
                    .accessibilityIdentifier("settlement.replay")
            } else {
                primary(failed ? "重试保存" : "确认结算", enabled: accepted && !saved, action: save)
                    .onGeometryChange(for: CGRect.self) { geometry in
                        geometry.frame(in: .named(space))
                    } action: { frame in
                        if !saved && frame.width > 0 && frame.height > 0 { source = frame }
                    }
                    .simultaneousGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
                        .onChanged { value in rememberTouch(value.startLocation) }
                        .onEnded { value in
                            if !saved { rememberTouch(value.startLocation) }
                        })
                    .accessibilityIdentifier("settlement.confirm")
            }
        }
    }

    private func primary(_ title: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
                .foregroundStyle(enabled ? canvas : ink.opacity(0.55))
                .background(ink.opacity(enabled ? 1 : 0.10), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func save() {
        guard accepted, !saved else { return }
        if failNextSave {
            failNextSave = false
            failed = true
            return
        }
        failed = false
        focus = touch.flatMap { source.contains($0.point) && ProcessInfo.processInfo.systemUptime - $0.uptime < 0.35 ? $0.point : nil }
        touch = nil
        saved = true
    }

    private func rememberTouch(_ point: CGPoint) {
        touch = (point, ProcessInfo.processInfo.systemUptime)
    }

    private func reset() {
        accepted = false
        focus = nil
        touch = nil
        finished = false
        saved = false
        waveID = UUID()
    }
}

private struct SampleSettlement {
    let limit: Decimal = 1500
    let spent: Decimal = 1380
    let recoveryGap: Decimal = 70
    let walletBefore: Decimal = 280

    var surplus: Decimal { limit - spent }
    var recovered: Decimal { min(recoveryGap, surplus) }
    var transfer: Decimal { surplus - recovered }
    var walletAfter: Decimal { walletBefore + transfer }
}
