import SwiftUI

struct ChannelDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    let channelID: UUID
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        let c = store.project(projectID)?.channels.first { $0.id == channelID } ?? InputChannel(channelNumber: 0, name: "")
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                HStack(spacing: 14) {
                    Text(String(format: "%02d", c.channelNumber)).font(.mono(.largeTitle, weight: .bold)).foregroundStyle(Theme.text)
                        .frame(width: 76, height: 76).background(Theme.elevated, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.color(c.colorTag), lineWidth: c.colorTag == .none ? 0 : 2))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(c.name.ifEmpty("Unnamed")).font(.title2.weight(.bold)).foregroundStyle(Theme.text)
                        Label(c.inputType.rawValue, systemImage: c.inputType.icon).font(.subheadline).foregroundStyle(Theme.accent)
                        StatusBadge(c.checkStatus)
                    }
                    Spacer()
                }
                TechnicalInfoCard(title: "Source", rows: [("Channel Name", c.name), ("Source", c.sourceName), ("Input Type", c.inputType.rawValue), ("Equipment", c.equipmentModel)])
                TechnicalInfoCard(title: "Patch", rows: [("Stage Box", c.stageBoxName), ("Stage Box Input", c.stageBoxInput), ("Console", c.consoleName), ("Console Channel", c.consoleChannel), ("Cable Label", c.cableLabel)])
                TechnicalInfoCard(title: "Technical Reference", rows: [("Phantom +48V", c.phantomPowerRequired ? "Required" : "Not required"), ("Gain Reference", c.gainReference), ("Pan", c.pan), ("Monitor Notes", c.monitorNotes)])
                if !c.notes.trimmed.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                        Text(c.notes).font(.subheadline).foregroundStyle(Theme.text2)
                    }.card()
                }
                SectionHeader(title: "Check Status")
                NavigationLink(value: Route.checkChannel(projectID, channelID)) {
                    HStack { Label("Run Line Check", systemImage: "checklist"); Spacer(); Image(systemName: "chevron.right") }
                        .font(.headline).foregroundStyle(Theme.accent).card()
                }
                CheckHistoryList(records: c.records)
            }
            .padding(Theme.pad)
        }
        .screenBackground()
        .navigationTitle("CH \(c.channelNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button { store.duplicateChannel(channelID, in: projectID); Haptics.success() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Channel actions")
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { ChannelEditorView(projectID: projectID, channelID: channelID) } }
        .confirmationDialog("Delete this channel?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Channel", role: .destructive) { dismiss(); store.deleteChannel(channelID, in: projectID) }
        }
    }
}

struct CheckHistoryList: View {
    let records: [LineCheckRecord]
    var body: some View {
        if records.isEmpty {
            Text("No checks recorded yet.").font(.subheadline).foregroundStyle(Theme.text2).card()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(records.sorted { $0.checkedAt > $1.checkedAt }) { r in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: Theme.icon(r.status)).foregroundStyle(Theme.color(r.status)).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack { Text(r.checkType).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text); Spacer(); Text(r.checkedAt.dateTime).font(.mono(.caption2, weight: .regular)).foregroundStyle(Theme.text2) }
                            if !r.issueDescription.trimmed.isEmpty { Text("Issue: \(r.issueDescription)").font(.caption).foregroundStyle(Theme.error) }
                            if !r.correctiveAction.trimmed.isEmpty { Text("Action: \(r.correctiveAction)").font(.caption).foregroundStyle(Theme.success) }
                            if !r.notes.trimmed.isEmpty { Text(r.notes).font(.caption).foregroundStyle(Theme.text2) }
                        }
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if r.id != records.sorted(by: { $0.checkedAt > $1.checkedAt }).last?.id { Divider().overlay(Theme.divider) }
                }
            }
            .card()
        }
    }
}
