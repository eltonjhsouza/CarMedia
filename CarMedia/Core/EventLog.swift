// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation

/// Central event log used by every subsystem and shown on the Diagnostics
/// screen. Entries are kept in memory (bounded ring) and mirrored to a file
/// in the app container so they can be pulled with `devicectl` or shared.
/// Everything leaving the app for display/export passes through LogScrubber.
public final class EventLog {
    public static let shared = EventLog()

    public enum Category: String {
        case app = "APP", browser = "WEB", player = "PLAYER",
        carplay = "CARPLAY", mirror = "MIRROR", diag = "DIAG", flag = "FLAG"
    }

    public struct Entry: Identifiable, Sendable {
        public let id = UUID()
        public let date: Date
        public let category: Category
        public let message: String
    }

    private let queue = DispatchQueue(label: "dev.carmedia.eventlog")
    private var entries: [Entry] = []
    private let memoryCap = 500
    private lazy var fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("diagnostics.log")
    }()

    private init() {}

    public func record(_ category: Category, _ message: String) {
        let entry = Entry(date: .now, category: category, message: message)
        queue.async {
            self.entries.append(entry)
            if self.entries.count > self.memoryCap {
                self.entries.removeFirst(self.entries.count - self.memoryCap)
            }
            self.appendToDisk(entry)
        }
        #if DEBUG
        print("[\(category.rawValue)] \(message)")
        #endif
    }

    public var snapshot: [Entry] { queue.sync { entries } }

    /// Scrubbed, redacted export — no raw URLs, tokens or paths.
    public func scrubbedExport() -> String {
        snapshot.map { e in
            "\(ISO8601DateFormatter().string(from: e.date)) [\(e.category.rawValue)] \(LogScrubber.scrub(e.message))"
        }.joined(separator: "\n")
    }

    private func appendToDisk(_ entry: Entry) {
        let line = "\(entry.date.ISO8601String) [\(entry.category.rawValue)] \(entry.message)\n"
        if FileManager.default.fileExists(atPath: fileURL.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int, size > 400_000 {
            // Keep the file bounded: drop it and reseed with the tail.
            let keep = snapshot.suffix(100).map { "\($0.date.ISO8601String) [\($0.category.rawValue)] \($0.message)" }.joined(separator: "\n")
            try? (keep + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}

extension Date {
    var ISO8601String: String { ISO8601DateFormatter().string(from: self) }
}
