import SwiftUI

struct ShowDetailView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    @State private var confirmDelete = false

    var body: some View {
        let p = store.project(projectID) ?? ShowProject()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                info(p)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.spacing), GridItem(.flexible())], spacing: Theme.spacing) {
                    MetricCard(title: "Input Channels", value: "\(p.channels.count)", icon: "slider.vertical.3", tint: Theme.accent)
                    MetricCard(title: "Open Issues", value: "\(p.openIssueCount)", icon: "exclamationmark.triangle.fill", tint: p.openIssueCount > 0 ? Theme.error : Theme.text2)
                }
                progress(p)
                SectionHeader(title: "Workspace")
                VStack(spacing: 0) {
                    navRow("Inputs", "slider.vertical.3", "\(p.channels.count) CH", .inputs(projectID))
                    Divider().overlay(Theme.divider)
                    navRow("Patch Plan", "point.3.connected.trianglepath.dotted", "\(Int((p.patchProgress * 100).rounded()))%", .patch(projectID))
                    Divider().overlay(Theme.divider)
                    navRow("Line Check", "checklist", "\(Int((p.checkProgress * 100).rounded()))%", .lineCheck(projectID))
                    Divider().overlay(Theme.divider)
                    navRow("Notes", "note.text", "\(p.showNotes.count)", .notes(projectID))
                    Divider().overlay(Theme.divider)
                    navRow("Export Report", "square.and.arrow.up", "", .export(projectID))
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius))
                if !p.showNotes.isEmpty {
                    SectionHeader(title: "Recent Notes")
                    ForEach(p.showNotes.sorted { $0.createdAt > $1.createdAt }.prefix(3)) { n in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(n.title.ifEmpty("Untitled")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text); Spacer(); StatusBadge(text: n.category.rawValue, color: Theme.accent) }
                            Text(n.content).font(.caption).foregroundStyle(Theme.text2).lineLimit(2)
                        }
                        .card()
                    }
                }
            }
            .padding(Theme.pad)
        }
        .screenBackground()
        .navigationTitle(p.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { router.sheet = .editShow(projectID) } label: { Label("Edit Show", systemImage: "pencil") }
                    Menu("Status") {
                        ForEach(ShowStatus.allCases) { s in Button(s.rawValue) { store.mutate(projectID) { $0.status = s } } }
                    }
                    Button { store.duplicate(projectID); Haptics.success() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete Show", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Show actions")
            }
        }
        .confirmationDialog("Delete this show?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Show", role: .destructive) { dismiss(); store.delete(projectID) }
        } message: { Text("All channels, checks, notes and reports for this show will be permanently deleted.") }
    }

    private func info(_ p: ShowProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusBadge(p.status)
                if p.isSample { StatusBadge(text: "SAMPLE DATA", color: Theme.warning, icon: "sparkles") }
                Spacer()
            }
            Text(p.displayTitle).font(.title2.weight(.bold)).foregroundStyle(Theme.text)
            if !p.artist.trimmed.isEmpty { Text(p.artist).font(.headline).foregroundStyle(Theme.text2) }
            VStack(alignment: .leading, spacing: 6) {
                Label(p.venue.ifEmpty("No venue"), systemImage: "mappin.and.ellipse")
                Label(p.showDate.dateTime, systemImage: "calendar")
                Label(p.engineer.ifEmpty("No engineer"), systemImage: "person.fill")
            }
            .font(.subheadline).foregroundStyle(Theme.text2)
            if !p.descriptionText.trimmed.isEmpty { Text(p.descriptionText).font(.subheadline).foregroundStyle(Theme.text) }
            if !p.notes.trimmed.isEmpty { Text(p.notes).font(.caption).foregroundStyle(Theme.text2) }
            Text("Updated \(p.updatedAt.dateTime)").font(.caption2).foregroundStyle(Theme.text2)
        }
        .card(Theme.elevated)
    }

    private func progress(_ p: ShowProject) -> some View {
        HStack(spacing: 16) {
            ProgressRing(progress: p.checkProgress, lineWidth: 8, tint: Theme.success).frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Patch completion").font(.caption); Spacer(); Text("\(Int((p.patchProgress * 100).rounded()))%").font(.mono(.caption)) }
                    ProgressBar(progress: p.patchProgress)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Line check").font(.caption); Spacer(); Text("\(p.channels.count - p.count(.notChecked))/\(p.channels.count)").font(.mono(.caption)) }
                    SegmentedStatusBar(passed: p.count(.passed), failed: p.count(.failed), skipped: p.count(.skipped), pending: p.count(.notChecked))
                }
            }
            .foregroundStyle(Theme.text2)
        }
        .card()
    }

    private func navRow(_ t: String, _ icon: String, _ value: String, _ r: Route) -> some View {
        NavigationLink(value: r) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 28)
                Text(t).font(.body.weight(.medium)).foregroundStyle(Theme.text)
                Spacer()
                Text(value).font(.mono(.subheadline)).foregroundStyle(Theme.text2)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.text2)
            }
            .padding(.horizontal, Theme.pad).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
