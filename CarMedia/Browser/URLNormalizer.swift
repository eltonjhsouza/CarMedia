// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation

/// Turns what the user typed into either a URL or a web search.
/// Pure logic — unit tested on CI without a simulator network.
public enum URLNormalizer {
    public static let searchEngine = URLComponents(string: "https://duckduckgo.com/")!

    public enum Input: Equatable {
        case url(URL)
        case search(String)
        case empty
        case invalid(String)
    }

    public static func interpret(_ raw: String) -> Input {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .empty }

        // Explicit scheme
        if let url = URL(string: text), url.scheme != nil, url.host != nil,
           ["http", "https"].contains(url.scheme?.lowercased()) {
            return .url(url)
        }

        // "host:port/path" style without scheme, or contains spaces -> not a URL
        if text.contains(" ") || text.contains("\t") { return .search(text) }

        // Bare-word dotted host (looks like example.com / sub.example.com.br)
        let hostCandidate = text.hasPrefix("localhost") ||
            (text.range(of: #"^[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})(:\d+)?(/\S*)?$"#, options: .regularExpression) != nil
             && text.contains("."))
        if hostCandidate, !text.hasSuffix(".") {
            if let url = URL(string: "https://" + text) , url.host != nil {
                return .url(url)
            }
            return .invalid(text)
        }

        // Single token that is clearly not a host (no dot) -> search
        if !text.contains(".") { return .search(text) }
        return .invalid(text)
    }

    public static func searchURL(for query: String) -> URL? {
        var comps = searchEngine
        comps.path = "/html"
        comps.queryItems = [URLQueryItem(name: "q", value: query)]
        return comps.url
    }

    public static func homeURL() -> URL { URL(string: "https://duckduckgo.com/")! }
}
