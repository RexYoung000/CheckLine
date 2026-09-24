import SwiftUI
import UIKit

struct PaperCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(PaperTheme.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .walletSurface()
    }
}

struct PaperPageTitle: View {
    var title: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(PaperTheme.Typography.display)
                .tracking(PaperTheme.Typography.displayTracking)
                .foregroundStyle(PaperTheme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.leading, 16)
            Spacer(minLength: 0)
        }
        .frame(height: PaperTheme.Layout.titleBarHeight)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A single thin line. `progress` is cycle elapsed (0...1); `nil` is an idle brand rule.
struct PaperHairline: View {
    var progress: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PaperTheme.lineTrack)
                    .frame(height: PaperTheme.Stroke.hairline)
                if let progress {
                    Capsule()
                        .fill(PaperTheme.lineInk)
                        .frame(
                            width: max(PaperTheme.Stroke.emphasis, proxy.size.width * progress),
                            height: PaperTheme.Stroke.progress
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: PaperTheme.Stroke.emphasis)
        .accessibilityHidden(progress == nil)
    }
}

struct PaperQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: PaperTheme.Space.xs) {
            configuration.label
                .font(.body.weight(.semibold))
                .foregroundStyle(PaperTheme.ink.opacity(configuration.isPressed ? 0.55 : 1))

        }
        .frame(minHeight: PaperTheme.Layout.minTap, alignment: .leading)
    }
}

struct PaperSolidButtonStyle: ButtonStyle {
    @Environment(\.walletReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    var enabled: Bool = true
    var foreground: Color = PaperTheme.canvas
    var background: Color = PaperTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, PaperTheme.Space.m)
            .frame(minHeight: PaperTheme.Layout.minTap)
            .background(
                background.opacity(backgroundOpacity(pressed: configuration.isPressed)),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : PaperTheme.Motion.spring, value: configuration.isPressed)
    }

    private func backgroundOpacity(pressed: Bool) -> Double {
        if enabled == false || isEnabled == false { return 0.28 }
        return pressed ? 0.72 : 1
    }
}

struct PaperChipPressStyle: ButtonStyle {
    @Environment(\.walletReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(reduceMotion ? nil : PaperTheme.Motion.spring, value: configuration.isPressed)
    }
}

struct PaperCirclePressStyle: ButtonStyle {
    @Environment(\.walletReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : PaperTheme.Motion.spring, value: configuration.isPressed)
    }
}

struct PaperScalePressStyle: ButtonStyle {
    @Environment(\.walletReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : PaperTheme.Motion.spring, value: configuration.isPressed)
    }
}

struct PaperField: View {
    var title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: PaperTheme.Space.xs) {
            Text(title)
                .font(PaperTheme.Typography.caption)
                .foregroundStyle(PaperTheme.muted)
            TextField("", text: $text, axis: axis == .vertical ? .vertical : .horizontal)
                .keyboardType(keyboard)
                .lineLimit(axis == .vertical ? 1...3 : 1...1)
                .foregroundStyle(PaperTheme.ink)
                .padding(.vertical, 8)
                .accessibilityLabel(title)
        }.padding(14).walletSurface(radius: 18)
    }
}

struct PaperChoiceChip<Value: Hashable>: View {
    var title: String
    var value: Value
    @Binding var selection: Value

    var body: some View {
        let selected = selection == value
        Button {
            PaperHaptics.light()
            selection = value
        } label: {
            Text(title)
                .font(PaperTheme.Typography.chip)
                .foregroundStyle(selected ? PaperTheme.canvas : PaperTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: PaperTheme.Radius.chip, style: .continuous)
                        .fill(selected ? PaperTheme.ink : PaperTheme.chipIdle)
                )
        }
        .buttonStyle(PaperChipPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PaperFormItem: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var title: String
    var value: String
    var showArrow: Bool = false
    var action: (() -> Void)?

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        let row = layout {
            Text(title)
                .font(.body)
                .foregroundStyle(PaperTheme.muted)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            HStack(spacing: 8) {
                Text(value)
                    .font(.body)
                    .foregroundStyle(PaperTheme.ink)
                    .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.7)
                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PaperTheme.muted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, typeSize.isAccessibilitySize ? 12 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 52)
        .walletSurface()
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { row }
                .buttonStyle(PaperChipPressStyle())
        } else {
            row
        }
    }
}

struct PaperComposerCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(PaperTheme.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PaperTheme.ink.opacity(0.06)))
        }
        .buttonStyle(PaperCirclePressStyle())
        .accessibilityLabel(String(localized: "v1.shell.close"))
    }
}

struct PaperHeroIcon: View {
    var systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(PaperTheme.ink)
            .frame(width: 80, height: 80)
            .background(PaperTheme.card, in: Circle())
            .accessibilityHidden(true)
    }
}

struct PaperHeroField: View {
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(PaperTheme.muted))
            .font(keyboard == .decimalPad ? .largeTitle.weight(.medium) : .title2.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(PaperTheme.ink)
            .keyboardType(keyboard)
            .padding(.horizontal, 16)
            .accessibilityLabel(placeholder)
    }
}

struct PaperCapsuleSegment<Value: Hashable>: View {
    var items: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                let selected = selection == item.0
                Button {
                    PaperHaptics.light()
                    selection = item.0
                } label: {
                    Text(item.1)
                        .font(PaperTheme.Typography.chip)
                        .foregroundStyle(selected ? PaperTheme.canvas : PaperTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(selected ? PaperTheme.ink : Color.clear)
                        )
                }
                .buttonStyle(PaperChipPressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(PaperTheme.chipIdle, in: Capsule())
    }
}

struct PaperSubmitBar: View {
    var title: String
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PaperTheme.canvas)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .frame(minHeight: 52)
                .background(
                    PaperTheme.ink.opacity(enabled ? 1 : 0.28),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
        }
        .buttonStyle(PaperScalePressStyle())
        .disabled(enabled == false)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
