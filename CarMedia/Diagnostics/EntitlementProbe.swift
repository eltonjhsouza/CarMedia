// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation

/// Reads the entitlements actually embedded in the code signature.
///
/// The supported, non-API way: signed non-App-Store builds carry
/// `embedded.mobileprovision` in the bundle; its XML section lists the
/// entitlements granted by the profile. App Store re-signing strips the
/// file, so absence here does not prove absence of entitlements in that
/// distribution channel — the probe reports UNKNOWN then, never a lie.
public enum EntitlementProbe {
    public struct Result {
        public var entitlements: [String: Bool]
        public var source: Source
        public enum Source { case mobileProvision, appStoreSigned, simulatorBuild, unsigned, notFound }
    }

    public static func current() async -> [String: Bool] {
        let r = full()
        return r.entitlements
    }

    public static func full() -> Result {
        #if targetEnvironment(simulator)
        return Result(entitlements: [:], source: .simulatorBuild)
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url)
        else {
            // No profile: either unsigned build or App Store re-sign.
            return Result(entitlements: [:], source: .notFound)
        }
        guard let plist = extractPlist(from: data) else {
            return Result(entitlements: [:], source: .notFound)
        }
        // Profile layout: { … "Entitlements" = { com.apple.developer… } … }
        guard let ents = plist["Entitlements"] as? [String: Any] else {
            return Result(entitlements: [:], source: .appStoreSigned)
        }
        var out: [String: Bool] = [:]
        for (k, v) in ents {
            if k.hasPrefix("com.apple.developer") {
                out[k] = (v as? Bool) ?? true
            }
        }
        return Result(entitlements: out, source: .mobileProvision)
    }

    /// The provisioning profile is PKCS#7; the embedded plist XML can be
    /// located between <?xml and </plist> without any crypto parsing.
    private static func extractPlist(from data: Data) -> [String: Any]? {
        guard let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>", range: start.lowerBound..<text.endIndex)
        else { return nil }
        let xml = String(text[start.lowerBound..<end.upperBound])
        guard let xmlData = xml.data(using: .utf8) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: xmlData, format: nil)) as? [String: Any]
    }
}
