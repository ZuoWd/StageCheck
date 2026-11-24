import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("defaultEngineer") private var engineer = ""
    @AppStorage("defaultTemplate") private var template = ShowTemplate.smallBand.rawValue
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("didOnboard") private var didOnboard = true
    @State private var share: ShareItem?
    @State private var importing = false
    @State private var importTarget: UUID?
    @State private var message: String?
    @State private var confirmErase = false

    private var version: String {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "1.0") (\(i?["CFBundleVersion"] as? String ?? "1"))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) { Text("Dark").tag("dark"); Text("System").tag("system") }.pickerStyle(.segmented)
                }.rowBG()
                Section("Defaults") {
                    TextField("Default Engineer Name", text: $engineer).textContentType(.name)
                    Picker("Default Show Template", selection: $template) { ForEach(ShowTemplate.allCases) { Text($0.rawValue).tag($0.rawValue) } }
                    Toggle("Haptic Feedback", isOn: $haptics)
                }.rowBG()
                Section {
                    Button { exportAll() } label: { Label("Export Data (JSON Backup)", systemImage: "externaldrive") }
                    Picker(selection: $importTarget) {
                        Text("Choose show…").tag(UUID?.none)
                        ForEach(store.projects) { Text($0.displayTitle).tag(Optional($0.id)) }
                    } label: { Label("Import Into", systemImage: "music.mic") }
                    Button { importing = true } label: { Label("Import Input List CSV", systemImage: "square.and.arrow.down") }
                        .disabled(importTarget == nil)
                    Button { let p = store.add(SampleData.project()); message = "Sample show \"\(p.displayTitle)\" added." } label: { Label("Add Sample Show", systemImage: "sparkles") }
                } header: { Text("Data") } footer: { Text("CSV import expects a header row with columns such as Channel, Name, Input Type, Source, Stage Box Input, Console Channel — the same format as the Input List CSV export.") }
                .rowBG()
                Section("Information") {
                    NavigationLink { InfoPage(title: "Privacy", text: Self.privacy) } label: { Label("Privacy Information", systemImage: "hand.raised.fill") }
                    NavigationLink { InfoPage(title: "Help", text: Self.help) } label: { Label("Help", systemImage: "questionmark.circle.fill") }
                    NavigationLink { InfoPage(title: "About StageCheck", text: Self.about) } label: { Label("About StageCheck", systemImage: "info.circle.fill") }
                    Button { didOnboard = false; dismiss() } label: { Label("Show Introduction", systemImage: "play.rectangle") }
                    HStack { Text("App Version"); Spacer(); Text(version).font(.mono(.body, weight: .regular)).foregroundStyle(Theme.text2) }
                }.rowBG()
                Section {
                    Button("Delete All Data", role: .destructive) { confirmErase = true }
                }.rowBG()
            }
            .darkList()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { importCSV($0) }
            .sheet(item: $share) { ShareSheet(items: [$0.url]) }
            .alert("StageCheck", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
            .confirmationDialog("Delete all data?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { store.eraseAll(); Haptics.warning(); message = "All shows and reports were deleted." }
            } message: { Text("All shows, channels, checks, notes and saved reports will be permanently deleted from this device.") }
        }
    }

    private func exportAll() {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]; enc.dateEncodingStrategy = .iso8601
        do {
            let data = try enc.encode(Store.Snapshot(projects: store.projects, reports: store.reports, customChecks: store.customChecks))
            share = ShareItem(url: try FileStorage.temp(data, name: "StageCheck_Backup_\(Date().formatted(.iso8601.year().month().day())).json"))
        } catch { message = "Export failed: \(error.localizedDescription)" }
    }

    private func importCSV(_ result: Result<URL, Error>) {
        guard let pid = importTarget else { return }
        switch result {
        case .failure(let e): message = "Import failed: \(e.localizedDescription)"
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), data.count < 5_000_000,
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { message = "The file could not be read."; return }
            let chans = CSVExporter.importChannels(text, startNumber: store.nextChannelNumber(pid))
            guard !chans.isEmpty else { message = "No channels found. Check that the file has a header row with a Name or Source column."; return }
            chans.forEach { store.upsert($0, in: pid) }
            Haptics.success()
            message = "Imported \(chans.count) channel\(chans.count == 1 ? "" : "s")."
        }
    }

    static let privacy = """
    StageCheck does not collect, transmit or share any personal data.

    • All shows, channels, checks, notes and reports are stored only on this device.
    • There is no account, login, analytics, advertising or tracking.
    • The app works fully offline and does not connect to any server.
    • Files leave the device only when you choose to share them using the iOS Share Sheet.
    • Deleting the app removes all of its data. You can also use Settings › Delete All Data.
    """

    static let help = """
    1. Create a show from a template in the Shows tab. Templates create editable input channels.
    2. Open Inputs to add, edit, duplicate, reorder or delete channels. Swipe a row for quick actions.
    3. Open Patch Plan to assign stage box inputs and console channels. Duplicate or missing assignments show warnings but never block saving.
    4. In the Check tab, select a channel and a check item, then mark it Passed, Failed or Skipped. Failed checks need an issue description and can record a corrective action. Retesting keeps the earlier failed record in history.
    5. Add notes in the Notes section and optionally link them to a channel.
    6. Use Export Report to create a PDF report or CSV files. Exports are kept in the Reports tab and can be shared again.

    All checks are manual records. StageCheck does not measure audio signals or control any audio equipment.
    """

    static let about = """
    StageCheck — Live Audio Check & Show Planner.

    A field tool for sound engineers, venues, churches, schools and rehearsal studios to plan shows, organize input channels and patch, run manual line checks and export reports.

    Free, with no ads, subscriptions or in-app purchases. All data stays on your device.
    """
}

struct InfoPage: View {
    let title: String, text: String
    var body: some View {
        ScrollView { Text(text).font(.body).foregroundStyle(Theme.text).frame(maxWidth: .infinity, alignment: .leading).padding(Theme.pad) }
            .screenBackground().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
