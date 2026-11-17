// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import AVFoundation
import SwiftUI
import UIKit

struct DiagnosticsView: View {
    @State private var entitlements: [String: Bool] = [:]
    @State private var entitlementSource: EntitlementProbe.Result.Source = .notFound
    @State private var log: [EventLog.Entry] = []
    @State private var route: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    deviceGroup
                    carplayGroup
                    routeGroup
                    signatureGroup
                    flagsGroup
                    legendGroup
                    logGroup
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

    // MARK: - Sections (small to keep the type-checker sane)

    private var deviceGroup: some View {
        group("Aparelho") {
            VStack(spacing: 4) {
                row("iOS", DeviceInfo.systemVersion)
                row("Modelo", DeviceInfo.machineIdentifier)
                row("App", DeviceInfo.appVersion)
                row("Bundle", DeviceInfo.bundleID)
            }
        }
    }

    private var carplayGroup: some View {
        group("CarPlay") {
            VStack(spacing: 4) {
                row("Cena do carro", CarPlayLink.shared.isConnected ? "conectada" : "não conectada")
                row("Entitlement CarPlay", entitlementsSummary)
                row("Flag vídeo", flag(FeatureFlags.carPlayVideo))
                let gate = flag(FeatureFlags.parkedGate)
                row("Portão parked", gate + (FeatureFlags.parkedGate.isOn ? " · \(CarGate.shared.isMoving ? "movendo" : "parado")" : ""))
            }
        }
    }

    private var routeGroup: some View {
        group("Rota de saída (AirPlay/CarPlay/áudio)") {
            VStack(spacing: 4) {
                row("Rotas", route)
                row("Rota remota (AirPlay/carro)", hasRemoteRouteNow ? "ativa" : "inativa")
            }
        }
    }

    private var signatureGroup: some View {
        group("Assinatura (verificável)") {
            VStack(spacing: 4) {
                ForEach(entitlements.keys.sorted(), id: \.self) { key in
                    row(key, entitlements[key] == true ? "presente no perfil" : "?")
                }
                if entitlements.isEmpty {
                    row("—", sourceText)
                }
            }
        }
    }

    private var flagsGroup: some View {
        group("Flags experimentais") {
            VStack(spacing: 4) {
                ForEach(FeatureFlags.all) { f in
                    Toggle(f.title, isOn: Binding(
                        get: { f.isOn },
                        set: { f.set($0) }))
                }
                Text("Flags desligam/ligam superfícies não validadas. Espelhamento só aparece na barra após ligar aqui e reiniciar o app.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var legendGroup: some View {
        group("Legenda honesta") {
            Text("✔ implementado = o código existe e roda. ⚿ autorizado = a Apple concedeu o entitlement ao time. ⚠ validado em hardware = testado com o Pulse conectado. Estas telas mostram o estado de cada um separadamente; o app NUNCA confunde os três.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var logGroup: some View {
        group("Logs (\(log.count))") {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(log.reversed().prefix(200)) { e in
                    HStack(alignment: .top) {
                        Text(e.date, style: .time).font(.caption2.monospaced)
                        Text("[\(e.category.rawValue)]").font(.caption2).foregroundStyle(.secondary)
                        Text(LogScrubber.scrub(e.message)).font(.caption2)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

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
            .map { "\($0.portName) [\($0.portType.carMediaPortLabel)]" }.joined(separator: ", ")
        if route.isEmpty { route = "alto-falante do iPhone" }
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

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
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
