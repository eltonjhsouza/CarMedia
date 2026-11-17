// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import AVFoundation
import Combine
import Foundation

/// Native player kept separate from the browser (stage 2).
///
/// Video output paths used here are all official:
///  - AirPlay video routes selected through AVRoutePickerView
///  - CarPlay screen output via the CarPlay scene's own window (CarPlay/)
///  - AVPlayer.externalPlaybackActivityStyle / allowsExternalPlayback
/// No DRM is touched: FairPlay-protected streams fail at the media-services
/// layer and are reported as such — that is expected and not worked around.
@MainActor
public final class PlayerModel: NSObject, ObservableObject {
    @Published public private(set) var player: AVPlayer
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var status: AVPlayerItem.Status = .unknown
    @Published public private(set) var routeSummary: String = "Saída: alto-falante do iPhone"
    @Published public private(set) var supportsExternalPlayback = false
    @Published public var volume: Float = 1.0 { didSet { player.volume = volume } }
    @Published public private(set) var lastError: String?
    @Published public var title: String = ""

    private let routePublisher: NSObjectProtocol
    private var timeToken: Any?

    // Test sources (public, unencrypted).
    public static let testMP4 = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    public static let testHLS = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"

    override public init() {
        player = AVPlayer()
        player.allowsExternalPlayback = true   // official property on AVPlayer
        routePublisher = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleRouteChange(note) }
        }
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        updateRouteSummary()
    }

    deinit {
        NotificationCenter.default.removeObserver(routePublisher)
    }

    // MARK: - Controls

    public func load(urlString: String, as title: String) {
        guard let url = URL(string: urlString) else {
            lastError = "URL inválida"; EventLog.shared.record(.player, "invalid url"); return
        }
        load(url: url, as: title)
    }

    public func load(url: URL, as title: String) {
        EventLog.shared.record(.player, "load \(LogScrubber.scrubURL(url.absoluteString)) kind=\(url.pathExtension.isEmpty ? "stream" : url.pathExtension)")
        // Tear down previous observations before swapping items.
        if let old = player.currentItem {
            old.removeObserver(self, forKeyPath: "status")
            old.removeObserver(self, forKeyPath: "presentationSize")
        }
        if let timeToken { player.removeTimeObserver(timeToken); self.timeToken = nil }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        self.title = title
        lastError = nil
        status = .unknown

        item.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        item.addObserver(self, forKeyPath: "presentationSize", options: [.new], context: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemFailed(_:)),
            name: Notification.Name("AVPlayerItemFailedToLoadResourceNotification"), object: item)
        NotificationCenter.default.addObserver(
            self, selector: #selector(playbackEnded(_:)),
            name: AVPlayerItem.didPlayToEndTimeNotification, object: item)

        timeToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            Task { @MainActor in
                self?.currentTime = t.seconds
                self?.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
            }
        }
        play()
    }

    public func play() {
        player.play()
        isPlaying = true
        EventLog.shared.record(.player, "play")
    }

    public func pause() {
        player.pause()
        isPlaying = false
        EventLog.shared.record(.player, "pause")
    }

    public func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        EventLog.shared.record(.player, "seek \(Int(seconds))s")
    }

    // MARK: - KVO & notifications

    override nonisolated public func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?
    ) {
        Task { @MainActor in
            if keyPath == "status", let item = self.player.currentItem {
                self.status = item.status
                if item.status == .failed {
                    let desc = item.error?.localizedDescription ?? "?"
                    self.lastError = desc
                    self.EventLog_record("item failed: \(desc)")
                } else if item.status == .readyToPlay {
                    self.EventLog_record("ready to play, externalRoute=\(self.hasRemoteVideoRoute)")
                }
            }
            if keyPath == "presentationSize" {
                self.EventLog_record("presentationSize \(self.player.currentItem?.presentationSize ?? .zero)")
            }
        }
    }

    private nonisolated func EventLog_record(_ s: String) {
        EventLog.shared.record(.player, s)
    }

    @objc private func itemFailed(_ note: Notification) {
        let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        lastError = err?.localizedDescription
        EventLog.shared.record(.player, "playback failed: \(err?.localizedDescription ?? "?")")
    }

    @objc private func playbackEnded(_ note: Notification) {
        isPlaying = false
        EventLog.shared.record(.player, "ended")
    }

    // MARK: - Routes (AirPlay / CarPlay audio-video)

    private func handleRouteChange(_ note: Notification) {
        updateRouteSummary()
        guard let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }
        EventLog.shared.record(.player, "route change reason=\(reason.label)")
        switch reason {
        case .oldDeviceUnavailable, .noSuitableRouteForCategory:
            // Output went away mid-playback: pause video, keep UI coherent.
            if FeatureFlags.parkedGate.isOn, CarGate.shared.isMoving {
                pause()
                EventLog.shared.record(.player, "paused: device disconnected while moving")
            }
        default:
            break
        }
    }

    private func updateRouteSummary() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let names = outputs.map { "\($0.portName) (\($0.carMediaPortLabel))" }
        routeSummary = names.isEmpty ? "Saída: alto-falante do iPhone" : "Saída: " + names.joined(separator: " + ")
        supportsExternalPlayback = hasRemoteVideoRoute
    }

    /// Public, honest signal: a remote route (AirPlay / car) is active.
    /// (AVPlayerItem.isExternalPlaybackActive does not exist; the route list does.)
    public var hasRemoteVideoRoute: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == AVAudioSession.Port.airPlay
                || $0.portType.rawValue.hasPrefix("Car")
        }
    }

    public var externalPlaybackActive: Bool { hasRemoteVideoRoute }
}

extension AVAudioSession.RouteChangeReason {
    var label: String {
        switch self {
        case .unknown: return "unknown"
        case .newDeviceAvailable: return "newDeviceAvailable"
        case .oldDeviceUnavailable: return "oldDeviceUnavailable"
        case .categoryChange: return "categoryChange"
        case .override: return "override"
        case .wakeFromSleep: return "wakeFromSleep"
        case .noSuitableRouteForCategory: return "noSuitableRoute"
        case .routeConfigurationChange: return "routeConfigurationChange"
        @unknown default: return "other(\(rawValue))"
        }
    }
}

extension AVAudioSession.Port {
    /// Human-friendly port type label. Port is a string-backed struct; car
    /// types match by rawValue so no version-gated enum member is needed.
    var carMediaPortLabel: String {
        if rawValue.hasPrefix("Car") { return "car" }
        switch self {
        case .builtInSpeaker: return "speaker"
        case .bluetoothA2DP: return "bt-a2dp"
        case .bluetoothLE: return "bt-le"
        case .bluetoothHFP: return "bt-hfp"
        case .airPlay: return "airplay"
        case .headphones: return "headphones"
        case .builtInReceiver: return "receiver"
        default: return rawValue
        }
    }
}
