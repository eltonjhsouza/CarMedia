// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import AVFoundation
import SwiftUI
import UIKit

struct DiagnosticsView: View {
    @State private var entitlements: [String: Bool] = [:]
    @State private var entitlementSource: EntitlementProbe.Result.Source = .notFound
    @State private var log: [EventLog.Entry] = []
    @State private var route: String = ""

    private let columns = [GridItem(.adaptive(minimum: 150), alignment: .leading)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    group("Aparelho") {
                        row("iOS", DeviceInfo.systemVersion)
                        row("Modelo", DeviceInfo.machineIdentifier)
                        row("App", DeviceInfo.appVersion)
                        row("Bundle", DeviceInfo.bundleID)
                    }
                    group("CarPlay") {
                        row("Cena do carro", CarPlayLink.shared.isConnected ? "conectada" : "não conectada")
                        row("Entitlement CarPlay", entitlementsSummary)
                        row("Flag vídeo", flag(FeatureFlags.carPlayVideo))
                        row("Portão parked", flag(FeatureFlags.parkedGate) + (FeatureFlags.parkedGate.isOn ? " · \(CarGate.shared.isMoving ? "movendo" : "parado")" : ""))
                    }
                    group("Rota de saída (AirPlay/áudio)") {
                        row("Rotas", route)
                        row("Rota remota (AirPlay/carro)", hasRemoteRouteNow ? "ativa" : "inativa")
                    }
                    group("Assinatura (verificável)") {
                        ForEach(entitlements.keys.sorted(), id: \.self) { key in
                            row(key, entitlements[key] == true ? "presente no perfil" : "?")
                        }
                        if entitlements.isEmpty {
                            row("—", sourceText)
                        }
                    }
                    group("Flags experimentais") {
                        ForEach(FeatureFlags.all) { flag in
                            Toggle(flag.title, isOn: Binding(
                                get: { flag.isOn }, set: { flag.set($0) }))
                        }
                        Text("Flags desligam/ligam superfícies não validadas. Espelhamento só aparece na barra após ligar aqui e reiniciar o app.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    group("Legenda honesta") {
                        Text("✔ implementado = o código existe e roda. ⚿ autorizado = a Apple concedeu o entitlement ao time. ⚠ validado em hardware = testado com o Pulse conectado. Estas telas mostram o estado de cada um separadamente; o app NUNCA confunde os três.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    group("Logs (\(log.count))") {
                        ForEach(log.reversed().prefix(200)) { e in
                            HStack(alignment: .top) {
                                Text(e.date, style: .time).font(.caption2.monospaced)
                                Text("[\(e.category.rawValue)]").font(.caption2).foregroundStyle(.secondary)
                                Text(LogScrubber.scrub(e.message)).font(.caption2)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Diagnósticos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: LogScrubber.scrub(EventLog.shared.scrubbedExport()),
                              preview: SharePreview("CarMedia logs")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .onAppear { refresh() }
        }
    }

    private var hasRemoteRouteNow: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == AVAudioSession.Port.airPlay || $0.portType.rawValue.hasPrefix("Car")
        }
    }

    private func refresh() {
        let probe = EntitlementProbe.full()
        entitlements = probe.entitlements
        entitlementSource = probe.source
        log = EventLog.shared.snapshot
        route = AVAudioSession.sharedInstance().currentRoute.outputs
            .map { "\($0.portName) [\($0.portType)]" }.joined(separator: ", ")
        if route.isEmpty { route = "recetor iPhone" }
    }

    private var entitlementsSummary: String {
        if entitlements["com.apple.developer.carplay-video"] == true { return "vídeo presente" }
        if entitlements.keys.contains(where: { $0.hasPrefix("com.apple.developer.carplay") }) { return "parcial" }
        return sourceText
    }

    private var sourceText: String {
        switch entitlementSource {
        case .simulatorBuild: return "build de simulador não carrega entitlements"
        case .appStoreSigned: return "re-assinado pela App Store: impossível verificar"
        case .unsigned: return "build não assinado"
        case .notFound: return "sem perfil no bundle"
        case .mobileProvision: return "lido do perfil"
        }
    }

    private func flag(_ f: FeatureFlags.Flag) -> String { "\(f.name): \(f.isOn ? "ON" : "OFF")" }

    private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}
