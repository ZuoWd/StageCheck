import SwiftUI

struct ShowListView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @State private var search = ""
    @State private var filter: ShowStatus? = nil
    @State private var newestFirst = true
    @State private var pendingDelete: ShowProject?

    private var items: [ShowProject] {
        store.projects
            .filter { filter == nil ? $0.status != .archived : $0.status == filter }
            .filter { search.isEmpty || [$0.title, $0.venue, $0.artist, $0.engineer].contains { $0.localizedCaseInsensitiveContains(search) } }
            .sorted { newestFirst ? $0.showDate > $1.showDate : $0.showDate < $1.showDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                SearchField(text: $search, prompt: "Search shows, venues, artists").padding(.horizontal, Theme.pad)
                ChipBar(items: [(Optional<ShowStatus>.none, "Active", nil)] + ShowStatus.allCases.map { s in (Optional(s), s.rawValue, store.projects.filter { $0.status == s }.count) },
                        selection: $filter)
                if items.isEmpty {
                    EmptyStateView(icon: "music.mic", title: store.projects.isEmpty ? "No Shows Yet" : "No Matching Shows",
                                   message: store.projects.isEmpty ? "Create a show from a template to get started." : "Try a different search or filter.",
                                   actionTitle: store.projects.isEmpty ? "Create Show" : nil) { router.sheet = .newShow }
                }
                LazyVStack(spacing: Theme.spacing) {
                    ForEach(items) { p in
                        NavigationLink(value: Route.show(p.id)) { ShowCard(project: p) }
                            .buttonStyle(PressStyle())
                            .contextMenu {
                                Button { router.sheet = .editShow(p.id) } label: { Label("Edit", systemImage: "pencil") }
                                Button { store.duplicate(p.id); Haptics.success() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                Button {
                                    store.mutate(p.id) { $0.status = $0.status == .archived ? .planning : .archived }
                                } label: { Label(p.status == .archived ? "Unarchive" : "Archive", systemImage: "archivebox") }
                                Button(role: .destructive) { pendingDelete = p } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
                .padding(.horizontal, Theme.pad)
            }
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle("Shows")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { newestFirst.toggle() } label: {
                    Label(newestFirst ? "Newest first" : "Oldest first", systemImage: newestFirst ? "arrow.down" : "arrow.up")
                }
                .accessibilityLabel("Sort by date, \(newestFirst ? "newest first" : "oldest first")")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { router.sheet = .newShow } label: { Image(systemName: "plus") }.accessibilityLabel("New Show")
            }
        }
        .confirmationDialog("Delete \(pendingDelete?.displayTitle ?? "show")?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Show", role: .destructive) { if let p = pendingDelete { store.delete(p.id); Haptics.warning() }; pendingDelete = nil }
        } message: { Text("All channels, line checks, notes and saved reports for this show will be permanently deleted.") }
    }
}
