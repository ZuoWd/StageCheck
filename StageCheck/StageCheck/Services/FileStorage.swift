import Foundation

enum FileStorage {
    static var appSupport: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Permanent report storage (Documents/Reports, excluded from nothing so it is backed up).
    static var reportsDir: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Reports", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for fileName: String) -> URL { reportsDir.appendingPathComponent(fileName) }
    static func exists(_ fileName: String) -> Bool { FileManager.default.fileExists(atPath: url(for: fileName).path) }
    static func remove(_ fileName: String) { try? FileManager.default.removeItem(at: url(for: fileName)) }

    static func write(_ data: Data, name: String) throws -> URL {
        let u = url(for: name)
        try data.write(to: u, options: .atomic)
        return u
    }

    static func safeName(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = String(s.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }).trimmed
        return String((cleaned.isEmpty ? "Show" : cleaned).replacingOccurrences(of: " ", with: "_").prefix(60))
    }

    /// Temporary file for ad-hoc sharing (e.g. full data export).
    static func temp(_ data: Data, name: String) throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: u, options: .atomic)
        return u
    }
}
