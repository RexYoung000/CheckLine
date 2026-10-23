import SwiftUI

/// SwiftUI List does not restore scrollPosition on all supported OS versions.
/// Capture the native list's exact offset on exit without replacing its delegate
/// or publishing a new Home state on every scroll frame.
struct RememberedRecordList<Content: View>: View {
    @Binding var position: RecordListReadingPosition?
    @State private var memory = RecordListPositionMemory()
    @ViewBuilder var content: (RecordListPositionMemory) -> Content

    var body: some View {
        content(memory)
            .onAppear { memory.configure(position: position) { position = $0 } }
            .onDisappear { memory.detach() }
    }
}

@MainActor final class RecordListPositionMemory {
    private weak var scrollView: UIScrollView?
    private var savedPosition: RecordListReadingPosition?
    private var rows: [UUID: WeakRecordRow] = [:]
    private var onChange: ((RecordListReadingPosition) -> Void)?
    private var configured = false
    private var restored = false
    private var restoring = false
    private var restoreTask: Task<Void, Never>?

    func configure(position: RecordListReadingPosition?, onChange: @escaping (RecordListReadingPosition) -> Void) {
        savedPosition = position; self.onChange = onChange; configured = true
        restore()
    }

    func connect(from view: UIView, id: UUID) {
        rows = rows.filter { $0.key == id || ($0.value.view != nil && $0.value.view !== view) }
        rows[id] = WeakRecordRow(view)
        var ancestor = view.superview
        while let candidate = ancestor {
            if let scroll = candidate as? UIScrollView {
                guard scrollView !== scroll else { return }
                scrollView = scroll; restored = false
                restore()
                return
            }
            ancestor = candidate.superview
        }
    }

    private func restore() {
        guard configured, !restored, let scrollView else { return }
        restored = true; restoring = true
        DispatchQueue.main.async { [weak self, weak scrollView] in
            guard let self, let scrollView, self.configured else { return }
            self.applyOffset(to: scrollView)
            guard self.savedPosition != nil else { self.restoring = false; return }
            // List estimates offscreen row sizes during its first layout, then
            // corrects contentOffset as cells become real. Reapply once after the
            // holder transition settles, unless the user has already taken over.
            self.restoreTask = Task { @MainActor [weak self, weak scrollView] in
                do { try await Task.sleep(for: .milliseconds(360)) } catch { return }
                guard let self, let scrollView, self.configured else { return }
                if !scrollView.isTracking && !scrollView.isDragging && !scrollView.isDecelerating { self.applyOffset(to: scrollView) }
                self.restoring = false
            }
        }
    }

    private func applyOffset(to scrollView: UIScrollView) {
        scrollView.layoutIfNeeded()
        if let savedPosition {
            var offset = savedPosition.offset
            if let id = savedPosition.rowID, let row = rows[id]?.view, row.isDescendant(of: scrollView) {
                let top = row.convert(row.bounds, to: scrollView).minY - scrollView.bounds.minY
                offset = scrollView.contentOffset
                offset.y += top - savedPosition.top
            }
            let inset = scrollView.adjustedContentInset
            let bottom = max(-inset.top, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
            offset.y = min(bottom, max(-inset.top, offset.y))
            scrollView.setContentOffset(offset, animated: false)
        }
    }

    func detach() {
        restoreTask?.cancel(); restoreTask = nil
        if let scrollView, configured, !restoring {
            let visibleRows = rows.compactMap { id, item -> (UUID, CGRect)? in
                guard let row = item.view, row.isDescendant(of: scrollView) else { return nil }
                let frame = row.convert(row.bounds, to: scrollView)
                return frame.maxY > scrollView.bounds.minY && frame.minY < scrollView.bounds.maxY ? (id, frame) : nil
            }
            let first = visibleRows.min { $0.1.minY < $1.1.minY }
            onChange?(RecordListReadingPosition(offset: scrollView.contentOffset, rowID: first?.0,
                                                top: first.map { $0.1.minY - scrollView.bounds.minY } ?? 0))
        }
        scrollView = nil
        rows = [:]; onChange = nil; configured = false; restored = false
    }
}

struct RecordListPositionProbe: UIViewRepresentable {
    let memory: RecordListPositionMemory
    let id: UUID
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async { [weak view] in
            if let view { memory.connect(from: view, id: id) }
        }
    }
}

struct RecordListReadingPosition {
    let offset: CGPoint
    let rowID: UUID?
    let top: CGFloat
}
@MainActor private final class WeakRecordRow {
    weak var view: UIView?
    init(_ view: UIView) { self.view = view }
}
