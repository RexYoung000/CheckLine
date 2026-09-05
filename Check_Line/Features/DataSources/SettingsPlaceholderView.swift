import SwiftUI

struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Text(String(localized: "v1.settings.privacy"))
                Text(String(localized: "v1.settings.sources"))
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(String(localized: "v1.settings.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.close")) { dismiss() }
                }
            }
        }
    }
}
