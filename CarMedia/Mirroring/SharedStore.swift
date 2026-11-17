// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation

/// App Group bridge between the app and the Broadcast Upload Extension.
/// The extension cannot show UI or read SwiftData; it reads capture targets
/// and leaves a small status + heartbeat here.
public enum SharedStore {
    public static let suiteName = "group.dev.carmedia.app"
    public static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    public enum Key {
        static let receiverHost = "mirror.receiverHost"
        static let receiverPort = "mirror.receiverPort"
        static let status = "mirror.status"          // idle | streaming | error
        static let statusDetail = "mirror.statusDetail"
        static let heartbeat = "mirror.heartbeat"    // unix timestamp
        static let frames = "mirror.frames"
        static let privacyBanner = "mirror.privacyBannerShown"
    }

    public static func setReceiver(host: String, port: Int) {
        defaults.set(host, forKey: Key.receiverHost)
        defaults.set(port, forKey: Key.receiverPort)
        EventLog.shared.record(.mirror, "receiver set host=\(host.isEmpty ? "<none>" : "<configured>") port=\(port)")
    }

    public static var receiverHost: String { defaults.string(forKey: Key.receiverHost) ?? "" }
    public static var receiverPort: Int {
        let p = defaults.integer(forKey: Key.receiverPort)
        return p == 0 ? 5555 : p
    }

    public static var status: String { defaults.string(forKey: Key.status) ?? "idle" }
    public static var frames: Int { defaults.integer(forKey: Key.frames) }
    public static var heartbeat: TimeInterval { defaults.double(forKey: Key.heartbeat) }
}
