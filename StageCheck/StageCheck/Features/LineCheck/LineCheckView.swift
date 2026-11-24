import SwiftUI

struct CheckTabView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    private var current: ShowProject? {
        if let id = router.checkProjectID, let p = store.project(id) { return p }
        return store.projects.filter { $0.status != .archived }.max { $0.updatedAt < $1.updatedAt }
    }

    var body: some View {
        Group {
            if let p = current {
                LineCheckContent(projectID: p.id)
            } else {
                EmptyStateView(icon: "checklist", title: "No Show to Check", message: "Create a show with input channels to start a line check.",
                               actionTitle: "Create Show") { router.sheet = .newShow }
                    .frame(maxHeight: .infinity).screenBackground()
            }
        }
        .navigationTitle("Line Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.projects.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Show", selection: Binding(get: { current?.id }, set: { router.checkProjectID = $0 })) {
                            ForEach(store.projects.filter { $0.status != .archived }.sorted { $0.updatedAt > $1.updatedAt }) { Text($0.displayTitle).tag(Optional($0.id)) }
                        }
                    } label: { Label("Select Show", systemImage: "rectangle.stack") }
                }
            }
        }
    }
}

struct LineCheckView: View {
    let projectID: UUID
    var body: some View { LineCheckContent(projectID: projectID).navigationTitle("Line Check") }
}

struct LineCheckContent: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let projectID: UUID
    @State private var filter: CheckStatus? = nil
    @State private var confirmReset = false

    var body: some View {
        let p = store.project(projectID) ?? ShowProject()
        let chans = p.sortedChannels
        let rows = chans.filter { filter == nil || $0.checkStatus == filter }
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.displayTitle).font(.headline).foregroundStyle(Theme.text).lineLimit(2)
                            Text("\(chans.count) channels · \(p.venue.ifEmpty("No venue"))").font(.caption).foregroundStyle(Theme.text2)
                        }
                        Spacer()
                        ProgressRing(progress: p.checkProgress, lineWidth: 7, tint: Theme.success).frame(width: 64, height: 64)
                    }
                    SegmentedStatusBar(passed: p.count(.passed), failed: p.count(.failed), skipped: p.count(.skipped), pending: p.count(.notChecked))
                    HStack {
                        stat("Passed", p.count(.passed), Theme.success); Spacer()
                        stat("Failed", p.count(.failed), Theme.error); Spacer()
                        stat("Pending", p.count(.notChecked), Theme.text2); Spacer()
                        stat("Skipped", p.count(.skipped), Theme.warning)
                    }
                    if let next = chans.first(where: { $0.checkStatus == .notChecked }) ?? chans.first(where: { $0.checkStatus == .failed }) {
                        NavigationLink(value: Route.checkChannel(projectID, next.id)) {
                            Label(next.checkStatus == .failed ? "Retest CH \(next.channelNumber)" : "Check Next · CH \(next.channelNumber)", systemImage: "play.fill")
                                .font(.headline).foregroundStyle(Theme.bg).frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .card(Theme.elevated).padding(.horizontal, Theme.pad)

                ChipBar(items: [(Optional<CheckStatus>.none, "All", chans.count),
                                (.notChecked, "Pending", p.count(.notChecked)), (.passed, "Passed", p.count(.passed)),
                                (.failed, "Failed", p.count(.failed)), (.skipped, "Skipped", p.count(.skipped))], selection: $filter)

                if chans.isEmpty {
                    EmptyStateView(icon: "slider.vertical.3", title: "No Input Channels", message: "Add input channels to this show before running a line check.",
                                   actionTitle: "Add Input") { router.sheet = .newChannel(projectID) }
                } else if rows.isEmpty {
                    Text("No channels with this status.").font(.subheadline).foregroundStyle(Theme.text2).padding(.horizontal, Theme.pad)
                }
                LazyVStack(spacing: 8) {
                    ForEach(rows) { c in
                        NavigationLink(value: Route.checkChannel(projectID, c.id)) { ChannelRow(channel: c).padding(.horizontal, 12).padding(.vertical, 4).background(Theme.card, in: RoundedRectangle(cornerRadius: 12)) }
                            .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, Theme.pad)
                if chans.contains(where: { !$0.records.isEmpty }) {
                    Button("Reset All Check Results", role: .destructive) { confirmReset = true }
                        .font(.subheadline).foregroundStyle(Theme.error).frame(maxWidth: .infinity).padding(.top, 8)
                }
            }
            .padding(.vertical, 8)
        }
        .screenBackground()
        .confirmationDialog("Reset all line-check results?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Results", role: .destructive) { store.mutate(projectID) { p in for i in p.channels.indices { p.channels[i].records = [] } } }
        } message: { Text("All check history for this show will be permanently deleted.") }
    }

    private func stat(_ t: String, _ v: Int, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(v)").font(.mono(.title3, weight: .bold)).foregroundStyle(c)
            Text(t).font(.caption2).foregroundStyle(Theme.text2)
        }
        .accessibilityElement(children: .combine)
    }
}
