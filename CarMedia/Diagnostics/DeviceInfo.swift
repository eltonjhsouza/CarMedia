// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation

public enum DeviceInfo {
    /// "iPhone16,2" style identifier via uname(3) machine field.
    public static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0) ?? "unknown"
            }
        }
    }

    public static var systemVersion: String {
        "\(UIDeviceHelper.name) \(UIDevice.current.systemVersion)"
    }

    public static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v)+\(b)"
    }

    public static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "?"
    }
}

enum UIDeviceHelper {
    static var name: String { UIDevice.current.model }
}
