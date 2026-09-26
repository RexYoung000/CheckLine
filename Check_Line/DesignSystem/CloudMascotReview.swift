#if DEBUG
import SwiftUI

/// Isolated visual review. It never sets Workspace state or touches the ledger.
struct CloudMascotReview: View {
    @State private var state: CloudMascotState = .idle

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-mascot-state"), arguments.indices.contains(index + 1), let value = CloudMascotState(rawValue: arguments[index + 1]) {
            _state = State(initialValue: value)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(String(localized: "wallet.mascot.preview.notice")).font(.caption).foregroundStyle(.secondary)
                    CloudMascotView(state: state).frame(width: 224, height: 208)
                    HStack(spacing: 16) {
                        CloudMascotView(state: state).frame(width: 44, height: 44)
                        Text(state.label).accessibilityIdentifier("wallet.mascot.preview.status")
                    }
                    VStack(spacing: 10) {
                        ForEach(CloudMascotState.allCases, id: \.self) { value in
                            Button(value.label) { state = value }
                                .buttonStyle(PaperQuietButtonStyle())
                                .accessibilityIdentifier("wallet.mascot.preview.\(value.rawValue)")
                        }
                    }
                }.padding(24).frame(maxWidth: .infinity)
            }
            .background(PaperTheme.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "wallet.mascot.name"))
        }
    }
}
#endif
