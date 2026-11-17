// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import ReplayKit
import SwiftUI

/// Stage 4 PoC: capture consent + system picker + live status + stop path.
/// The broadcast extension streams H.264 frames to a LAN test receiver over
/// TCP — capture and transport are validated FIRST, deliberately, because
/// there is NO public API to push ReplayKit samples to a CarPlay screen or
/// to an arbitrary AirPlay video receiver. See docs/MIRRORING.md.
/// Behind FeatureFlags.mirroring (default OFF).
struct MirroringView: View {
    @StateObject private var vm = MirroringModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Receptor de testes (LAN)") {
                    TextField("IP do receptor", text: $vm.host)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                    TextField("Porta TCP", value: $vm.port, format: .number)
                        .keyboardType(.numberPad)
                    Button("Salvar destino") { vm.saveReceiver() }
                    Text("Use tools/receiver/ (FFplay/FFmpeg) no mesmo Wi-Fi. Sem destino válido a captura recusa iniciar.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Iniciar") {
                    VStack {
                        BroadcastPickerRepresentable()
                            .frame(height: 80)
                    }
                    Text("O seletor acima é o sistema (RPSystemBroadcastPickerView): o usuário escolhe 'CarMedia Broadcast' e o iOS exibe o aviso de gravação. Nada começa sem esse gesto.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Estado") {
                    LabeledContent("Captura", value: vm.status)
                    LabeledContent("Quadros", value: "\(vm.frames)")
                    LabeledContent("Último sinal", value: vm.heartbeatText)
                    if vm.isLikelyStreaming {
                        Button("Parar (via sistema)", role: .destructive) { vm.stopHint() }
                        Text("O encerramento é sempre pelo Centro de Controle do sistema — extensões de broadcast não têm botão de stop próprio.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("O que este PoC valida — e o que não existe") {
                    Text("""
                    ✔ Captura da tela via ReplayKit com consentimento do sistema.
                    ✔ Transporte dos frames para um receptor de testes na LAN.
                    ✗ Entrega de tela de app em THIRD-PARTY AirPlay receivers: sem API pública.
                    ✗ Espelhar a tela do app na tela do CarPlay: só a central decide se mostra
                      Screen Mirroring; apps não têm API para isso. O caminho oficial para vídeo
                      no carro é a cena CarPlay (aba CarPlay), não ReplayKit.
                    Nada é gravado em disco; o stream existe só durante a sessão.
                    """)
                    .font(.footnote)
                }
            }
            .navigationTitle("Espelhamento")
            .onAppear { vm.refreshLoop() }
        }
    }
}

@MainActor
final class MirroringModel: ObservableObject {
    @Published var host = SharedStore.receiverHost
    @Published var port = SharedStore.receiverPort
    @Published var status = SharedStore.status
    @Published var frames = SharedStore.frames
    @Published var heartbeatText = "—"

    var isLikelyStreaming: Bool {
        status == "streaming" && Date().timeIntervalSince1970 - SharedStore.heartbeat < 5
    }

    func saveReceiver() {
        SharedStore.setReceiver(host: host, port: port)
    }

    func stopHint() {
        EventLog.shared.record(.mirror, "user asked to stop; system control center required")
    }

    func refreshLoop() {
        Task { @MainActor in
            for _ in 0..<600 {
                status = SharedStore.status
                frames = SharedStore.frames
                let hb = SharedStore.heartbeat
                heartbeatText = hb > 0 ? RelativeDateTimeFormatter().localizedString(
                    for: Date(timeIntervalSince1970: hb), relativeTo: .now) : "—"
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

/// The system picker — no custom "fake cast" button anywhere.
struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: .zero)
        v.preferredExtension = "dev.carmedia.app.broadcast"   // bundle id of the extension
        v.showsMicrophoneButton = false                       // screen only, no mic capture
        return v
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
