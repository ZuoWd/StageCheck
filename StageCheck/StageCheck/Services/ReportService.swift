import SwiftUI
import QuickLook

enum ReportService {
    @MainActor
    static func generate(_ type: ReportType, for p: ShowProject, store: Store) throws -> ReportRecord {
        let data: Data
        switch type {
        case .pdf: data = PDFReportRenderer(project: p).render()
        case .inputsCSV: data = CSVExporter.inputs(p)
        case .patchCSV: data = CSVExporter.patch(p)
        case .checkCSV: data = CSVExporter.checks(p)
        }
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd_HHmmss"
        let stamp = df.string(from: Date())
        let suffix: String = { switch type { case .pdf: return "Report"; case .inputsCSV: return "Inputs"; case .patchCSV: return "Patch"; case .checkCSV: return "LineCheck" } }()
        let name = "\(FileStorage.safeName(p.displayTitle))_\(suffix)_\(stamp).\(type.fileExtension)"
        _ = try FileStorage.write(data, name: name)
        let rec = ReportRecord(projectID: p.id, showName: p.displayTitle, reportName: "\(p.displayTitle) — \(type.rawValue)", reportType: type, fileName: name)
        store.reports.insert(rec, at: 0)
        return rec
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ShareItem: Identifiable { let id = UUID(); let url: URL }

/// QuickLook preview for PDF and CSV files.
struct FilePreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url) }
    func makeUIViewController(context: Context) -> UINavigationController {
        let q = QLPreviewController(); q.dataSource = context.coordinator
        q.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak q] _ in q?.dismiss(animated: true) })
        return UINavigationController(rootViewController: q)
    }
    func updateUIViewController(_ vc: UINavigationController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(_ u: URL) { url = u }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
