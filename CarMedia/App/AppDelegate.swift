// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        EventLog.shared.record(.app, "CarMedia launched (ios \(UIDevice.current.systemVersion))")
        if FeatureFlags.parkedGate.isOn { CarGate.shared.start() }
        return true
    }

    // Code-side fallback for scene selection; the Info.plist manifest is the
    // primary source. Unknown roles must NOT crash the phone experience.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == CarPlayLink.windowRole {
            return UISceneConfiguration(name: "CarPlay", sessionRole: CarPlayLink.windowRole)
        }
        return UISceneConfiguration(name: "Phone", sessionRole: connectingSceneSession.role)
    }
}
