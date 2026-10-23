import SwiftUI
import Testing
import UIKit
@testable import CheckLine

@Suite(.serialized) @MainActor struct ContactFeedbackTests {
    @Observable final class PlaybackState {
        var contact: Date? = Date()
        var phase = ScenePhase.active
        var visibleContact: Date?
        var visible: Bool { visibleContact != nil }
        var appearances = 0
    }

    private struct Probe: View {
        let state: PlaybackState
        var body: some View {
            let contact = state.contact
            ContactEffectTimeline(startedAt: state.contact, duration: 0.72) { _ in
                Color.red
                    .id(contact)
                    .onAppear { state.visibleContact = contact; state.appearances += 1 }
                    .onDisappear { if state.visibleContact == contact { state.visibleContact = nil } }
            }
            .frame(width: 128, height: 48)
            .environment(\.scenePhase, state.phase)
        }
    }

    private func host(_ state: PlaybackState) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 160, height: 80))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window.windowScene = scene
        }
        window.rootViewController = UIHostingController(rootView: Probe(state: state))
        window.isHidden = false
        return window
    }

    @Test("CLICK截止后实际卸载绘制子树，不能冻结淡出末帧")
    func removesFinishedDecoration() async throws {
        let state = PlaybackState(), window = host(state)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(220))
        #expect(state.visible && state.appearances == 1)
        try await Task.sleep(for: .milliseconds(650))
        #expect(!state.visible)
        try await Task.sleep(for: .milliseconds(180))
        #expect(!state.visible && state.appearances == 1)
    }

    @Test("新接触不被旧截止回调移除，第二次也彻底结束")
    func replacedContactOwnsItsDeadline() async throws {
        let state = PlaybackState(), window = host(state)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await wait { state.visible }
        try await Task.sleep(for: .milliseconds(250))
        state.contact = Date()
        try await wait { state.appearances == 2 }
        let remaining = max(0, 0.52 - Date().timeIntervalSince(state.contact!))
        try await Task.sleep(for: .seconds(remaining))
        #expect(state.visible, "The first contact expired, but the replacement is still playing.")
        #expect(state.appearances == 2)
        try await wait { !state.visible }
        #expect(!state.visible)
    }

    private func wait(until condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(1.2)
        while !condition() && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(condition())
    }

    @Test("后台移除反馈，过期接触回前台不重播")
    func motionAndBackgroundDoNotRetainOldFrame() async throws {
        let state = PlaybackState()
        state.phase = .background
        let window = host(state)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(160))
        #expect(!state.visible && state.appearances == 0)
        state.phase = .active; state.contact = Date()
        try await Task.sleep(for: .milliseconds(180))
        #expect(state.visible)
        state.phase = .background
        try await Task.sleep(for: .milliseconds(120))
        #expect(!state.visible)
        try await Task.sleep(for: .milliseconds(650))
        state.phase = .active
        try await Task.sleep(for: .milliseconds(120))
        #expect(!state.visible && state.appearances == 1)
    }

    @Test("浅深色实际绘制均保留紫青粉彩光且组件内部透明")
    func iridescenceFollowsActualBorder() throws {
        for scheme in [ColorScheme.light, .dark] {
            var cyan = 0, pink = 0, violet = 0
            var previous: [UInt8]?
            for progress in [0.2, 0.45, 0.7] {
                let renderer = ImageRenderer(content: ComponentLightFrame(progress: progress, radius: 24, origin: .top)
                    .frame(width: 240, height: 120).environment(\.colorScheme, scheme))
                renderer.scale = 1
                let image = try #require(renderer.cgImage)
                var bytes = [UInt8](repeating: 0, count: 240 * 120 * 4)
                let context = try #require(CGContext(data: &bytes, width: 240, height: 120, bitsPerComponent: 8,
                    bytesPerRow: 240 * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: 240, height: 120))
                var interiorAlpha = 0, darkestBandChannel = 255
                for y in 0..<120 {
                    for x in 0..<240 {
                        let i = (y * 240 + x) * 4
                        let r = Int(bytes[i]), g = Int(bytes[i + 1]), b = Int(bytes[i + 2]), a = Int(bytes[i + 3])
                        if x > 18 && x < 221 && y > 18 && y < 101 { interiorAlpha = max(interiorAlpha, a) }
                        guard a > 35 else { continue }
                        darkestBandChannel = min(darkestBandChannel, min(r, g, b) * 255 / a)
                        if g > r + 10 && b > r + 10 { cyan += 1 }
                        if r > g + 12 && r > b + 3 { pink += 1 }
                        if b > r + 10 && b > g + 10 { violet += 1 }
                    }
                }
                #expect(interiorAlpha < 3)
                #expect(darkestBandChannel > 100, "Transparent band tails must not paint black into the glass rim.")
                if let previous { #expect(bytes != previous, "The light must travel along the border.") }
                previous = bytes
            }
            #expect(cyan > 15 && pink > 15 && violet > 15)
        }
    }
}
