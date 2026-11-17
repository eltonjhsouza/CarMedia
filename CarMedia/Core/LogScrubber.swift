// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation

/// Redacts sensitive material from log text before it is exported or shown
/// outside the app: URL query/fragment (they carry tokens and session ids),
/// email addresses, bearer/api keys, and file paths under the container.
public enum LogScrubber {
    /// Full URL -> origin + path, query dropped.
    public static func scrubURL(_ raw: String) -> String {
        guard var comps = URLComponents(string: raw) else { return "<url?>" }
        comps.query = nil
        comps.fragment = nil
        if comps.user != nil { comps.user = nil; comps.password = nil }
        return comps.string ?? "<url?>"
    }

    public static func scrub(_ text: String) -> String {
        var out = text
        // URLs with schemes: keep scheme://host/path only.
        out = replace(in: out, pattern: #"https?://[^\s\"']+"#) { match in
            scrubURL(match)
        }
        // Emails
        out = replace(in: out, pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#) { _ in "<email>" }
        // Bearer tokens and key=value secret shapes
        out = replace(in: out, pattern: #"(?i)\bbearer\s+[^\s\"']+"#) { _ in "<redacted>" }
        out = replace(in: out, pattern: #"(?i)(token|apikey|api_key|secret)[\"'=: ]+[^\s,\"'}]+"#) { _ in "<redacted>" }
        // iOS container paths
        out = replace(in: out, pattern: #"/var/mobile/Containers/[^ \t\r\n]+"#) { _ in "<container-path>" }
        return out
    }

    private static func replace(in text: String, pattern: String, _ transform: (String) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var out = ""
        var last = 0
        re.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let r = m?.range else { return }
            out += ns.substring(with: NSRange(location: last, length: r.location - last))
            out += transform(ns.substring(with: r))
            last = r.location + r.length
        }
        out += ns.substring(from: last)
        return out
    }
}
