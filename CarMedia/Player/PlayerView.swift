// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import AVKit
import SwiftUI

struct PlayerView: View {
    @StateObject private var model = PlayerModel()
    @StateObject private var carLink = CarPlayLink.shared
    @State private var urlString = PlayerModel.testMP4

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                VideoContainer(model: model)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                statusRow

                HStack {
                    Image(systemName: "wave.3.right")
                    Text(model.routeSummary)
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    RoutePickerButton()
                }
                .padding(.horizontal)

                controls
                sourceField
                if let err = model.lastError {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.red)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("Player")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.toggleFullScreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                }
            }
            .environment(\.modelContext, Persistence.container.mainContext)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Text(model.title).font(.headline).lineLimit(1)
            Spacer()
            Text(statusLabel).font(.caption).foregroundStyle(.secondary)
            if model.externalPlaybackActive {
                Label("Saída externa", systemImage: "arrow.up.forward.app")
                    .font(.caption).foregroundStyle(.tint)
            }
        }
        .padding(.horizontal)
    }

    private var statusLabel: String {
        switch model.status {
        case .unknown: return "…"; case .loading: return "carregando"
        case .readyToPlay: return "pronto"; case .failed: return "erro"
        @unknown default: return "?"
        }
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 24) {
                Button { model.seek(to: max(0, model.currentTime - 15)) } label: { Image(systemName: "backward.fill") }
                Button { model.isPlaying ? model.pause() : model.play() } label: {
                    Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                }
                Button { model.seek(to: min(model.duration, model.currentTime + 15)) } label: { Image(systemName: "forward.fill") }
            }
            Slider(value: Binding(
                get: { model.duration > 0 ? model.currentTime / model.duration : 0 },
                set: { model.seek(to: $0 * model.duration) }),
                in: 0...1)
                .padding(.horizontal)
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $model.volume, in: 0...1)
                Text(timeString(model.currentTime) + " / " + timeString(model.duration))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private var sourceField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("MP4 ou HLS (m3u8)", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { loadCurrent() }
                Button("Abrir") { loadCurrent() }
            }
            HStack {
                Button("MP4 de teste") { load(PlayerModel.testMP4, "Big Buck Bunny (MP4)") }
                Button("HLS de teste") { load(PlayerModel.testHLS, "Apple BipBop (HLS)") }
                Spacer()
                if carLink.isConnected {
                    Button {
                        carLink.sendCurrentVideoToCar(player: model.player, title: model.title)
                    } label: { Label("Enviar para o CarPlay", systemImage: "car.fill") }
                        .buttonStyle(.borderedProminent)
                }
            }
            .font(.footnote)
        }
        .padding(.horizontal)
    }

    private func loadCurrent() { load(urlString, (URL(string: urlString)?.lastPathComponent) ?? "Fonte") }
    private func load(_ url: String, _ name: String) { model.load(urlString: url, as: name) }

    private func timeString(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "--:--" }
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Video surface (AVPlayerViewController = official fullscreen & AirPlay)

struct VideoContainer: UIViewControllerRepresentable {
    @ObservedObject var model: PlayerModel
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = model.player
        vc.updatesNowPlayingInfoCenter = false
        if #available(iOS 18.0, *) { vc.entersFullScreenWhenPlaybackBegins = false }
        PlayerUICoordinator.shared.controller = vc
        return vc
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = model.player
    }
}

/// Bridges the SwiftUI fullscreen button to the AVPlayerViewController.
final class PlayerUICoordinator {
    static let shared = PlayerUICoordinator()
    weak var controller: AVPlayerViewController?
}

extension PlayerModel {
    /// Fullscreen via a modal AVPlayerViewController sharing the same player.
    /// Uses only long-stable APIs (modal .fullScreen presentation), so it
    /// works regardless of AVKit's newer programmatic-fullscreen additions.
    func toggleFullScreen() {
        guard let host = PlayerUICoordinator.shared.controller?.view.window?.rootViewController?.topMost else { return }
        let full = AVPlayerViewController()
        full.player = player
        full.allowsExternalPlayback = true
        full.modalPresentationStyle = .fullScreen
        host.present(full, animated: true)
        EventLog.shared.record(.player, "fullscreen presented")
    }
}

extension UIViewController {
    var topMost: UIViewController {
        if let presented { return presented.topMost }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController { return visible.topMost }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController { return selected.topMost }
        return self
    }
}

// MARK: - AVRoutePickerView (video-preferring destinations first)

struct RoutePickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.prioritizesVideoDevices = true   // iOS 13+: destinos com vídeo primeiro
        v.delegate = context.coordinator
        return v
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, AVRoutePickerViewDelegate {
        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            EventLog.shared.record(.player, "route picker closed")
        }
    }
}
