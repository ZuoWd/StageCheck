import SwiftUI

struct ExportView: View {
    @EnvironmentObject var store: Store
    let projectID: UUID
    @State private var type: ReportType = .pdf
    @State private var preview: ShareItem?
    @State private var share: ShareItem?
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        let p = store.project(projectID) ?? ShowProject()
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.displayTitle).font(.title3.weight(.bold)).foregroundStyle(Theme.text)
                    Text("\(p.venue.ifEmpty("No venue")) · \(p.showDate.shortDate)").font(.subheadline).foregroundStyle(Theme.text2)
                    HStack(spacing: 14) {
                        Label("\(p.channels.count) CH", systemImage: "slider.vertical.3")
                        Label("\(Int((p.checkProgress * 100).rounded()))% checked", systemImage: "checklist")
                        Label("\(p.openIssueCount) open", systemImage: "exclamationmark.triangle")
                    }
                    .font(.mono(.caption, weight: .medium)).foregroundStyle(Theme.text2)
                }
                .card(Theme.elevated)

                SectionHeader(title: "Export Type")
                ForEach(ReportType.allCases) { t in
                    Button { type = t; Haptics.tap() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: t.icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                                Text(detail(t)).font(.caption).foregroundStyle(Theme.text2)
                            }
                            Spacer()
                            Image(systemName: type == t ? "checkmark.circle.fill" : "circle").foregroundStyle(type == t ? Theme.accent : Theme.divider).font(.title3)
                        }
                        .card(type == t ? Theme.elevated : Theme.card)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(type == t ? .isSelected : [])
                }
                HStack(spacing: 8) {
                    SecondaryButton(title: "Preview", icon: "eye") { run(share: false) }
                    PrimaryButton(title: "Share", icon: "square.and.arrow.up") { run(share: true) }
                }
                .disabled(busy)
                Text("Each export is saved to Report History. Use the Share Sheet to save to Files, AirDrop or email.")
                    .font(.caption).foregroundStyle(Theme.text2)
            }
            .padding(Theme.pad)
        }
        .screenBackground()
        .navigationTitle("Export Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $preview) { FilePreview(url: $0.url).ignoresSafeArea() }
        .sheet(item: $share) { ShareSheet(items: [$0.url]).presentationDetents([.medium, .large]) }
        .alert("Export Failed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }

    private func detail(_ t: ReportType) -> String {
        switch t {
        case .pdf: return "Full report: show info, inputs, patch, checks, issues, notes"
        case .inputsCSV: return "Input channel list for spreadsheets"
        case .patchCSV: return "Stage box and console assignments"
        case .checkCSV: return "Complete line-check history"
        }
    }

    private func run(share s: Bool) {
        guard let p = store.project(projectID) else { return }
        busy = true; defer { busy = false }
        do {
            let rec = try ReportService.generate(type, for: p, store: store)
            let item = ShareItem(url: FileStorage.url(for: rec.fileName))
            Haptics.success()
            if s { share = item } else { preview = item }
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }
}
