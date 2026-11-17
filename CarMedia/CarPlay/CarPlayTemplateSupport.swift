// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).
//
// REFERENCE-ONLY. This file compiles but is NOT registered in the scene
// manifest: a CarPlay app picks ONE scene style. CarMedia uses the window
// scene (CarPlaySceneDelegate) because it can host a web view; the template
// path below is the official media-app path and the only place where the
// system's own "video unavailable" reporting is handled automatically.
// Keeping both in the manifest at once is the classic way to get a CarPlay
// app that never appears, so it is documented instead of silently combined.
//
// To try the template path: remove the "UIWindowSceneSessionRoleCarPlay"
// configuration from Info.plist, register this delegate for the CarPlay
// template role, and sign with carplay-audio + carplay-video.

import AVFoundation
import CarPlay
import Foundation

// Compiled only when the CARMEDIA_TEMPLATE_SCENE preprocessor flag is set
// (project.yml / xcodebuild OTHER_SWIFT_FLAGS). That is the moment the
// Info.plist should swap the CarPlay window-scene configuration for
// CPTemplateApplicationScene — you do not ship both at once.
#if CARMEDIA_TEMPLATE_SCENE
final class CarPlayTemplateSupport: NSObject, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        EventLog.shared.record(.carplay, "template scene connected")

        // "Utilizar CPSessionConfiguration.supportsVideoPlayback quando
        // aplicável" — applicable here, iOS 26.4+:
        if #available(iOS 26.4, *) {
            let config = CPSessionConfiguration(delegate: nil)
            // Requires com.apple.developer.carplay-video in the profile;
            // without it this returns false / has no effect and video
            // templates are hidden by the system.
            config.supportsVideoPlayback = FeatureFlags.carPlayVideo.isOn
            templateApplicationScene.sessionConfiguration = config
            EventLog.shared.record(.carplay, "sessionConfiguration.supportsVideoPlayback set to \(FeatureFlags.carPlayVideo.isOn)")
        } else {
            EventLog.shared.record(.carplay, "supportsVideoPlayback needs iOS 26.4+; running \(UIDevice.current.systemVersion)")
        }

        let items = [
            CPListItem(text: "MP4 de teste", detailText: "Big Buck Bunny"),
            CPListItem(text: "HLS de teste", detailText: "Apple BipBop"),
        ]
        let list = CPListTemplate(title: "CarMedia", sections: [CPListSection(items: items)])
        list.delegate = self
        interfaceController.setRootTemplate(list, animated: false, completion: nil)
    }

    func templateApplicationSceneDidCollapse(_ templateApplicationScene: CPTemplateApplicationScene) {
        EventLog.shared.record(.carplay, "template scene collapsed")
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        EventLog.shared.record(.carplay, "template scene disconnected")
    }
}

extension CarPlayTemplateSupport: CPListTemplateDelegate {
    func listTemplate(_ listTemplate: CPListTemplate,
                      didSelect item: CPListItem,
                      completionHandler: @escaping () -> Void) {
        let index = (listTemplate.sections?.first?.items.firstIndex(of: item)) ?? 0
        let urlString = index == 0 ? PlayerModel.testMP4 : PlayerModel.testHLS
        // Handoff to the phone-side player; when entitled, the car's own
        // video pipeline (now-playing / video control templates) is chosen
        // by the SYSTEM, audio-only when the car reports video unavailable —
        // never forced by us.
        Task { @MainActor in
            PlayerUICoordinator.shared.controller?.player = AVPlayer(url: URL(string: urlString)!)
        }
        completionHandler()
    }
}
#endif
