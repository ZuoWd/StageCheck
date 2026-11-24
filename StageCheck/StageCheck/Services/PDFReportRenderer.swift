import UIKit

/// Print-friendly multi-page PDF report with wrapped table cells and repeated headings.
final class PDFReportRenderer {
    private let page = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
    private let margin: CGFloat = 40
    private var y: CGFloat = 0
    private var ctx: UIGraphicsPDFRendererContext!
    private var pageNo = 0
    private let project: ShowProject
    private let generated = Date()

    private let ink = UIColor(red: 0.08, green: 0.1, blue: 0.14, alpha: 1)
    private let muted = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1)
    private let accent = UIColor(red: 0.13, green: 0.47, blue: 0.78, alpha: 1)
    private let rule = UIColor(red: 0.85, green: 0.87, blue: 0.9, alpha: 1)
    private let fail = UIColor(red: 0.8, green: 0.18, blue: 0.24, alpha: 1)

    init(project: ShowProject) { self.project = project }

    private var contentWidth: CGFloat { page.width - margin * 2 }
    private var bottom: CGFloat { page.height - margin - 20 }

    func render() -> Data {
        let meta = [kCGPDFContextCreator as String: "StageCheck", kCGPDFContextTitle as String: "\(project.displayTitle) — Show Report"]
        let fmt = UIGraphicsPDFRendererFormat(); fmt.documentInfo = meta
        return UIGraphicsPDFRenderer(bounds: page, format: fmt).pdfData { c in
            ctx = c
            newPage()
            cover()
            let chans = project.sortedChannels
            heading("Input Channel List")
            table(["CH", "Name", "Type", "Source", "Equipment", "+48V"], [0.07, 0.2, 0.13, 0.25, 0.25, 0.1],
                  chans.map { ["\($0.channelNumber)", $0.name, $0.inputType.rawValue, $0.sourceName, $0.equipmentModel, $0.phantomPowerRequired ? "Yes" : ""] })
            heading("Patch Assignments")
            let flags = PatchAnalyzer.flagged(chans)
            table(["CH", "Source", "Stage Box", "SB In", "Console", "Con CH", "Cable"], [0.07, 0.23, 0.17, 0.1, 0.17, 0.11, 0.15],
                  chans.sorted { $0.channelNumber < $1.channelNumber }.map { ["\($0.channelNumber)\(flags.contains($0.id) ? " !" : "")", $0.sourceName.ifEmpty($0.name), $0.stageBoxName, $0.stageBoxInput, $0.consoleName, $0.consoleChannel, $0.cableLabel] })
            let warnings = PatchAnalyzer.warnings(for: chans)
            if !warnings.isEmpty { paragraph("Patch warnings:\n" + warnings.map { "• \($0.kind.rawValue): \($0.message)" }.joined(separator: "\n"), size: 9, color: muted) }
            heading("Line-Check Results")
            table(["CH", "Name", "Status", "Last Check", "Items Checked"], [0.07, 0.25, 0.14, 0.22, 0.32],
                  chans.map { c in ["\(c.channelNumber)", c.name, c.checkStatus.rawValue, c.records.map(\.checkedAt).max()?.dateTime ?? "—",
                                    c.latestByItem.map { "\($0.checkType): \($0.status.rawValue)" }.joined(separator: "\n")] })
            let failed = chans.flatMap { c in c.records.filter { $0.status == .failed }.map { (c, $0) } }.sorted { $0.1.checkedAt < $1.1.checkedAt }
            heading("Failed Checks & Corrective Actions")
            if failed.isEmpty { paragraph("No failed checks recorded.", size: 10, color: muted) }
            else {
                let open = Set(chans.flatMap { $0.openIssues.map(\.id) })
                table(["CH", "Check Item", "Issue", "Corrective Action", "State"], [0.07, 0.18, 0.3, 0.3, 0.15],
                      failed.map { ["\($0.0.channelNumber)", $0.1.checkType, $0.1.issueDescription, $0.1.correctiveAction, open.contains($0.1.id) ? "OPEN" : "Retested"] })
            }
            heading("Open Issues")
            let openIssues = chans.flatMap { c in c.openIssues.map { "• CH \(c.channelNumber) \(c.name) — \($0.checkType): \($0.issueDescription.ifEmpty("No description"))" } }
            paragraph(openIssues.isEmpty ? "No open issues." : openIssues.joined(separator: "\n"), size: 10, color: openIssues.isEmpty ? muted : fail)
            heading("Show Notes")
            if !project.notes.trimmed.isEmpty { paragraph(project.notes, size: 10, color: ink) }
            if project.showNotes.isEmpty && project.notes.trimmed.isEmpty { paragraph("No notes.", size: 10, color: muted) }
            for n in project.showNotes.sorted(by: { $0.createdAt < $1.createdAt }) {
                var link = ""
                if let cid = n.channelID, let c = chans.first(where: { $0.id == cid }) { link = " · CH \(c.channelNumber) \(c.name)" }
                paragraph("\(n.title.ifEmpty("Untitled")) [\(n.category.rawValue)\(link)] — \(n.createdAt.dateTime)", size: 10, color: ink, bold: true)
                if !n.content.trimmed.isEmpty { paragraph(n.content, size: 10, color: muted) }
            }
        }
    }

    // MARK: Layout primitives
    private func attrs(_ size: CGFloat, _ color: UIColor, bold: Bool = false, mono: Bool = false) -> [NSAttributedString.Key: Any] {
        let font = mono ? UIFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular) : UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        let ps = NSMutableParagraphStyle(); ps.lineBreakMode = .byWordWrapping
        return [.font: font, .foregroundColor: color, .paragraphStyle: ps]
    }

    private func height(_ s: String, _ a: [NSAttributedString.Key: Any], _ w: CGFloat) -> CGFloat {
        ceil((s as NSString).boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: a, context: nil).height)
    }

    @discardableResult
    private func draw(_ s: String, _ a: [NSAttributedString.Key: Any], x: CGFloat, w: CGFloat) -> CGFloat {
        let h = height(s, a, w)
        (s as NSString).draw(with: CGRect(x: x, y: y, width: w, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: a, context: nil)
        return h
    }

    private func newPage() {
        ctx.beginPage(); pageNo += 1; y = margin
        let a = attrs(8, muted)
        ("StageCheck · \(project.displayTitle)" as NSString).draw(at: CGPoint(x: margin, y: page.height - margin + 4), withAttributes: a)
        let pn = "Page \(pageNo)" as NSString
        pn.draw(at: CGPoint(x: page.width - margin - pn.size(withAttributes: a).width, y: page.height - margin + 4), withAttributes: a)
    }

    private func ensure(_ h: CGFloat) { if y + h > bottom { newPage() } }

    private func paragraph(_ s: String, size: CGFloat, color: UIColor, bold: Bool = false) {
        // Split long text by lines so it can flow across pages.
        for line in s.components(separatedBy: "\n") {
            let a = attrs(size, color, bold: bold)
            let h = height(line.isEmpty ? " " : line, a, contentWidth)
            ensure(min(h, bottom - margin))
            y += draw(line.isEmpty ? " " : line, a, x: margin, w: contentWidth) + 2
        }
        y += 6
    }

    private func heading(_ t: String) {
        ensure(60); y += 10
        y += draw(t.uppercased(), attrs(11, accent, bold: true), x: margin, w: contentWidth) + 4
        ctx.cgContext.setFillColor(rule.cgColor); ctx.cgContext.fill(CGRect(x: margin, y: y, width: contentWidth, height: 1)); y += 8
    }

    private func cover() {
        let cg = ctx.cgContext
        cg.setFillColor(accent.cgColor); cg.fill(CGRect(x: margin, y: y, width: 6, height: 44))
        let x = margin + 16, w = contentWidth - 16
        y += draw("StageCheck", attrs(10, accent, bold: true), x: x, w: w)
        y += draw(project.displayTitle, attrs(22, ink, bold: true), x: x, w: w) + 4
        y += draw("Show Report · Generated \(generated.dateTime)", attrs(9, muted), x: x, w: w) + 18
        let info: [(String, String)] = [("Artist / Client", project.artist), ("Venue", project.venue), ("Show Date", project.showDate.dateTime),
                                         ("Engineer", project.engineer), ("Status", project.status.rawValue)]
        for (k, v) in info {
            ensure(16)
            draw(k, attrs(10, muted), x: margin, w: 120)
            y += max(draw(v.ifEmpty("—"), attrs(10, ink, bold: true), x: margin + 120, w: contentWidth - 120), 14) + 2
        }
        if !project.descriptionText.trimmed.isEmpty { y += 6; paragraph(project.descriptionText, size: 10, color: ink) }
        heading("Project Summary")
        let c = project.channels
        let summary: [(String, String)] = [("Input Channels", "\(c.count)"), ("Patch Complete", "\(c.filter(\.isPatchComplete).count) of \(c.count)"),
                                            ("Passed", "\(project.count(.passed))"), ("Failed", "\(project.count(.failed))"),
                                            ("Skipped", "\(project.count(.skipped))"), ("Not Checked", "\(project.count(.notChecked))"),
                                            ("Completion", "\(Int((project.checkProgress * 100).rounded()))%"), ("Open Issues", "\(project.openIssueCount)")]
        let colW = contentWidth / 4
        for (i, s) in summary.enumerated() {
            let cx = margin + CGFloat(i % 4) * colW
            if i % 4 == 0 && i > 0 { y += 40 }
            ensure(40)
            let top = y
            draw(s.1, attrs(16, ink, bold: true, mono: true), x: cx, w: colW - 8)
            y = top + 20; draw(s.0, attrs(8, muted), x: cx, w: colW - 8); y = top
        }
        y += 44
    }

    private func table(_ headers: [String], _ widths: [CGFloat], _ rows: [[String]]) {
        let pad: CGFloat = 4
        let cols = widths.map { $0 * contentWidth }
        let ha = attrs(8, muted, bold: true), ca = attrs(9, ink)
        func header() {
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(white: 0.95, alpha: 1).cgColor); cg.fill(CGRect(x: margin, y: y, width: contentWidth, height: 18))
            var x = margin
            for (i, h) in headers.enumerated() { (h.uppercased() as NSString).draw(in: CGRect(x: x + pad, y: y + 4, width: cols[i] - pad * 2, height: 12), withAttributes: ha); x += cols[i] }
            y += 20
        }
        if rows.isEmpty { paragraph("No data.", size: 10, color: muted); return }
        ensure(40); header()
        for (ri, r) in rows.enumerated() {
            let cells = r.map { $0.trimmed.isEmpty ? "—" : $0 }
            var h: CGFloat = 0
            for (i, s) in cells.enumerated() where i < cols.count { h = max(h, height(s, ca, cols[i] - pad * 2)) }
            h += pad * 2
            if y + h > bottom { newPage(); header() }
            if ri % 2 == 1 { ctx.cgContext.setFillColor(UIColor(white: 0.98, alpha: 1).cgColor); ctx.cgContext.fill(CGRect(x: margin, y: y, width: contentWidth, height: h)) }
            var x = margin
            for (i, s) in cells.enumerated() where i < cols.count {
                let a = (s == "Failed" || s == "OPEN" || s.hasSuffix(" !")) ? attrs(9, fail, bold: true) : ca
                (s as NSString).draw(with: CGRect(x: x + pad, y: y + pad, width: cols[i] - pad * 2, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: a, context: nil)
                x += cols[i]
            }
            y += h
            ctx.cgContext.setFillColor(rule.cgColor); ctx.cgContext.fill(CGRect(x: margin, y: y, width: contentWidth, height: 0.5))
        }
        y += 10
    }
}
