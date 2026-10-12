import SwiftUI

struct AttachmentImageSelection: Identifiable {
    let id: UUID
    let image: UIImage
}

struct AttachmentImagePreview: View {
    let selection: AttachmentImageSelection
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: selection.image).resizable().scaledToFit()
                    .frame(width: geometry.size.width * max(1, min(zoom * magnification, 4)))
                    .gesture(MagnificationGesture().updating($magnification) { value, state, _ in state = value }
                        .onEnded { zoom = max(1, min(zoom * $0, 4)) })
                    .onTapGesture(count: 2) { zoom = zoom > 1 ? 1 : 2 }
                    .accessibilityLabel(String(localized: "wallet.expense.attachments"))
                    .accessibilityValue(Double(zoom).formatted(.percent))
                    .accessibilityIdentifier("wallet.attachment.image")
            }
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "wallet.expense.attachments")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "ui.attachment.zoom")) { zoom = zoom > 1 ? 1 : 2 }
                        .accessibilityIdentifier("wallet.attachment.zoom")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "action.close"), iconSymbol: "xmark") { dismiss() }.labelStyle(.iconOnly)
                        .accessibilityIdentifier("wallet.attachment.close")
                }
            }
        }.presentationBackground(PaperTheme.canvas)
    }
}
