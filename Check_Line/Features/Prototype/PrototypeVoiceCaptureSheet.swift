import SwiftUI

struct PrototypeVoiceCaptureSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    let onUseManual: () -> Void

    @State private var isListening = true
    @State private var showsTranscript = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                VStack(spacing: 7) {
                    Text(LocalizedStringKey(isListening ? "voice.listening" : "voice.paused"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(CheckLineColor.text)

                    Text("voice.mock.status")
                        .font(.caption)
                        .foregroundStyle(CheckLineColor.secondary)
                }

                PrototypeVoiceWaveform(isListening: isListening)
                    .frame(height: 64)
                    .accessibilityHidden(true)

                transcriptSurface

                HStack(spacing: 16) {
                    Button {
                        isListening.toggle()
                        PrototypeHaptics.selection()
                    } label: {
                        Image(systemName: isListening ? "pause.fill" : "mic.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(CheckLineColor.text, in: Circle())
                    }
                    .accessibilityLabel(
                        Text(LocalizedStringKey(isListening ? "voice.pause" : "voice.resume"))
                    )
                    .accessibilityIdentifier("voice.toggleListening")

                    Button {
                        onUseManual()
                    } label: {
                        Label("voice.manual", systemImage: "keyboard")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(CheckLineColor.text)
                    .accessibilityIdentifier("voice.useManual")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .background(CheckLineColor.canvas.ignoresSafeArea())
            .navigationTitle(Text("voice.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                if reduceMotion {
                    showsTranscript = true
                } else {
                    withAnimation(.easeOut(duration: 0.22)) {
                        showsTranscript = true
                    }
                }
            }
        }
    }

    private var transcriptSurface: some View {
        HStack(spacing: 12) {
            Image(systemName: "quote.bubble.fill")
                .font(.subheadline)
                .foregroundStyle(CheckLineColor.secondary)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(showsTranscript ? "voice.transcript" : "voice.listening"))
                .font(.body.weight(showsTranscript ? .semibold : .regular))
                .foregroundStyle(showsTranscript ? CheckLineColor.text : CheckLineColor.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(CheckLineColor.muted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PrototypeVoiceWaveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isListening: Bool

    private let lowHeights: [CGFloat] = [12, 20, 28, 16, 24, 14, 22]
    private let highHeights: [CGFloat] = [28, 44, 24, 50, 30, 42, 34]

    var body: some View {
        Group {
            if reduceMotion || !isListening {
                bars(isHighPhase: false)
            } else {
                PhaseAnimator([false, true]) { phase in
                    bars(isHighPhase: phase)
                } animation: { _ in
                    .easeInOut(duration: 0.52)
                }
            }
        }
    }

    private func bars(isHighPhase: Bool) -> some View {
        HStack(alignment: .center, spacing: 7) {
            ForEach(lowHeights.indices, id: \.self) { index in
                Capsule()
                    .fill(CheckLineColor.text)
                    .frame(
                        width: 5,
                        height: isHighPhase ? highHeights[index] : lowHeights[index]
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
