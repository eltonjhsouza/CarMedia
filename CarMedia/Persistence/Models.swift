// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation
import SwiftData

@Model
public final class Favorite {
    @Attribute(.unique) public var url: URL
    public var title: String
    public var addedAt: Date
    public init(url: URL, title: String, addedAt: Date = .now) {
        self.url = url; self.title = title; self.addedAt = addedAt
    }
}

@Model
public final class HistoryEntry {
    public var url: URL
    public var title: String
    public var visitedAt: Date
    public init(url: URL, title: String, visitedAt: Date = .now) {
        self.url = url; self.title = title; self.visitedAt = visitedAt
    }
}

/// Shared store for favorites and history (SwiftData).
@MainActor
public enum Persistence {
    public static let container: ModelContainer = {
        let schema = Schema([Favorite.self, HistoryEntry.self])
        let config = ModelConfiguration(schema: schema)
        do { return try ModelContainer(for: schema, configurations: [config]) }
        catch {
            EventLog.shared.record(.app, "SwiftData init failed: \(error.localizedDescription)")
            return try! ModelContainer(for: schema, configurations: [ModelConfiguration(inMemory: true)])
        }
    }()

    @discardableResult
    public static func recordVisit(url: URL, title: String, context: ModelContext) -> Bool {
        context.insert(HistoryEntry(url: url, title: title))
        try? context.save()
        return true
    }
}
