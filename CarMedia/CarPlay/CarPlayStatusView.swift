// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import SwiftUI

/// Honest CarPlay status panel. Three states, never blended:
/// IMPLEMENTADO (code exists) / AUTORIZADO (Apple granted entitlements,
/// detectable only indirectly) / VALIDADO EM HARDWARE (only the user can
/// confirm, with the Fiat Pulse connected).
struct CarPlayStatusView: View {
    @StateObject private var link = CarPlayLink.shared
    @Environment(\.modelContext) private var context
    @State private var entitlements: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Estado") {
                    Label { Text("Conectado à central") } icon: {
                        Image(systemName: link.isConnected ? "checkmark.circle.fill" : "circle")
                    }
                    .foregroundStyle(link.isConnected ? .green : .secondary)

                    statusLine("Camada CarPlay no código", .yes)
                    statusLine("Entitlements na assinatura", entitlementsHaveCarPlay ? .yes : .no)
                    statusLine("Vídeo habilitado por entitlement", carplayVideoEntitled ? .yes : .unknown)
                    Text("Validação em hardware: somente um teste com o Pulse conectado confirma. Este app não afirma que CarPlay funciona sem esse teste.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Ações") {
                    Button("Enviar página atual do navegador para o carro") {
                        if let url = BrowserModel.shared.currentURL { link.sendPageToCar(url) }
                        else { link.lastHandoff = "Abra uma página no Navegador primeiro." }
                    }
                    Button("Enviar vídeo atual do Player para o carro") {
                        link.lastHandoff = "Use o botão Enviar no Player (o vídeo precisa estar carregado lá)."
                    }
                    if let h = link.lastHandoff {
                        Text(h).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Flags experimentais") {
                    ForEach([FeatureFlags.carPlayScene, FeatureFlags.parkedGate, FeatureFlags.carPlayVideo], id: \.name) { flag in
                        Toggle(flag.title, isOn: Binding(
                            get: { flag.isOn }, set: { flag.set($0) }))
                    }
                    Text("carplayVideo só tem efeito com o entitlement com.apple.developer.carplay-video concedido pela Apple ao seu time (pedido em developer.apple.com/contact/carplay). Sem ele o iOS nunca cria a cena do carro — o app continua normal no iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Como isto funciona (APIs públicas)") {
                    Text("""
                    • Cena do carro: UIWindowScene com role "UIWindowSceneSessionRoleCarPlay" (mesma string do Info.plist), caminho verificado pelo Cafari Lite (MIT).
                    • Sessões de template usam CPSessionConfiguration.supportsVideoPlayback (iOS 26.4) — referência em CarPlayTemplateSupport.swift, não registrada no manifest para não misturar os caminhos.
                    • Quando o carro informa que vídeo está indisponível, o sistema recai para só áudio; nossa aproximação é o portão por velocidade (CoreLocation), pois não há API pública "estacionado?" para window scenes.
                    • Nada aqui usa APIs privadas.
                    """)
                    .font(.footnote)
                }
            }
            .navigationTitle("CarPlay")
            .task { entitlements = await EntitlementProbe.current() }
            .environment(\.modelContext, Persistence.container.mainContext)
        }
    }

    private var entitlementsHaveCarPlay: Bool {
        entitlements.keys.contains { $0.hasPrefix("com.apple.developer.carplay") }
    }
    private var carplayVideoEntitled: Bool {
        entitlements["com.apple.developer.carplay-video"] == true
    }

    private func statusLine(_ text: String, _ s: Status) -> some View {
        HStack {
            Text(text)
            Spacer()
            switch s {
            case .yes: Label("sim", systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.caption)
            case .no: Label("não", systemImage: "xmark.seal").foregroundStyle(.red).font(.caption)
            case .unknown: Label("indeterminado", systemImage: "questionmark.seal").foregroundStyle(.orange).font(.caption)
            }
        }
    }
    private enum Status { case yes, no, unknown }
}
