import SwiftUI

struct PaperGlassEffect: ViewModifier {
    enum ShapeKind {
        case circle
        case capsule
        case rounded(CGFloat)
    }

    var shape: ShapeKind
    var interactive: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .circle:
                content.glassEffect(interactive ? .regular.interactive() : .regular, in: .circle)
            case .capsule:
                content.glassEffect(interactive ? .regular.interactive() : .regular, in: .capsule)
            case .rounded(let radius):
                content.glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: radius))
            }
        } else {
            fallback(content)
        }
    }

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        switch shape {
        case .circle:
            content
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        case .capsule:
            content
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        case .rounded(let radius):
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
        }
    }
}

struct PaperPlusSafeAreaPad: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.safeAreaPadding(.bottom)
        }
    }
}

extension View {
    func paperGlass(_ shape: PaperGlassEffect.ShapeKind, interactive: Bool = false) -> some View {
        modifier(PaperGlassEffect(shape: shape, interactive: interactive))
    }
}
