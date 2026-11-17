// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).
// Compile-time-unknown, runtime-tunable feature flags.
//
// Experimental surfaces (CarPlay video on the head unit, screen mirroring)
// default to OFF and must be validated on real hardware before being turned
// on by default. A clone with a free Apple ID builds and runs phone-only:
// iOS simply never creates the car scene without the granted entitlements.
//
// Overrides, in priority order:
//   1. Environment variables CARMEDIA_FLAG_* (schemes, CI)
//   2. UserDefaults "flags.<name>" (Diagnostics screen on the device)
//   3. Built-in default below

import Foundation

enum FeatureFlags {
    static let carPlayScene = Flag(name: "carplayScene", env: "CARMEDIA_FLAG_CARPLAY_SCENE", defaultValue: true)
    static let parkedGate   = Flag(name: "parkedGate",   env: "CARMEDIA_FLAG_PARKED_GATE",   defaultValue: true)
    static let carPlayVideo = Flag(name: "carplayVideo", env: "CARMEDIA_FLAG_CARPLAY_VIDEO", defaultValue: false)
    static let mirroring    = Flag(name: "mirroring",    env: "CARMEDIA_FLAG_MIRRORING",     defaultValue: false)

    static var all: [Flag] { [carPlayScene, parkedGate, carPlayVideo, mirroring] }

    struct Flag: Identifiable {
        let name: String
        let env: String
        let defaultValue: Bool
        var id: String { name }
        var title: String {
            switch name {
            case "carplayScene": return "Cena CarPlay (window scene)"
            case "parkedGate":   return "Portão de estacionamento (velocidade GPS)"
            case "carplayVideo": return "Vídeo na tela do carro (requer entitlement)"
            case "mirroring":    return "Espelhamento PoC (ReplayKit → receptor TCP)"
            default: return name
            }
        }

        var isOn: Bool {
            if let v = ProcessInfo.processInfo.environment[env] { return v == "1" }
            let key = "flags.\(name)"
            if UserDefaults.standard.object(forKey: key) != nil {
                return UserDefaults.standard.bool(forKey: key)
            }
            return defaultValue
        }

        func set(_ value: Bool) {
            UserDefaults.standard.set(value, forKey: "flags.\(name)")
            EventLog.shared.record(.flag, "flag \(name) = \(value)")
        }
    }
}
