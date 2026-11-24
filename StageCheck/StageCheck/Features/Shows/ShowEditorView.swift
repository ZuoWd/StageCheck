import SwiftUI

struct ShowEditorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultEngineer") private var defaultEngineer = ""
    @AppStorage("defaultTemplate") private var defaultTemplate = ShowTemplate.smallBand.rawValue

    let projectID: UUID?
    @State private var draft = ShowProject()
    @State private var template: ShowTemplate = .smallBand
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                if projectID == nil {
                    Section("Template") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ShowTemplate.allCases) { t in templateTile(t) }
                            }
                            .padding(.vertical, 4)
                        }
                        Text(template == .empty ? "Start without channels." : "Creates \(template.channels().count) editable input channels.")
                            .font(.caption).foregroundStyle(Theme.text2)
                    }
                    .rowBG()
                }
                Section("Show") {
                    TextField("Show Name", text: $draft.title)
                    TextField("Artist / Client", text: $draft.artist)
                    TextField("Venue", text: $draft.venue)
                    DatePicker("Show Date", selection: $draft.showDate)
                    TextField("Engineer Name", text: $draft.engineer).textContentType(.name)
                    Picker("Status", selection: $draft.status) { ForEach(ShowStatus.allCases) { Text($0.rawValue).tag($0) } }
                }
                .rowBG()
                Section("Description") {
                    TextField("Description", text: $draft.descriptionText, axis: .vertical).lineLimit(2...6)
                }
                .rowBG()
                Section("Notes") {
                    TextField("General show notes", text: $draft.notes, axis: .vertical).lineLimit(3...8)
                }
                .rowBG()
            }
            .darkList()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(projectID == nil ? "New Show" : "Edit Show")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(projectID == nil ? "Create" : "Save", action: save).fontWeight(.semibold)
                        .disabled(draft.title.trimmed.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func templateTile(_ t: ShowTemplate) -> some View {
        let sel = t == template
        return Button { template = t; Haptics.tap() } label: {
            VStack(spacing: 6) {
                Image(systemName: t.icon).font(.title3)
                Text(t.rawValue).font(.caption.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(width: 92, height: 76)
            .foregroundStyle(sel ? Theme.bg : Theme.text)
            .background(sel ? Theme.accent : Theme.elevated, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(sel ? .isSelected : [])
    }

    private func load() {
        guard !loaded else { return }; loaded = true
        if let id = projectID, let p = store.project(id) { draft = p }
        else { draft.engineer = defaultEngineer; template = ShowTemplate(rawValue: defaultTemplate) ?? .smallBand }
    }

    private func save() {
        if projectID != nil {
            // Preserve channels/notes that may have changed while editing.
            store.mutate(draft.id) { p in
                p.title = draft.title; p.artist = draft.artist; p.venue = draft.venue; p.showDate = draft.showDate
                p.engineer = draft.engineer; p.status = draft.status; p.descriptionText = draft.descriptionText; p.notes = draft.notes
            }
        } else {
            var p = draft; p.channels = template.channels(); p.createdAt = Date(); p.updatedAt = Date()
            store.add(p)
            dismiss()
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.open([.show(p.id)], in: .shows) }
            return
        }
        Haptics.success()
        dismiss()
    }
}
