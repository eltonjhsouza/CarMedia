// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).
// Scene-role knowledge adapted from cafari-lite (MIT © rPlayAI).

import AVFoundation
import Combine
import Foundation
import SwiftUI

/// Phone↔car bridge and the single source of truth about CarPlay state.
///
/// Facts this layer is built on (verified against Apple docs, the CarPlay
/// Developer Guide, WWDC26 "Rev up your CarPlay app", cafari-lite and
/// rPlayFling as of iOS 26.4 / 27.x):
///
///  * Video on the head unit needs the entitlement com.apple.developer.carplay-video,
///    granted by Apple per developer account on request
///    (https://developer.apple.com/contact/carplay/). A free Apple ID cannot
///    hold it. In practice the audio entitlement
///    (com.apple.developer.carplay-audio) must be present alongside it, or
///    the app never appears in the car.
///  * With those entitlements iOS creates a *window scene* whose role raw
///    value is "UIWindowSceneSessionRoleCarPlay" — not exposed in Swift, so
///    it is referenced by raw string, exactly like the Info.plist manifest.
///    Anything UIKit can draw appears on the car screen, video included.
///  * Without them iOS never creates the scene: the app stays a normal phone
///    app and nothing fails. That keeps this whole layer inert-but-honest
///    for unsigned clones.
///  * There is NO public API that reports the system "video unavailable
///    while driving" state for window scenes; the head unit applies its own
///    restrictions. For template-based media sessions the system plays the
///    video as audio-only when it reports video unavailable, and
///    CPSessionConfiguration.supportsVideoPlayback (iOS 26.4) declares that
///    the session wants video at all. We approximate the parked state with
///    CarGate (location speed) and say so plainly in the UI.
@MainActor
public final class CarPlayLink: ObservableObject {
    public static let shared = CarPlayLink()

    /// The undocumented-in-Swift but public-in-Info.plist window role.
    public static let windowRole = UISceneSession.Role(rawValue: "UIWindowSceneSessionRoleCarPlay")

    @Published public private(set) var isConnected = false
    @Published public private(set) var lastHandoff: String?
    /// Set by CarPlaySceneDelegate when the car window is live.
    weak var carScreen: CarPlayScreenViewController?

    private init() {}

    func sceneConnected(_ screen: CarPlayScreenViewController) {
        carScreen = screen
        isConnected = true
        EventLog.shared.record(.carplay, "car scene connected")
    }

    func sceneDisconnected() {
        carScreen = nil
        isConnected = false
        EventLog.shared.record(.carplay, "car scene disconnected")
    }

    // MARK: - Handoffs requested from the phone

    /// Send the phone player's current URL to a *separate* AVPlayer on the
    /// car screen. AVPlayer instances are per-window by design; sharing one
    /// between scenes moves the video away from whichever screen it left.
    public func sendCurrentVideoToCar(player: AVPlayer, title: String) {
        guard let screen = carScreen else {
            lastHandoff = "CarPlay não conectado — nada foi enviado."
            return
        }
        guard let item = player.currentItem,
              let asset = item.asset as? AVURLAsset else {
            lastHandoff = "Faixa atual não expõe uma URL jogável no carro."
            return
        }
        screen.playInCar(url: asset.url, title: title)
        lastHandoff = "Enviado para o CarPlay: \(LogScrubber.scrubURL(asset.url.absoluteString))"
        EventLog.shared.record(.carplay, "video handoff \(LogScrubber.scrubURL(asset.url.absoluteString))")
    }

    public func sendPageToCar(_ url: URL) {
        guard let screen = carScreen else {
            lastHandoff = "CarPlay não conectado — nada foi enviado."
            return
        }
        screen.browse(url)
        lastHandoff = "Página enviada: \(LogScrubber.scrubURL(url.absoluteString))"
        EventLog.shared.record(.carplay, "page handoff \(LogScrubber.scrubURL(url.absoluteString))")
    }
}
