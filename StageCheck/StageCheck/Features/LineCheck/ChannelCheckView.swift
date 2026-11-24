import SwiftUI

struct ChannelCheckView: View {
    @EnvironmentObject var store: Store
    let projectID: UUID
    @State var channelID: UUID
    @State private var item = defaultCheckItems[0]
    @State private var status: CheckStatus = .passed
    @State private var notes = ""
    @State private var issue = ""
    @State private var action = ""
    @State private var addingCustom = false
    @State private var customName = ""
    @State private var savedBanner = false
    @FocusState private var focused: Bool

    init(projectID: UUID, channelID: UUID) { self.projectID = projectID; _channelID = State(initialValue: channelID) }

    private var channels: [InputChannel] { store.project(projectID)?.sortedChannels ?? [] }
    private var channel: InputChannel? { channels.first { $0.id == channelID } }

    var body: some View {
        if let c = channel {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(c)
                    if !c.openIssues.isEmpty { openIssues(c) }
                    SectionHeader(title: "Check Item", action: "Custom", onAction: { addingCustom = true })
                    itemGrid(c)
                    SectionHeader(title: "Result")
                    HStack(spacing: 8) {
                        resultButton(.passed, "Pass"); resultButton(.failed, "Fail"); resultButton(.skipped, "Skip")
                    }
                    if status == .failed { failFields }
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5).focused($focused)
                        .padding(12).background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                    HStack(spacing: 8) {
                        SecondaryButton(title: "Save", icon: "checkmark") { save(c, advance: false) }
                        PrimaryButton(title: nextChannel(after: c) == nil ? "Save & Finish" : "Save & Next", icon: "arrow.right") { save(c, advance: true) }
                    }
                    .disabled(status == .failed && issue.trimmed.isEmpty)
                    if status == .failed && issue.trimmed.isEmpty {
                        Text("Describe the issue to save a failed check.").font(.caption).foregroundStyle(Theme.warning)
                    }
                    Text("Results are manual verification records. StageCheck does not measure audio signals.")
                        .font(.caption2).foregroundStyle(Theme.text2)
                    SectionHeader(title: "Check History")
                    CheckHistoryList(records: c.records)
                }
                .padding(Theme.pad)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("CH \(c.channelNumber) Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button { step(-1) } label: { Image(systemName: "chevron.up") }.disabled(channels.first?.id == channelID).accessibilityLabel("Previous channel")
                        Button { step(1) } label: { Image(systemName: "chevron.down") }.disabled(channels.last?.id == channelID).accessibilityLabel("Next channel")
                    }
                }
            }
            .overlay(alignment: .top) {
                if savedBanner {
                    Label("Result saved", systemImage: "checkmark.circle.fill").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.success, in: Capsule()).foregroundStyle(Theme.bg)
                        .transition(.move(edge: .top).combined(with: .opacity)).padding(.top, 8)
                }
            }
            .alert("Custom Check Item", isPresented: $addingCustom) {
                TextField("Name", text: $customName)
                Button("Add") {
                    let n = customName.trimmed
                    if !n.isEmpty && !store.checkItems.contains(n) { store.customChecks.append(n) }
                    if !n.isEmpty { item = n }
                    customName = ""
                }
                Button("Cancel", role: .cancel) { customName = "" }
            } message: { Text("Custom items are saved on this device and available for all shows.") }
        } else {
            EmptyStateView(icon: "questionmark", title: "Channel Not Found", message: "This channel was deleted.").screenBackground()
        }
    }

    private func header(_ c: InputChannel) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", c.channelNumber)).font(.mono(.title, weight: .bold)).foregroundStyle(Theme.text)
                .frame(width: 64, height: 64).background(Theme.elevated, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(c.name.ifEmpty("Unnamed")).font(.title3.weight(.bold)).foregroundStyle(Theme.text)
                Text(c.sourceName.ifEmpty(c.inputType.rawValue)).font(.subheadline).foregroundStyle(Theme.text2)
                HStack(spacing: 8) {
                    Text(c.patchSummary).font(.mono(.caption, weight: .medium)).foregroundStyle(c.isPatchComplete ? Theme.text2 : Theme.warning)
                    if c.phantomPowerRequired { Text("+48V").font(.mono(.caption, weight: .bold)).foregroundStyle(Theme.warning) }
                }
            }
            Spacer()
            StatusBadge(c.checkStatus)
        }
        .card()
    }

    private func openIssues(_ c: InputChannel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Open issue\(c.openIssues.count > 1 ? "s" : "")", systemImage: "exclamationmark.octagon.fill").font(.subheadline.weight(.bold)).foregroundStyle(Theme.error)
            ForEach(c.openIssues) { r in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.checkType).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                        Text(r.issueDescription).font(.caption).foregroundStyle(Theme.text2)
                        if !r.correctiveAction.isEmpty { Text("Action: \(r.correctiveAction)").font(.caption).foregroundStyle(Theme.success) }
                    }
                    Spacer()
                    Button("Retest") { item = r.checkType; status = .passed; action = r.correctiveAction; Haptics.tap() }
                        .font(.caption.weight(.bold)).buttonStyle(.borderedProminent).tint(Theme.accent)
                }
            }
        }
        .card(Theme.error.opacity(0.1))
    }

    private func itemGrid(_ c: InputChannel) -> some View {
        let latest = Dictionary(c.latestByItem.map { ($0.checkType, $0.status) }, uniquingKeysWith: { a, _ in a })
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
            ForEach(store.checkItems, id: \.self) { i in
                let sel = i == item
                Button { item = i; Haptics.tap() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: Theme.icon(latest[i] ?? .notChecked)).foregroundStyle(sel ? Theme.bg : Theme.color(latest[i] ?? .notChecked))
                        Text(i).font(.caption.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(10).frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(sel ? Theme.bg : Theme.text)
                    .background(sel ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(i), \((latest[i] ?? .notChecked).rawValue)").accessibilityAddTraits(sel ? .isSelected : [])
            }
        }
    }

    private func resultButton(_ s: CheckStatus, _ t: String) -> some View {
        let sel = status == s
        return Button { withAnimation(.easeOut(duration: 0.15)) { status = s }; s == .failed ? Haptics.warning() : Haptics.tap() } label: {
            VStack(spacing: 4) { Image(systemName: Theme.icon(s)).font(.title2); Text(t).font(.subheadline.weight(.bold)) }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .foregroundStyle(sel ? Theme.bg : Theme.color(s))
                .background(sel ? Theme.color(s) : Theme.color(s).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).accessibilityLabel(t).accessibilityAddTraits(sel ? .isSelected : [])
    }

    private var failFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This check will be recorded as FAILED", systemImage: "exclamationmark.triangle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.error)
            TextField("Issue description (required)", text: $issue, axis: .vertical).lineLimit(1...4).focused($focused)
                .padding(12).background(Theme.bg2, in: RoundedRectangle(cornerRadius: 10))
            TextField("Corrective action", text: $action, axis: .vertical).lineLimit(1...4).focused($focused)
                .padding(12).background(Theme.bg2, in: RoundedRectangle(cornerRadius: 10))
        }
        .card(Theme.error.opacity(0.1))
    }

    private func nextChannel(after c: InputChannel) -> InputChannel? {
        guard let i = channels.firstIndex(where: { $0.id == c.id }) else { return nil }
        return channels.dropFirst(i + 1).first
    }

    private func step(_ d: Int) {
        guard let i = channels.firstIndex(where: { $0.id == channelID }), channels.indices.contains(i + d) else { return }
        channelID = channels[i + d].id; reset()
    }

    private func reset() { notes = ""; issue = ""; action = ""; status = .passed; item = store.checkItems.first ?? item }

    private func save(_ c: InputChannel, advance: Bool) {
        focused = false
        let r = LineCheckRecord(checkType: item, status: status, issueDescription: status == .failed ? issue.trimmed : "",
                                correctiveAction: action.trimmed, notes: notes.trimmed)
        store.addRecord(r, channel: c.id, in: projectID)
        status == .failed ? Haptics.error() : Haptics.success()
        withAnimation { savedBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { savedBanner = false } }
        if advance, let n = nextChannel(after: c) { channelID = n.id; reset() } else { notes = ""; issue = ""; action = "" }
    }
}
