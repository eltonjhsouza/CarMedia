// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import SwiftUI

/// Root tab screen. Tabs that are not implemented are NOT shown as dead
/// buttons — Mirroring appears only when its PoC flag is enabled.
struct RootView: View {
    @StateObject private var link = CarPlayLink.shared

    var body: some View {
        TabView {
            BrowserView()
                .tabItem { Label("Navegador", systemImage: "safari") }

            PlayerView()
                .tabItem { Label("Player", systemImage: "play.rectangle") }

            CarPlayStatusView()
                .tabItem { Label("CarPlay", systemImage: "car.fill") }

            if FeatureFlags.mirroring.isOn {
                MirroringView()
                    .tabItem { Label("Espelhamento", systemImage: "rectangle.on.rectangle") }
            }

            DiagnosticsView()
                .tabItem { Label("Diagnósticos", systemImage: "stethoscope") }
        }
        .overlay(alignment: .top) {
            if link.isConnected {
                Text("CarPlay conectado")
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 2)
            }
        }
    }
}
