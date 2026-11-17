// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation
@testable import CarMedia
import Testing

@Suite struct URLNormalizerTests {
    @Test func empty() {
        #expect(URLNormalizer.interpret("") == .empty)
        #expect(URLNormalizer.interpret("   ") == .empty)
    }

    @Test func explicitScheme() {
        #expect(URLNormalizer.interpret("https://example.com") ==
                .url(URL(string: "https://example.com")!))
        #expect(URLNormalizer.interpret("http://example.com/a?b=1") ==
                .url(URL(string: "http://example.com/a?b=1")!))
    }

    @Test func bareHost() {
        #expect(URLNormalizer.interpret("example.com") ==
                .url(URL(string: "https://example.com")!))
        #expect(URLNormalizer.interpret("sub.example.co.uk/path") ==
                .url(URL(string: "https://sub.example.co.uk/path")!))
    }

    @Test func spacesAreSearch() {
        #expect(URLNormalizer.interpret("big buck bunny mp4") == .search("big buck bunny mp4"))
    }

    @Test func noDotSingleWordIsSearch() {
        #expect(URLNormalizer.interpret("carplay") == .search("carplay"))
    }

    @Test func searchURLCarriesQuery() {
        let url = URLNormalizer.searchURL(for: "car play")
        #expect(url?.absoluteString.hasPrefix("https://duckduckgo.com/html?q=car") ?? false)
    }

    @Test func weirdInputDoesNotCrash() {
        _ = URLNormalizer.interpret("ht!tp://%%%")
        _ = URLNormalizer.interpret("://")
        _ = URLNormalizer.interpret("a..b")
    }
}
