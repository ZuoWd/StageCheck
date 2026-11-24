import SwiftUI

struct NotesView: View {
    @EnvironmentObject var store: Store
    let projectID: UUID
    @State private var search = ""
    @State private var category: NoteCategory? = nil
    @State private var editing: ShowNote?
    @State private var pendingDelete: ShowNote?

    var body: some View {
        let p = store.project(projectID) ?? ShowProject()
        let notes = p.showNotes
            .filter { category == nil || $0.category == category }
            .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.content.localizedCaseInsensitiveContains(search) }
            .sorted { $0.createdAt > $1.createdAt }
        List {
            Section {
                SearchField(text: $search, prompt: "Search notes").listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                ChipBar(items: [(Optional<NoteCategory>.none, "All", p.showNotes.count)] + NoteCategory.allCases.map { c in (Optional(c), c.rawValue, p.showNotes.filter { $0.category == c }.count) },
                        selection: $category)
                    .padding(.horizontal, -Theme.pad).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if notes.isEmpty {
                EmptyStateView(icon: "note.text", title: p.showNotes.isEmpty ? "No Notes" : "No Matching Notes",
                               message: "Capture setup, soundcheck, equipment and monitoring notes.",
                               actionTitle: "New Note") { editing = ShowNote() }
                    .listRowBackground(Color.clear)
            }
            ForEach(notes) { n in
                Button { editing = n } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(n.title.ifEmpty("Untitled")).font(.headline).foregroundStyle(Theme.text)
                            Spacer()
                            StatusBadge(text: n.category.rawValue, color: Theme.accent)
                        }
                        if !n.content.isEmpty { Text(n.content).font(.subheadline).foregroundStyle(Theme.text2).lineLimit(3) }
                        HStack(spacing: 10) {
                            Text(n.createdAt.dateTime)
                            if let cid = n.channelID, let c = p.channels.first(where: { $0.id == cid }) {
                                Label("CH \(c.channelNumber) \(c.name)", systemImage: "link")
                            }
                        }
                        .font(.mono(.caption2, weight: .regular)).foregroundStyle(Theme.text2)
                    }
                    .padding(.vertical, 4)
                }
                .rowBG()
                .swipeActions { Button(role: .destructive) { pendingDelete = n } label: { Label("Delete", systemImage: "trash") } }
            }
        }
        .darkList()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button { editing = ShowNote() } label: { Image(systemName: "plus") }.accessibilityLabel("New Note") }
        }
        .sheet(item: $editing) { n in NoteEditor(projectID: projectID, note: n) }
        .confirmationDialog("Delete this note?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Note", role: .destructive) {
                if let n = pendingDelete { store.mutate(projectID) { $0.showNotes.removeAll { $0.id == n.id } } }
                pendingDelete = nil
            }
        }
    }
}

struct NoteEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    @State var note: ShowNote

    var body: some View {
        let chans = store.project(projectID)?.sortedChannels ?? []
        let isNew = !(store.project(projectID)?.showNotes.contains { $0.id == note.id } ?? false)
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $note.title)
                    Picker("Category", selection: $note.category) { ForEach(NoteCategory.allCases) { Text($0.rawValue).tag($0) } }
                    Picker("Related Channel", selection: $note.channelID) {
                        Text("None").tag(UUID?.none)
                        ForEach(chans) { Text("CH \($0.channelNumber) · \($0.name)").tag(Optional($0.id)) }
                    }
                }.rowBG()
                Section("Content") {
                    TextField("Write your note", text: $note.content, axis: .vertical).lineLimit(6...20)
                }.rowBG()
            }
            .darkList()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.mutate(projectID) { p in
                            if let i = p.showNotes.firstIndex(where: { $0.id == note.id }) { p.showNotes[i] = note } else { p.showNotes.append(note) }
                        }
                        Haptics.success(); dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(note.title.trimmed.isEmpty && note.content.trimmed.isEmpty)
                }
            }
        }
    }
}
