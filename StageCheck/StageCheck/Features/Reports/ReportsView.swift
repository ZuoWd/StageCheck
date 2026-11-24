import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var preview: ShareItem?
    @State private var share: ShareItem?
    @State private var pendingDelete: ReportRecord?
    @State private var missing = false
    @State private var choosingShow = false

    var body: some View {
        List {
            if store.reports.isEmpty {
                EmptyStateView(icon: "doc.richtext", title: "No Reports Yet", message: "Generate a PDF report or CSV export from a show. Saved reports appear here.",
                               actionTitle: store.projects.isEmpty ? nil : "Create Report") { choosingShow = true }
                    .listRowBackground(Color.clear)
            }
            ForEach(store.reports) { r in
                Button { open(r, share: false) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: r.reportType.icon).font(.title2).foregroundStyle(r.reportType == .pdf ? Theme.accent : Theme.success).frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.reportType.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                            Text(r.showName).font(.caption).foregroundStyle(Theme.text2).lineLimit(1)
                            Text(r.createdAt.dateTime).font(.mono(.caption2, weight: .regular)).foregroundStyle(Theme.text2)
                        }
                        Spacer()
                        if !FileStorage.exists(r.fileName) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning).accessibilityLabel("File missing") }
                    }
                    .padding(.vertical, 4)
                }
                .rowBG()
                .accessibilityLabel("\(r.reportType.rawValue), \(r.showName), \(r.createdAt.dateTime)")
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pendingDelete = r } label: { Label("Delete", systemImage: "trash") }
                    Button { open(r, share: true) } label: { Label("Share", systemImage: "square.and.arrow.up") }.tint(Theme.accent)
                }
                .contextMenu {
                    Button { open(r, share: false) } label: { Label("Preview", systemImage: "eye") }
                    Button { open(r, share: true) } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { pendingDelete = r } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .darkList()
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.projects.isEmpty {
                ToolbarItem(placement: .primaryAction) { Button { choosingShow = true } label: { Image(systemName: "plus") }.accessibilityLabel("New Report") }
            }
        }
        .confirmationDialog("Create report for", isPresented: $choosingShow, titleVisibility: .visible) {
            ForEach(store.projects.sorted { $0.updatedAt > $1.updatedAt }.prefix(8)) { p in
                Button(p.displayTitle) { router.open([.show(p.id), .export(p.id)], in: .shows) }
            }
        }
        .sheet(item: $preview) { FilePreview(url: $0.url).ignoresSafeArea() }
        .sheet(item: $share) { ShareSheet(items: [$0.url]).presentationDetents([.medium, .large]) }
        .confirmationDialog("Delete this report?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Report", role: .destructive) { if let r = pendingDelete { store.deleteReport(r) }; pendingDelete = nil }
        } message: { Text("The saved file will be removed from this device.") }
        .alert("File Not Found", isPresented: $missing) { Button("OK") {} } message: {
            Text("This report file is no longer available. Delete the entry and export the show again.")
        }
    }

    private func open(_ r: ReportRecord, share s: Bool) {
        guard FileStorage.exists(r.fileName) else { missing = true; return }
        let item = ShareItem(url: FileStorage.url(for: r.fileName))
        if s { share = item } else { preview = item }
    }
}
