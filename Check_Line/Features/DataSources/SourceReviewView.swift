import SwiftUI

struct SourceReviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PaperCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "ui.source.available"))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(PaperTheme.muted)
                        ForEach(["manual", "agentText"], id: \.self) { source in
                            Label(String(localized: String.LocalizationValue("ui.source." + source)), systemImage: "checkmark.circle")
                                .font(.body).foregroundStyle(PaperTheme.ink)
                                .accessibilityValue(String(localized: "ui.source.available"))
                        }
                    }
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "ui.source.unavailable"))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(PaperTheme.muted)
                        ForEach(["applePay", "sms", "email", "statement"], id: \.self) { source in
                            Text(String(localized: String.LocalizationValue("ui.source." + source)))
                                .font(.body).foregroundStyle(PaperTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityValue(String(localized: "ui.source.notConnected"))
                        }
                    }
                }
                DisclosureGroup(String(localized: "ui.sources.details")) {
                    Text(String(localized: "ui.sources.boundary"))
                        .font(.subheadline).foregroundStyle(PaperTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
                #if DEBUG
                if DesignPreviewData.isEnabled {
                    NavigationLink { ImportReviewPrototype() } label: {
                        Label(String(localized: "ui.import.title"), systemImage: "tray.and.arrow.down")
                    }.buttonStyle(PaperQuietButtonStyle())
                    NavigationLink { ManagementReviewPrototype() } label: { Text(String(localized: "ui.design.manage")) }
                        .buttonStyle(PaperQuietButtonStyle())
                }
                #endif
            }.padding(22).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(PaperTheme.canvas).navigationTitle(String(localized: "ui.sources.title")).navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
/// Operable state contract only. No parser, system permission, network or ledger reference.
struct ImportReviewPrototype: View {
    enum Phase: String, CaseIterable { case source, processing, review, empty, failed, confirm, result }
    @State private var phase: Phase = .source
    @State private var included = true
    @State private var attribution = "ui.source.unbudgeted"
    private var title: String {
        switch phase {
        case .source: "ui.import.start"
        case .processing: "ui.import.processing"
        case .review: "ui.import.review"
        case .empty: "ui.import.empty"
        case .failed: "ui.import.failed"
        case .confirm: "ui.import.confirm"
        case .result: "ui.import.result"
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(String(localized: "ui.import.demo"), systemImage: "testtube.2")
                    .font(.caption).foregroundStyle(PaperTheme.accent)
                Text(String(localized: String.LocalizationValue(title))).font(.title2.weight(.semibold))
                switch phase {
                case .source:
                    Text(String(localized: "ui.sources.boundary")).font(.subheadline)
                    Button(String(localized: "ui.import.start")) { phase = .processing }.buttonStyle(PaperSolidButtonStyle())
                case .processing:
                    Label(String(localized: "ui.import.processing"), systemImage: "hourglass")
                    Button(String(localized: "ui.import.continue")) { phase = .review }.buttonStyle(PaperSolidButtonStyle())
                case .review:
                    Toggle(isOn: $included) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "wallet.demo.coffee"))
                            Text(MoneyFormat.string(40, currencyCode: "CNY")).monospacedDigit()
                            Text(Date(), format: .dateTime.year().month().day()).font(.caption)
                        }
                    }.padding(18).walletSurface()
                    Picker(String(localized: "v1.agent.attribution"), selection: $attribution) {
                        Text(String(localized: "v1.unbudgeted")).tag("ui.source.unbudgeted")
                        Text(String(localized: "wallet.demo.daily")).tag("wallet.demo.daily")
                    }.pickerStyle(.menu)
                    Label(String(localized: "ui.import.duplicate"), systemImage: "doc.on.doc").padding(18).walletSurface()
                    Button(String(localized: "ui.import.confirm")) { phase = .confirm }.buttonStyle(PaperSolidButtonStyle(enabled: included)).disabled(!included)
                case .empty:
                    ContentUnavailableView(String(localized: "ui.import.empty"), systemImage: "tray")
                    Button(String(localized: "ui.import.reset")) { phase = .source }.buttonStyle(PaperQuietButtonStyle())
                case .failed:
                    Label(String(localized: "ui.import.failed"), systemImage: "exclamationmark.circle")
                    Button(String(localized: "ui.import.retry")) { phase = .review }.buttonStyle(PaperSolidButtonStyle())
                case .confirm:
                    Text(String(localized: "ui.import.impact"))
                    Button(String(localized: "ui.import.submit")) { phase = .result }.buttonStyle(PaperSolidButtonStyle())
                    Button(String(localized: "action.cancel")) { phase = .review }.buttonStyle(PaperQuietButtonStyle())
                case .result:
                    Label(String(localized: "ui.import.result"), systemImage: "checkmark.circle")
                    Button(String(localized: "ui.import.reset")) { phase = .source }.buttonStyle(PaperQuietButtonStyle())
                }
            }.padding(22).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(PaperTheme.canvas)
        .navigationTitle(String(localized: "ui.import.title")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu(String(localized: "ui.import.states")) {
                Button(String(localized: "ui.import.review")) { phase = .review }
                Button(String(localized: "ui.import.empty")) { phase = .empty }
                Button(String(localized: "ui.import.failed")) { phase = .failed }
            }
        }
    }
}

