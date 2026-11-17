// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import SwiftUI
import UIKit

final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: RootView().modelContainer(Persistence.container))
        window.makeKeyAndVisible()
        self.window = window
        EventLog.shared.record(.app, "phone scene connected")
    }
}
