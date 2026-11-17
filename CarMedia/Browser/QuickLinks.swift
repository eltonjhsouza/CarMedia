// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation

public struct QuickLink: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let url: String
    public let mayHaveDRM: Bool
    public init(_ name: String, _ url: String, drm: Bool) {
        self.name = name; self.url = url; self.mayHaveDRM = drm
    }
}

/// Initial shortcuts. Services that ship FairPlay/Widevine content are
/// flagged so the UI can state plainly: a browser tab does NOT promise DRM
/// playback — those streams require the services' own apps / AirPlay video.
public enum QuickLinks {
    public static let all: [QuickLink] = [
        .init("YouTube",  "https://m.youtube.com",            drm: false),
        .init("Pluto TV", "https://pluto.tv",                 drm: false),
        .init("Twitch",   "https://www.twitch.tv",            drm: false),
        .init("Netflix",  "https://www.netflix.com",          drm: true),
        .init("Prime Video", "https://www.primevideo.com",    drm: true),
        .init("Disney+",  "https://www.disneyplus.com",       drm: true),
    ]

    /// Honest, non-clickable note shown next to DRM-flagged services.
    public static func drmNote(for link: QuickLink) -> String? {
        guard link.mayHaveDRM else { return nil }
        return "\(link.name) usa DRM: páginas protegidas podem não reproduzir dentro de um navegador de terceiro."
    }
}
