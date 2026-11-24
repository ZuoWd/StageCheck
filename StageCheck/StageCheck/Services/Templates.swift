import Foundation

enum ShowTemplate: String, CaseIterable, Identifiable {
    case smallBand = "Small Band", fullBand = "Full Band", acoustic = "Acoustic Performance"
    case dj = "DJ Setup", church = "Church Audio", empty = "Empty Show"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smallBand: return "music.mic"
        case .fullBand: return "music.quarternote.3"
        case .acoustic: return "guitars"
        case .dj: return "opticaldisc"
        case .church: return "building.columns"
        case .empty: return "square.dashed"
        }
    }

    typealias Row = (String, InputType, String, Bool)

    private var rows: [Row] {
        switch self {
        case .smallBand:
            return [("Kick", .drum, "Kick Drum", false), ("Snare", .drum, "Snare Top", false),
                    ("OH L", .drum, "Overhead Left", true), ("OH R", .drum, "Overhead Right", true),
                    ("Bass DI", .bass, "Bass Amp DI Out", false), ("Gtr", .guitar, "Guitar Cab", false),
                    ("Lead Vox", .vocal, "Lead Vocal", false), ("BV", .vocal, "Backing Vocal", false)]
        case .fullBand:
            return [("Kick In", .drum, "Kick Inside", false), ("Kick Out", .drum, "Kick Front", false),
                    ("Snare Top", .drum, "Snare Top", false), ("Snare Btm", .drum, "Snare Bottom", false),
                    ("Hi-Hat", .drum, "Hi-Hat", true), ("Tom 1", .drum, "Rack Tom", false),
                    ("Tom 2", .drum, "Floor Tom", false), ("OH L", .drum, "Overhead Left", true),
                    ("OH R", .drum, "Overhead Right", true), ("Bass DI", .bass, "Bass DI", false),
                    ("Bass Mic", .bass, "Bass Cab", false), ("Gtr 1", .guitar, "Guitar 1 Cab", false),
                    ("Gtr 2", .guitar, "Guitar 2 Cab", false), ("Keys L", .keyboard, "Keyboard Left", false),
                    ("Keys R", .keyboard, "Keyboard Right", false), ("Lead Vox", .vocal, "Lead Vocal", false),
                    ("BV 1", .vocal, "Backing Vocal 1", false), ("BV 2", .vocal, "Backing Vocal 2", false),
                    ("Spare Vox", .vocal, "Spare / Talk Mic", false)]
        case .acoustic:
            return [("Ac Gtr DI", .guitar, "Acoustic Guitar Pickup", false), ("Ac Gtr Mic", .guitar, "Acoustic Guitar Mic", true),
                    ("Vox", .vocal, "Lead Vocal", false), ("Harmony", .vocal, "Harmony Vocal", false),
                    ("Cajon", .drum, "Cajon", false)]
        case .dj:
            return [("DJ L", .dj, "DJ Mixer Master L", false), ("DJ R", .dj, "DJ Mixer Master R", false),
                    ("DJ Booth L", .dj, "DJ Mixer Booth L", false), ("DJ Booth R", .dj, "DJ Mixer Booth R", false),
                    ("MC Mic", .wireless, "Wireless Handheld", false)]
        case .church:
            return [("Pastor", .wireless, "Pastor Headset", false), ("Pulpit", .microphone, "Pulpit Mic", true),
                    ("Worship Lead", .vocal, "Worship Leader Vocal", false), ("Choir L", .microphone, "Choir Left", true),
                    ("Choir R", .microphone, "Choir Right", true), ("Piano L", .keyboard, "Piano Left", false),
                    ("Piano R", .keyboard, "Piano Right", false), ("Ac Gtr", .guitar, "Acoustic Guitar DI", false),
                    ("Video L", .playback, "Video Playback L", false), ("Video R", .playback, "Video Playback R", false)]
        case .empty:
            return []
        }
    }

    func channels() -> [InputChannel] {
        rows.enumerated().map { i, r in
            InputChannel(channelNumber: i + 1, name: r.0, inputType: r.1, sourceName: r.2,
                         stageBoxName: "Stage Box A", stageBoxInput: "\(i + 1)", consoleChannel: "\(i + 1)", phantom: r.3)
        }
    }

    func makeProject(title: String, engineer: String) -> ShowProject {
        var p = ShowProject(); p.title = title; p.engineer = engineer; p.channels = channels()
        return p
    }
}

enum SampleData {
    static func project() -> ShowProject {
        var p = ShowTemplate.smallBand.makeProject(title: "Sample Show — Friday Night Live", engineer: "Sample Engineer")
        p.artist = "Sample Artist"; p.venue = "Sample Venue Club"; p.isSample = true; p.status = .soundcheck
        p.showDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        p.descriptionText = "This is sample data that demonstrates the StageCheck workflow. You can edit or delete it."
        // Leave guitar unassigned on console and duplicate a stage box input to demonstrate warnings.
        if p.channels.count > 7 { p.channels[5].consoleChannel = ""; p.channels[7].stageBoxInput = "7" }
        let now = Date()
        for i in 0..<min(4, p.channels.count) {
            p.channels[i].records = [LineCheckRecord(checkType: "Signal Present", status: .passed, checkedAt: now.addingTimeInterval(Double(-600 + i * 60)))]
        }
        if p.channels.count > 4 {
            p.channels[4].records = [LineCheckRecord(checkType: "Noise / Hum Check", status: .failed,
                                                     issueDescription: "Audible hum on DI output",
                                                     correctiveAction: "Try ground lift and replace XLR cable",
                                                     checkedAt: now.addingTimeInterval(-120))]
        }
        p.showNotes = [ShowNote(title: "Load-in", content: "Load-in at 4:00 PM. Stage box placed stage left.", category: .setup),
                       ShowNote(channelID: p.channels.count > 4 ? p.channels[4].id : nil, title: "Bass DI hum",
                                content: "Check power for bass amp; consider a different outlet.", category: .equipment)]
        return p
    }
}
