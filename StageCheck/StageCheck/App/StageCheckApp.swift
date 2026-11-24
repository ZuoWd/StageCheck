import Combine
import SwiftUI

@main
struct StageCheckApp: App {
    @StateObject private var store = Store()
    @StateObject private var router = Router()
    @AppStorage("appearance") private var appearance = "dark"
    @Environment(\.scenePhase) private var phase

    init() { Theme.applyAppearance() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(router)
                .tint(Theme.accent)
                .preferredColorScheme(appearance == "dark" ? .dark : nil)
        }
        .onChange(of: phase) { p in if p != .active { store.saveNow() } }
    }
}

enum Route: Hashable {
    case show(UUID), inputs(UUID), channel(UUID, UUID), patch(UUID), lineCheck(UUID), checkChannel(UUID, UUID), notes(UUID), export(UUID)
}

enum AppTab: Hashable { case home, shows, check, reports }

enum Sheet: Identifiable {
    case newShow, editShow(UUID), newChannel(UUID), settings
    var id: String {
        switch self {
        case .newShow: return "new"; case .editShow(let i): return "edit\(i)"; case .newChannel(let i): return "ch\(i)"; case .settings: return "settings"
        }
    }
}

@MainActor
final class Router: ObservableObject {
    @Published var tab: AppTab = .home
    @Published var homePath = NavigationPath()
    @Published var showsPath = NavigationPath()
    @Published var checkPath = NavigationPath()
    @Published var sheet: Sheet?
    @AppStorage("checkProjectID") var checkProjectIDString = ""

    var checkProjectID: UUID? {
        get { UUID(uuidString: checkProjectIDString) }
        set { objectWillChange.send(); checkProjectIDString = newValue?.uuidString ?? "" }
    }

    func open(_ routes: [Route], in tab: AppTab) {
        self.tab = tab
        var p = NavigationPath(); routes.forEach { p.append($0) }
        switch tab {
        case .home: homePath = p
        case .shows: showsPath = p
        case .check: checkPath = p
        case .reports: break
        }
    }

    func startCheck(_ pid: UUID) {
        checkProjectID = pid
        tab = .check
        checkPath = NavigationPath()
    }
}
