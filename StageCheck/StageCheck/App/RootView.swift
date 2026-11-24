import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @AppStorage("didOnboard") private var didOnboard = false

    var body: some View {
        Group {
            if didOnboard { tabs } else { OnboardingView { didOnboard = true } }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .newShow: ShowEditorView(projectID: nil)
            case .editShow(let id): ShowEditorView(projectID: id)
            case .newChannel(let pid): NavigationStack { ChannelEditorView(projectID: pid, channelID: nil) }
            case .settings: SettingsView()
            }
        }
        .onAppear {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-uiSample") { didOnboard = true; if store.projects.isEmpty { store.add(SampleData.project()) } }
            if let i = args.firstIndex(of: "-uiTab"), i + 1 < args.count, let pid = store.projects.first?.id {
                switch args[i + 1] {
                case "shows": router.tab = .shows
                case "check": router.tab = .check
                case "reports": router.tab = .reports
                case "detail": router.open([.show(pid)], in: .shows)
                case "inputs": router.open([.show(pid), .inputs(pid)], in: .shows)
                case "patch": router.open([.show(pid), .patch(pid)], in: .shows)
                case "channel": if let c = store.project(pid)?.sortedChannels[4].id { router.open([.checkChannel(pid, c)], in: .check) }
                case "export": router.open([.show(pid), .export(pid)], in: .shows)
                case "pdf": if let pr = store.project(pid) { _ = try? ReportService.generate(.pdf, for: pr, store: store); router.tab = .reports }
                default: break
                }
            }
            #endif
        }
        .alert("Storage Error", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.lastError ?? "") }
    }

    private var tabs: some View {
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.homePath) { DashboardView().routes() }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(AppTab.home)
            NavigationStack(path: $router.showsPath) { ShowListView().routes() }
                .tabItem { Label("Shows", systemImage: "music.mic") }.tag(AppTab.shows)
            NavigationStack(path: $router.checkPath) { CheckTabView().routes() }
                .tabItem { Label("Check", systemImage: "checklist") }.tag(AppTab.check)
            NavigationStack { ReportsView() }
                .tabItem { Label("Reports", systemImage: "doc.text.fill") }.tag(AppTab.reports)
        }
    }
}

struct RouteView: View {
    @EnvironmentObject var store: Store
    let route: Route
    var body: some View {
        switch route {
        case .show(let p): exists(p) { ShowDetailView(projectID: p) }
        case .inputs(let p): exists(p) { InputListView(projectID: p) }
        case .channel(let p, let c): exists(p, c) { ChannelDetailView(projectID: p, channelID: c) }
        case .patch(let p): exists(p) { PatchPlanView(projectID: p) }
        case .lineCheck(let p): exists(p) { LineCheckView(projectID: p) }
        case .checkChannel(let p, let c): exists(p, c) { ChannelCheckView(projectID: p, channelID: c) }
        case .notes(let p): exists(p) { NotesView(projectID: p) }
        case .export(let p): exists(p) { ExportView(projectID: p) }
        }
    }

    @ViewBuilder
    private func exists<V: View>(_ p: UUID, _ c: UUID? = nil, @ViewBuilder _ v: () -> V) -> some View {
        if let proj = store.project(p), c == nil || proj.channels.contains(where: { $0.id == c }) { v() }
        else { EmptyStateView(icon: "questionmark.folder", title: "Not Found", message: "This item was deleted.").screenBackground() }
    }
}

extension View {
    func routes() -> some View { navigationDestination(for: Route.self) { RouteView(route: $0) } }
}
