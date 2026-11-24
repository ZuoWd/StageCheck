import SwiftUI

struct PatchPlanView: View {
    @EnvironmentObject var store: Store
    let projectID: UUID
    enum Filter: String, CaseIterable { case all = "All", unassigned = "Unassigned", incomplete = "Incomplete", conflicts = "Conflicts" }
    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var editing: InputChannel?
    @State private var showWarnings = true

    var body: some View {
        let chans = (store.project(projectID)?.channels ?? []).sorted { $0.channelNumber < $1.channelNumber }
        let warnings = PatchAnalyzer.warnings(for: chans)
        let conflicts = PatchAnalyzer.flagged(chans)
        let rows = chans.filter {
            switch filter {
            case .all: return true
            case .unassigned: return !$0.hasStageBox && !$0.hasConsole
            case .incomplete: return !$0.isPatchComplete
            case .conflicts: return conflicts.contains($0.id)
            }
        }.filter { search.isEmpty || [$0.name, $0.sourceName, $0.stageBoxName, $0.stageBoxInput, $0.consoleChannel, $0.cableLabel, "\($0.channelNumber)"].contains { $0.localizedCaseInsensitiveContains(search) } }

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                HStack(spacing: Theme.spacing) {
                    MetricCard(title: "Patched", value: "\(chans.filter(\.isPatchComplete).count)/\(chans.count)", icon: "point.3.connected.trianglepath.dotted", tint: Theme.success)
                    MetricCard(title: "Warnings", value: "\(warnings.count)", icon: "exclamationmark.triangle.fill", tint: warnings.isEmpty ? Theme.text2 : Theme.warning)
                }
                .padding(.horizontal, Theme.pad)
                if !warnings.isEmpty { warningCard(warnings).padding(.horizontal, Theme.pad) }
                SearchField(text: $search, prompt: "Search assignments").padding(.horizontal, Theme.pad)
                ChipBar(items: Filter.allCases.map { ($0, $0.rawValue, nil) }, selection: $filter)
                table(rows, conflicts).padding(.horizontal, Theme.pad)
                Text("Warnings never block saving — shared assignments can be intentional.")
                    .font(.caption).foregroundStyle(Theme.text2).padding(.horizontal, Theme.pad)
            }
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle("Patch Plan")
        .sheet(item: $editing) { c in PatchEditSheet(projectID: projectID, channel: c) }
    }

    private func warningCard(_ w: [PatchWarning]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation { showWarnings.toggle() } } label: {
                HStack {
                    Label("\(w.count) patch warning\(w.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill").font(.subheadline.weight(.semibold))
                    Spacer(); Image(systemName: showWarnings ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(Theme.warning)
            }
            if showWarnings {
                ForEach(w) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.kind.rawValue).font(.caption.weight(.bold)).foregroundStyle(item.kind == .incomplete ? Theme.warning : Theme.error)
                        Text(item.message).font(.caption).foregroundStyle(Theme.text2)
                    }
                }
            }
        }
        .card(Theme.warning.opacity(0.08))
    }

    private func table(_ rows: [InputChannel], _ conflicts: Set<UUID>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("CH").frame(width: 34, alignment: .leading)
                Text("SOURCE").frame(maxWidth: .infinity, alignment: .leading)
                Text("STAGE BOX").frame(width: 84, alignment: .leading)
                Text("CONSOLE").frame(width: 56, alignment: .leading)
            }
            .font(.mono(.caption2, weight: .bold)).foregroundStyle(Theme.text2)
            .padding(.horizontal, 12).padding(.vertical, 10).background(Theme.elevated)
            if rows.isEmpty {
                Text("No channels in this view.").font(.subheadline).foregroundStyle(Theme.text2).padding(20)
            }
            ForEach(rows) { c in
                Button { editing = c } label: {
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", c.channelNumber)).font(.mono(.subheadline, weight: .bold)).foregroundStyle(Theme.text).frame(width: 34, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.name.ifEmpty("Unnamed")).font(.subheadline.weight(.medium)).foregroundStyle(Theme.text).lineLimit(1)
                            Text(c.cableLabel.isEmpty ? c.sourceName : "Cable \(c.cableLabel)").font(.caption2).foregroundStyle(Theme.text2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        cell(c.hasStageBox ? "\(c.stageBoxName.trimmed.isEmpty ? "" : abbreviate(c.stageBoxName) + " ")\(c.stageBoxInput)" : "—", ok: c.hasStageBox, conflict: conflicts.contains(c.id))
                            .frame(width: 84, alignment: .leading)
                        cell(c.hasConsole ? c.consoleChannel : "—", ok: c.hasConsole, conflict: conflicts.contains(c.id)).frame(width: 56, alignment: .leading)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Channel \(c.channelNumber) \(c.name), \(c.patchSummary)\(conflicts.contains(c.id) ? ", conflict" : "")")
                .accessibilityHint("Edit patch assignment")
                Divider().overlay(Theme.divider)
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    private func cell(_ s: String, ok: Bool, conflict: Bool) -> some View {
        Text(s).font(.mono(.caption, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            .foregroundStyle(!ok ? Theme.warning : conflict ? Theme.error : Theme.accent)
    }

    private func abbreviate(_ s: String) -> String {
        let words = s.split(separator: " ")
        return words.count > 1 ? words.map { String($0.prefix(1)) }.joined().uppercased() : String(s.prefix(4))
    }
}

struct PatchEditSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    @State var channel: InputChannel

    var body: some View {
        NavigationStack {
            Form {
                Section { LabeledContent("Channel", value: "\(channel.channelNumber) · \(channel.name)") ; LabeledContent("Source", value: channel.sourceName.ifEmpty("—")) }.rowBG()
                Section("Stage Box") {
                    TextField("Stage Box Name", text: $channel.stageBoxName)
                    TextField("Stage Box Input", text: $channel.stageBoxInput)
                }.rowBG()
                Section("Console") {
                    TextField("Console Name", text: $channel.consoleName)
                    TextField("Console Channel", text: $channel.consoleChannel)
                }.rowBG()
                Section("Cable & Notes") {
                    TextField("Cable Label", text: $channel.cableLabel)
                    TextField("Notes", text: $channel.notes, axis: .vertical).lineLimit(1...4)
                }.rowBG()
            }
            .darkList()
            .navigationTitle("Edit Patch").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { store.upsert(channel, in: projectID); Haptics.success(); dismiss() }.fontWeight(.semibold) }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
