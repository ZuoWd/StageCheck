import Combine
import Foundation
import SwiftUI

/// Offline-first local persistence. Data is stored as JSON in Application Support
/// (atomic writes, file protection). Compatible with iOS 16.
@MainActor
final class Store: ObservableObject {
    struct Snapshot: Codable {
        var schemaVersion = 1
        var projects: [ShowProject] = []
        var reports: [ReportRecord] = []
        var customChecks: [String] = []
    }

    @Published var projects: [ShowProject] = [] { didSet { scheduleSave() } }
    @Published var reports: [ReportRecord] = [] { didSet { scheduleSave() } }
    @Published var customChecks: [String] = [] { didSet { scheduleSave() } }
    @Published var lastError: String?

    private var loading = false
    private var saveTask: Task<Void, Never>?

    static var dataURL: URL { FileStorage.appSupport.appendingPathComponent("stagecheck-data.json") }

    init(inMemory: Bool = false) {
        guard !inMemory else { return }
        load()
    }

    var checkItems: [String] { defaultCheckItems + customChecks }

    // MARK: Persistence
    func load() {
        loading = true; defer { loading = false }
        guard let data = try? Data(contentsOf: Self.dataURL) else { return }
        do {
            let snap = try JSONDecoder().decode(Snapshot.self, from: data)
            projects = snap.projects; reports = snap.reports; customChecks = snap.customChecks
        } catch {
            // Keep a copy of the unreadable file rather than overwriting it.
            try? FileManager.default.copyItem(at: Self.dataURL, to: Self.dataURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))"))
            lastError = "Saved data could not be read. A backup copy was kept."
        }
    }

    private func scheduleSave() {
        guard !loading else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        let snap = Snapshot(projects: projects, reports: reports, customChecks: customChecks)
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: Self.dataURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            lastError = "Could not save data: \(error.localizedDescription)"
        }
    }

    // MARK: Projects
    func index(of id: UUID) -> Int? { projects.firstIndex { $0.id == id } }
    func project(_ id: UUID) -> ShowProject? { projects.first { $0.id == id } }

    func binding(for id: UUID) -> Binding<ShowProject>? {
        guard project(id) != nil else { return nil }
        return Binding(get: { [weak self] in self?.project(id) ?? ShowProject() },
                       set: { [weak self] new in self?.update(new) })
    }

    func update(_ p: ShowProject) {
        guard let i = index(of: p.id) else { return }
        var p = p; p.updatedAt = Date(); projects[i] = p
    }

    func mutate(_ id: UUID, _ change: (inout ShowProject) -> Void) {
        guard let i = index(of: id) else { return }
        var p = projects[i]; change(&p); p.updatedAt = Date(); projects[i] = p
    }

    @discardableResult
    func add(_ p: ShowProject) -> ShowProject { projects.append(p); return p }

    func duplicate(_ id: UUID) {
        guard var p = project(id) else { return }
        p.id = UUID(); p.title = p.displayTitle + " Copy"; p.isSample = false
        p.createdAt = Date(); p.updatedAt = Date(); p.status = .planning
        var map: [UUID: UUID] = [:]
        p.channels = p.channels.map { var c = $0; let n = UUID(); map[c.id] = n; c.id = n; c.records = []; return c }
        p.showNotes = p.showNotes.map { var n = $0; n.id = UUID(); n.channelID = n.channelID.flatMap { map[$0] }; return n }
        projects.append(p)
    }

    func delete(_ id: UUID) {
        projects.removeAll { $0.id == id }
        // Cascade: remove report files and history for this show.
        for r in reports where r.projectID == id { FileStorage.remove(r.fileName) }
        reports.removeAll { $0.projectID == id }
    }

    // MARK: Channels
    func nextChannelNumber(_ pid: UUID) -> Int { (project(pid)?.channels.map(\.channelNumber).max() ?? 0) + 1 }

    func upsert(_ c: InputChannel, in pid: UUID) {
        mutate(pid) { p in
            if let i = p.channels.firstIndex(where: { $0.id == c.id }) { var n = c; n.records = p.channels[i].records; p.channels[i] = n }
            else { var c = c; c.sortOrder = (p.channels.map(\.sortOrder).max() ?? 0) + 1; p.channels.append(c) }
        }
    }

    func deleteChannel(_ cid: UUID, in pid: UUID) {
        mutate(pid) { p in
            p.channels.removeAll { $0.id == cid }
            for i in p.showNotes.indices where p.showNotes[i].channelID == cid { p.showNotes[i].channelID = nil }
        }
    }

    func duplicateChannel(_ cid: UUID, in pid: UUID) {
        guard let src = project(pid)?.channels.first(where: { $0.id == cid }) else { return }
        var c = src; c.id = UUID(); c.records = []; c.name += " Copy"; c.channelNumber = nextChannelNumber(pid)
        upsert(c, in: pid)
    }

    func reorderChannels(_ ordered: [InputChannel], in pid: UUID) {
        mutate(pid) { p in
            for (i, c) in ordered.enumerated() { if let j = p.channels.firstIndex(where: { $0.id == c.id }) { p.channels[j].sortOrder = i } }
        }
    }

    func addRecord(_ r: LineCheckRecord, channel cid: UUID, in pid: UUID) {
        mutate(pid) { p in
            if let i = p.channels.firstIndex(where: { $0.id == cid }) { p.channels[i].records.append(r) }
        }
    }

    // MARK: Reports
    func deleteReport(_ r: ReportRecord) {
        FileStorage.remove(r.fileName)
        reports.removeAll { $0.id == r.id }
    }

    func eraseAll() {
        for r in reports { FileStorage.remove(r.fileName) }
        projects = []; reports = []; customChecks = []
        saveNow()
    }
}
