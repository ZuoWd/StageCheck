import Foundation

struct PatchWarning: Identifiable, Hashable {
    enum Kind: String { case duplicateStageBox = "Duplicate Stage Box Input", duplicateConsole = "Duplicate Console Channel",
                        noDestination = "No Destination", incomplete = "Incomplete Patch" }
    let id = UUID()
    let kind: Kind
    let channelIDs: [UUID]
    let message: String
}

enum PatchAnalyzer {
    private static func key(_ a: String, _ b: String) -> String { "\(a.trimmed.lowercased())|\(b.trimmed.lowercased())" }

    static func warnings(for channels: [InputChannel]) -> [PatchWarning] {
        var out: [PatchWarning] = []
        let sorted = channels.sorted { $0.channelNumber < $1.channelNumber }

        let sb = Dictionary(grouping: sorted.filter(\.hasStageBox)) { key($0.stageBoxName, $0.stageBoxInput) }
        for (_, group) in sb where group.count > 1 {
            let f = group[0]
            out.append(.init(kind: .duplicateStageBox, channelIDs: group.map(\.id),
                             message: "\(f.stageBoxName.trimmed.isEmpty ? "Stage box" : f.stageBoxName) input \(f.stageBoxInput) used by CH \(group.map { String($0.channelNumber) }.joined(separator: ", "))"))
        }
        let cc = Dictionary(grouping: sorted.filter(\.hasConsole)) { key($0.consoleName, $0.consoleChannel) }
        for (_, group) in cc where group.count > 1 {
            out.append(.init(kind: .duplicateConsole, channelIDs: group.map(\.id),
                             message: "Console channel \(group[0].consoleChannel) used by CH \(group.map { String($0.channelNumber) }.joined(separator: ", "))"))
        }
        for c in sorted {
            if !c.hasConsole && !c.hasStageBox {
                out.append(.init(kind: .noDestination, channelIDs: [c.id], message: "CH \(c.channelNumber) \(c.name) has no patch destination"))
            } else if !c.isPatchComplete {
                out.append(.init(kind: .incomplete, channelIDs: [c.id],
                                 message: "CH \(c.channelNumber) \(c.name) is missing \(c.hasConsole ? "a stage box input" : "a console channel")"))
            }
        }
        return out.sorted { $0.message < $1.message }
    }

    static func flagged(_ channels: [InputChannel]) -> Set<UUID> {
        Set(warnings(for: channels).filter { $0.kind == .duplicateConsole || $0.kind == .duplicateStageBox }.flatMap(\.channelIDs))
    }
}