struct ManagementReviewPrototype: View {
    enum Phase { case detail, empty, processing, failed, result }
    @State private var phase: Phase = .detail
    @State private var showImpact = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(String(localized: "ui.import.demo"), systemImage: "testtube.2").font(.caption)
                switch phase {
                case .detail:
                    PaperFormItem(title: String(localized: "v1.composer.merchant"), value: String(localized: "wallet.demo.coffee"))
                    PaperFormItem(title: String(localized: "v1.agent.amount"), value: MoneyFormat.string(40, currencyCode: "CNY"))
                    PaperFormItem(title: String(localized: "v1.agent.attribution"), value: String(localized: "wallet.demo.daily"))
                    Text(String(localized: "ui.manage.boundary"))
                    Text(String(localized: "ui.design.impact")).font(.subheadline)
                    Button(String(localized: "ui.design.previewCorrection")) { phase = .processing }.buttonStyle(PaperSolidButtonStyle())
                case .empty:
                    ContentUnavailableView(String(localized: "ui.manage.empty"), systemImage: "receipt")
                case .processing:
                    Label(String(localized: "ui.manage.processing"), systemImage: "hourglass")
                    Button(String(localized: "ui.import.continue")) { showImpact = true }.buttonStyle(PaperSolidButtonStyle())
                case .failed:
                    Label(String(localized: "ui.manage.failed"), systemImage: "exclamationmark.circle")
                    Button(String(localized: "ui.draft.retry")) { phase = .processing }.buttonStyle(PaperSolidButtonStyle())
                case .result:
                    Label(String(localized: "ui.design.completed"), systemImage: "checkmark.circle")
                    Button(String(localized: "ui.manage.back")) { phase = .detail }.buttonStyle(PaperQuietButtonStyle())
                }
            }.padding(22)
        }.background(PaperTheme.canvas).navigationTitle(String(localized: "ui.design.manage"))
        .toolbar {
            Menu(String(localized: "ui.import.states")) {
                Button(String(localized: "wallet.expense.title")) { phase = .detail }
                Button(String(localized: "ui.manage.empty")) { phase = .empty }
                Button(String(localized: "ui.manage.processing")) { phase = .processing }
                Button(String(localized: "ui.manage.failed")) { phase = .failed }
            }
        }
        .fullScreenCover(isPresented: $showImpact) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(String(localized: "ui.import.demo")).font(.caption)
                        Text(String(localized: "ui.design.correctionExample"))
                        Text(String(localized: "ui.design.impact"))
                        Button(String(localized: "ui.import.submit")) { phase = .result; showImpact = false }.buttonStyle(PaperSolidButtonStyle())
                        Button(String(localized: "action.cancel")) { phase = .detail; showImpact = false }.buttonStyle(PaperQuietButtonStyle())
                    }.padding(22)
                }.background(PaperTheme.canvas).navigationTitle(String(localized: "ui.design.previewCorrection"))
            }
        }
    }
}
#endif
