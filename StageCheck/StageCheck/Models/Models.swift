import Foundation

enum ShowStatus: String, Codable, CaseIterable, Identifiable {
    case planning = "Planning", preparing = "Preparing", soundcheck = "Soundcheck", completed = "Completed", archived = "Archived"
    var id: String { rawValue }
}

enum InputType: String, Codable, CaseIterable, Identifiable {
    case vocal = "Vocal", drum = "Drum", guitar = "Guitar", bass = "Bass", keyboard = "Keyboard", playback = "Playback"
    case dj = "DJ", microphone = "Microphone", instrument = "Instrument", wireless = "Wireless", other = "Other"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .vocal: return "mic.fill"
        case .drum: return "circle.circle.fill"
        case .guitar: return "guitars.fill"
        case .bass: return "waveform.path"
        case .keyboard: return "pianokeys"
        case .playback: return "play.rectangle.fill"
        case .dj: return "opticaldisc.fill"
        case .microphone: return "mic"
        case .instrument: return "music.note"
        case .wireless: return "antenna.radiowaves.left.and.right"
        case .other: return "cable.connector"
        }
    }
}

enum CheckStatus: String, Codable, CaseIterable, Identifiable {
    case notChecked = "Not Checked", passed = "Passed", failed = "Failed", skipped = "Skipped"
    var id: String { rawValue }
}

enum NoteCategory: String, Codable, CaseIterable, Identifiable {
    case setup = "Setup", soundcheck = "Soundcheck", equipment = "Equipment", monitoring = "Monitoring", general = "General"
    var id: String { rawValue }
}

enum ReportType: String, Codable, CaseIterable, Identifiable {
    case pdf = "PDF Show Report", inputsCSV = "Input List CSV", patchCSV = "Patch CSV", checkCSV = "Line Check CSV"
    var id: String { rawValue }
    var fileExtension: String { self == .pdf ? "pdf" : "csv" }
    var icon: String { self == .pdf ? "doc.richtext.fill" : "tablecells.fill" }
}

enum ColorTag: String, Codable, CaseIterable, Identifiable {
    case none = "None", blue = "Blue", green = "Green", orange = "Orange", red = "Red", purple = "Purple", yellow = "Yellow", gray = "Gray"
    var id: String { rawValue }
}

let defaultCheckItems = ["Signal Present", "Source Verified", "Noise / Hum Check", "Polarity Check",
                         "Phantom Power Verification", "Monitor Feed Verification", "Additional Check"]

struct LineCheckRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var checkType: String
    var status: CheckStatus
    var issueDescription = ""
    var correctiveAction = ""
    var checkedAt = Date()
    var notes = ""
}

struct InputChannel: Codable, Identifiable, Hashable {
    var id = UUID()
    var channelNumber: Int
    var name: String
    var inputType: InputType = .microphone
    var sourceName = ""
    var equipmentModel = ""
    var stageBoxName = ""
    var stageBoxInput = ""
    var consoleName = ""
    var consoleChannel = ""
    var phantomPowerRequired = false
    var gainReference = ""
    var pan = ""
    var monitorNotes = ""
    var cableLabel = ""
    var colorTag: ColorTag = .none
    var notes = ""
    var sortOrder = 0
    var records: [LineCheckRecord] = []

    /// Most recent record for each check item (retests supersede earlier results; history is kept).
    var latestByItem: [LineCheckRecord] {
        var map: [String: LineCheckRecord] = [:]
        for r in records where (map[r.checkType]?.checkedAt ?? .distantPast) <= r.checkedAt { map[r.checkType] = r }
        return map.values.sorted { $0.checkedAt > $1.checkedAt }
    }
    var checkStatus: CheckStatus {
        let latest = latestByItem
        if latest.isEmpty { return .notChecked }
        if latest.contains(where: { $0.status == .failed }) { return .failed }
        if latest.contains(where: { $0.status == .passed }) { return .passed }
        return .skipped
    }
    var openIssues: [LineCheckRecord] { latestByItem.filter { $0.status == .failed } }
    var hasStageBox: Bool { !stageBoxInput.trimmed.isEmpty }
    var hasConsole: Bool { !consoleChannel.trimmed.isEmpty }
    var isPatchComplete: Bool { hasStageBox && hasConsole }
    var patchSummary: String {
        if !hasStageBox && !hasConsole { return "Unassigned" }
        let sb = hasStageBox ? "\(stageBoxName.trimmed.isEmpty ? "SB" : stageBoxName) \(stageBoxInput)" : "—"
        let cc = hasConsole ? "CH \(consoleChannel)" : "—"
        return "\(sb) → \(cc)"
    }

    init(channelNumber: Int, name: String, inputType: InputType = .microphone, sourceName: String = "",
         equipmentModel: String = "", stageBoxName: String = "", stageBoxInput: String = "",
         consoleChannel: String = "", phantom: Bool = false) {
        self.channelNumber = channelNumber; self.name = name; self.inputType = inputType
        self.sourceName = sourceName; self.equipmentModel = equipmentModel; self.stageBoxName = stageBoxName
        self.stageBoxInput = stageBoxInput; self.consoleChannel = consoleChannel
        self.phantomPowerRequired = phantom; self.sortOrder = channelNumber
    }
}

struct ShowNote: Codable, Identifiable, Hashable {
    var id = UUID()
    var channelID: UUID?
    var title = ""
    var content = ""
    var category: NoteCategory = .general
    var createdAt = Date()
}

struct ShowProject: Codable, Identifiable, Hashable {
    var id = UUID()
    var title = ""
    var artist = ""
    var venue = ""
    var showDate = Date()
    var engineer = ""
    var descriptionText = ""
    var notes = ""
    var status: ShowStatus = .planning
    var isSample = false
    var createdAt = Date()
    var updatedAt = Date()
    var channels: [InputChannel] = []
    var showNotes: [ShowNote] = []

    var sortedChannels: [InputChannel] { channels.sorted { ($0.sortOrder, $0.channelNumber) < ($1.sortOrder, $1.channelNumber) } }
    func count(_ s: CheckStatus) -> Int { channels.filter { $0.checkStatus == s }.count }
    var checkProgress: Double { channels.isEmpty ? 0 : Double(channels.count - count(.notChecked)) / Double(channels.count) }
    var patchProgress: Double { channels.isEmpty ? 0 : Double(channels.filter(\.isPatchComplete).count) / Double(channels.count) }
    var openIssueCount: Int { channels.reduce(0) { $0 + $1.openIssues.count } }
    var displayTitle: String { title.trimmed.isEmpty ? "Untitled Show" : title }
}

struct ReportRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var projectID: UUID
    var showName: String
    var reportName: String
    var reportType: ReportType
    var fileName: String
    var createdAt = Date()
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
