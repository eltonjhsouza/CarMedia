// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).
// Window-scene approach follows cafari-lite (MIT © rPlayAI): the car screen
// is a plain UIWindowScene under role "UIWindowSceneSessionRoleCarPlay", so
// anything UIKit draws — WKWebView and AVPlayer included — shows on the head
// unit and takes touches from it. iOS only ever creates this scene for a
// build signed with the granted CarPlay entitlements.

import UIKit

final class CarPlaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        EventLog.shared.record(.carplay, "car scene willConnect role=\(session.role.rawValue)")
        guard FeatureFlags.carPlayScene.isOn, let windowScene = scene as? UIWindowScene else {
            EventLog.shared.record(.carplay, "car scene ignored (flag off or not a window scene)")
            return
        }
        let window = UIWindow(windowScene: windowScene)
        let screen = CarPlayScreenViewController(windowScene: windowScene)
        window.rootViewController = screen
        window.makeKeyAndVisible()
        self.window = window
        CarPlayLink.shared.sceneConnected(screen)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        CarPlayLink.shared.sceneDisconnected()
    }
}
