import SwiftUI

struct InputListView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let projectID: UUID
    @State private var search = ""
    @State private var typeFilter: InputType? = nil
    @State private var grouped = false
    @State private var editMode: EditMode = .inactive
    @State private var pendingDelete: InputChannel?

    private var all: [InputChannel] { store.project(projectID)?.sortedChannels ?? [] }
    private var filtered: [InputChannel] {
        all.filter { typeFilter == nil || $0.inputType == typeFilter }
            .filter { search.isEmpty || [$0.name, $0.sourceName, $0.equipmentModel, $0.cableLabel, "\($0.channelNumber)"].contains { $0.localizedCaseInsensitiveContains(search) } }
    }
    private var typeItems: [(InputType?, String, Int?)] {
        var out: [(InputType?, String, Int?)] = [(nil, "All", all.count)]
        for t in InputType.allCases {
            let n = all.filter { $0.inputType == t }.count
            if n > 0 { out.append((t, t.rawValue, n)) }
        }
        return out
    }
    private var canReorder: Bool { search.isEmpty && typeFilter == nil && !grouped }

    var body: some View {
        let flags = PatchAnalyzer.flagged(all)
        List {
            Section {
                SearchField(text: $search, prompt: "Search channels").listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                ChipBar(items: typeItems, selection: $typeFilter)
                .padding(.horizontal, -Theme.pad)
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if all.isEmpty {
                EmptyStateView(icon: "slider.vertical.3", title: "No Input Channels", message: "Add channels to build your input list and patch.",
                               actionTitle: "Add Input") { router.sheet = .newChannel(projectID) }
                    .listRowBackground(Color.clear)
            } else if filtered.isEmpty {
                Text("No channels match your search.").foregroundStyle(Theme.text2).listRowBackground(Color.clear)
            }
            if grouped {
                ForEach(InputType.allCases) { t in
                    let items = filtered.filter { $0.inputType == t }
                    if !items.isEmpty {
                        Section { ForEach(items) { row($0, flags) } } header: { Text("\(t.rawValue) · \(items.count)") }
                    }
                }
            } else {
                Section {
                    ForEach(filtered) { row($0, flags) }
                        .onMove(perform: move)
                        .moveDisabled(!canReorder)
                }
            }
        }
        .listStyle(.insetGrouped)
        .darkList()
        .environment(\.editMode, $editMode)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Inputs")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Toggle(isOn: $grouped) { Label("Group by Type", systemImage: "square.grid.3x1.below.line.grid.1x2") }
                    Button { withAnimation { editMode = editMode == .active ? .inactive : .active } } label: {
                        Label(editMode == .active ? "Done Reordering" : "Reorder", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(!canReorder)
                } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                .accessibilityLabel("View options")
                Button { router.sheet = .newChannel(projectID) } label: { Image(systemName: "plus") }.accessibilityLabel("Add Input")
            }
        }
        .confirmationDialog("Delete channel \(pendingDelete?.channelNumber ?? 0)?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Channel", role: .destructive) { if let c = pendingDelete { store.deleteChannel(c.id, in: projectID) }; pendingDelete = nil }
        } message: { Text("Its line-check history will also be deleted.") }
    }

    private func row(_ c: InputChannel, _ flags: Set<UUID>) -> some View {
        NavigationLink(value: Route.channel(projectID, c.id)) { ChannelRow(channel: c, warn: flags.contains(c.id)) }
            .rowBG()
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { pendingDelete = c } label: { Label("Delete", systemImage: "trash") }
                Button { store.duplicateChannel(c.id, in: projectID) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }.tint(Theme.accent)
            }
            .contextMenu {
                Button { store.duplicateChannel(c.id, in: projectID) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                Button(role: .destructive) { pendingDelete = c } label: { Label("Delete", systemImage: "trash") }
            }
    }

    private func move(_ from: IndexSet, _ to: Int) {
        var items = all; items.move(fromOffsets: from, toOffset: to)
        store.reorderChannels(items, in: projectID); Haptics.tap()
    }
}
