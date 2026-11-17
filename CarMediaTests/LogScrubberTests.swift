// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation
@testable import CarMedia
import Testing

@Suite struct LogScrubberTests {
    @Test func urlQueryIsDropped() {
        let s = LogScrubber.scrubURL("https://host/path?token=abc123#frag")
        #expect(s == "https://host/path")
    }

    @Test func urlsInTextAreScrubbed() {
        let out = LogScrubber.scrub("loaded https://video.example/x.m3u8?sig=SECRET done")
        #expect(!out.contains("SECRET"))
        #expect(out.contains("https://video.example/x.m3u8"))
    }

    @Test func emailsRedacted() {
        #expect(LogScrubber.scrub("mail ana@example.com now") == "mail <email> now")
    }

    @Test func bearerRedacted() {
        let out = LogScrubber.scrub("Authorization: Bearer xyz.abc.def")
        #expect(!out.contains("xyz.abc.def"))
    }

    @Test func containerPathsRedacted() {
        let out = LogScrubber.scrub("file /var/mobile/Containers/Data/Application/ABC/x.mp4")
        #expect(!out.contains("Containers"))
    }
}
