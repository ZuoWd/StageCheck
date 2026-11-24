import Foundation

enum CSVExporter {
    nonisolated static func escape(_ s: String) -> String {
        var v = s
        // Neutralise spreadsheet formula injection.
        if let f = v.first, "=+-@".contains(f), Double(v) == nil { v = "'" + v }
        return v.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) ? "\"\(v.replacingOccurrences(of: "\"", with: "\"\""))\"" : v
    }

    static func make(_ header: [String], _ rows: [[String]]) -> Data {
        let lines = ([header] + rows).map { $0.map(escape).joined(separator: ",") }
        return Data(("\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    static func inputs(_ p: ShowProject) -> Data {
        make(["Channel", "Name", "Input Type", "Source", "Equipment Model", "Stage Box", "Stage Box Input", "Console", "Console Channel",
              "Phantom +48V", "Gain Reference", "Pan", "Monitor Notes", "Cable Label", "Color Tag", "Notes", "Check Status"],
             p.sortedChannels.map { c in
                 ["\(c.channelNumber)", c.name, c.inputType.rawValue, c.sourceName, c.equipmentModel, c.stageBoxName, c.stageBoxInput, c.consoleName,
                  c.consoleChannel, c.phantomPowerRequired ? "Yes" : "No", c.gainReference, c.pan, c.monitorNotes, c.cableLabel, c.colorTag.rawValue, c.notes, c.checkStatus.rawValue]
             })
    }

    static func patch(_ p: ShowProject) -> Data {
        let flags = PatchAnalyzer.flagged(p.channels)
        return make(["Channel", "Source", "Stage Box", "Stage Box Input", "Console", "Console Channel", "Cable Label", "Notes", "Patch Status"],
                    p.channels.sorted { $0.channelNumber < $1.channelNumber }.map { c in
                        ["\(c.channelNumber)", c.sourceName.ifEmpty(c.name), c.stageBoxName, c.stageBoxInput, c.consoleName, c.consoleChannel, c.cableLabel, c.notes,
                         flags.contains(c.id) ? "Conflict" : c.isPatchComplete ? "Complete" : (c.hasConsole || c.hasStageBox) ? "Incomplete" : "Unassigned"]
                    })
    }

    static func checks(_ p: ShowProject) -> Data {
        var rows: [[String]] = []
        for c in p.sortedChannels {
            for r in c.records.sorted(by: { $0.checkedAt < $1.checkedAt }) {
                rows.append(["\(c.channelNumber)", c.name, r.checkType, r.status.rawValue, ISO8601DateFormatter().string(from: r.checkedAt),
                             r.issueDescription, r.correctiveAction, r.notes])
            }
        }
        return make(["Channel", "Name", "Check Item", "Result", "Checked At", "Issue", "Corrective Action", "Notes"], rows)
    }

    // MARK: Import (input list)
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        var it = text.replacingOccurrences(of: "\u{FEFF}", with: "").makeIterator()
        var pending: Character? = nil
        while let ch = pending ?? it.next() {
            pending = nil
            if quoted {
                if ch == "\"" { if let n = it.next() { if n == "\"" { field.append("\"") } else { quoted = false; pending = n } } else { quoted = false } }
                else { field.append(ch) }
            } else {
                switch ch {
                case "\"": quoted = true
                case ",": row.append(field); field = ""
                case "\n", "\r\n", "\r": row.append(field); field = ""; if row.contains(where: { !$0.isEmpty }) { rows.append(row) }; row = []
                default: field.append(ch)
                }
            }
        }
        row.append(field); if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }

    /// Imports channels from a CSV with a header row (as produced by the Input List export).
    static func importChannels(_ text: String, startNumber: Int) -> [InputChannel] {
        let rows = parse(text)
        guard let header = rows.first?.map({ $0.trimmed.lowercased() }) else { return [] }
        func col(_ names: String...) -> Int? { header.firstIndex { names.contains($0) } }
        let iNum = col("channel", "ch", "channel number"), iName = col("name", "channel name"), iType = col("input type", "type")
        let iSrc = col("source", "source name"), iEq = col("equipment model", "equipment"), iSB = col("stage box"), iSBI = col("stage box input")
        let iCon = col("console"), iCC = col("console channel"), iPh = col("phantom +48v", "phantom", "phantom power")
        let iGain = col("gain reference", "gain"), iPan = col("pan"), iMon = col("monitor notes"), iCab = col("cable label"), iNotes = col("notes")
        guard iName != nil || iSrc != nil else { return [] }
        var n = startNumber
        return rows.dropFirst().prefix(512).compactMap { r in
            func v(_ i: Int?) -> String { guard let i, i < r.count else { return "" }; return String(r[i].trimmed.prefix(200)) }
            let name = v(iName).ifEmpty(v(iSrc))
            guard !name.trimmed.isEmpty else { return nil }
            var c = InputChannel(channelNumber: Int(v(iNum)) ?? n, name: name)
            n = max(n, c.channelNumber) + 1
            c.inputType = InputType.allCases.first { $0.rawValue.lowercased() == v(iType).lowercased() } ?? .other
            c.sourceName = v(iSrc); c.equipmentModel = v(iEq); c.stageBoxName = v(iSB); c.stageBoxInput = v(iSBI)
            c.consoleName = v(iCon); c.consoleChannel = v(iCC); c.phantomPowerRequired = ["yes", "true", "1", "on"].contains(v(iPh).lowercased())
            c.gainReference = v(iGain); c.pan = v(iPan); c.monitorNotes = v(iMon); c.cableLabel = v(iCab); c.notes = v(iNotes)
            return c
        }
    }
}
