// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import AVKit
import UIKit
import WebKit

/// The car screen itself: an index page (a web view — the CarPlay screen has
/// no keyboard, so browsing starts from phone-sent pages and a fixed index),
/// a full-page video surface, and the driving behaviour.
final class CarPlayScreenViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private let webView: WKWebView
    private let playerHost = UIViewController()     // hosts AVPlayerViewController
    private var player: AVPlayer?
    private let drivingBanner = CarPlayScreenViewController.makeBanner()
    private let windowScene: UIWindowScene

    init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(nibName: nil, bundle: nil)
        // WKWebView copies the configuration on init — register on the copy.
        webView.configuration.userContentController.add(self, name: "car")
        webView.navigationDelegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        webView.frame = view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChild(webView)
        view.addSubview(webView)
        webView.didMove(toParent: self)
        loadIndex()

        // Video surface starts hidden; shown only when something plays.
        playerHost.view.isHidden = true
        playerHost.view.frame = view.bounds
        playerHost.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChild(playerHost)
        view.addSubview(playerHost.view)
        playerHost.didMove(toParent: self)

        drivingBanner.isHidden = true
        drivingBanner.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
        drivingBanner.autoresizingMask = [.flexibleWidth]
        view.addSubview(drivingBanner)

        NotificationCenter.default.addObserver(
            self, selector: #selector(gateChanged), name: CarGate.stateChanged, object: nil)
        applyGate()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "car")
    }

    // MARK: - Public API used by the phone

    func browse(_ url: URL) {
        showWeb()
        webView.load(URLRequest(url: url))
    }

    func playInCar(url: URL, title: String) {
        EventLog.shared.record(.carplay, "car play \(LogScrubber.scrubURL(url.absoluteString))")
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        let vc = AVPlayerViewController()
        vc.player = player
        vc.allowsExternalPlayback = false   // we ARE the external screen here
        playerHost.children.forEach { $0.willMove(toParent: nil); $0.removeFromParent() }
        playerHost.addChild(vc)
        vc.view.frame = playerHost.view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerHost.view.addSubview(vc.view)
        vc.didMove(toParent: playerHost)
        playerHost.view.isHidden = false
        drivingBanner.isHidden = false
        player.play()
        applyGate()
    }

    // MARK: - Driving gate

    @objc private func gateChanged() { applyGate() }

    private func applyGate() {
        guard FeatureFlags.parkedGate.isOn else {
            player?.play()
            playerHost.view.isHidden = false
            drivingBanner.isHidden = true
            return
        }
        if CarGate.shared.isMoving {
            // Video unavailable while driving: picture off, audio continues —
            // the same degradation direction the system documents for CarPlay
            // sessions. Web videos are paused instead (we cannot separate
            // their picture from audio inside a web view).
            playerHost.view.isHidden = true
            drivingBanner.isHidden = false
            player?.play()
            webView.evaluateJavaScript("window.carMediaPauseWebVideo && window.carMediaPauseWebVideo();", completionHandler: nil)
        } else {
            applyVideoVisibility()
            drivingBanner.isHidden = true
        }
    }

    private func applyVideoVisibility() {
        playerHost.view.isHidden = player == nil
    }

    private func showWeb() {
        stopVideo()
    }

    private func stopVideo() {
        player?.pause()
        player = nil
        playerHost.view.isHidden = true
        drivingBanner.isHidden = true
    }

    // MARK: - Index page (local HTML, no network)

    private func loadIndex() {
        webView.loadHTMLString(Self.indexHTML, baseURL: nil)
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "car", let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        switch action {
        case "play":
            if let s = body["url"] as? String, let url = URL(string: s) {
                playInCar(url: url, title: (body["title"] as? String) ?? url.lastPathComponent)
            }
        case "nav":
            if let s = body["url"] as? String, let url = URL(string: s) {
                EventLog.shared.record(.carplay, "car nav \(LogScrubber.scrubURL(s))")
                webView.load(URLRequest(url: url))
            }
        default: break
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Ask pages to expose their own video pause when the gate closes.
        webView.evaluateJavaScript(Self.pauseHelperJS, completionHandler: nil)
    }

    private static func makeBanner() -> UILabel {
        let l = UILabel()
        l.text = "Dirigindo — vídeo indisponível. O áudio continua."
        l.textColor = .white
        l.backgroundColor = UIColor(white: 0, alpha: 0.75)
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        return l
    }

    private static var indexHTML: String {
        var rows = ""
        for l in QuickLinks.all {
            rows += "<a class=btn href=# onclick=\"go('\(l.url)')\">\(l.name)</a>"
        }
        rows += "<hr>"
        rows += "<a class=btn href=# onclick=\"play('\(PlayerModel.testMP4)','Big Buck Bunny')\">▶ MP4 de teste</a>"
        rows += "<a class=btn href=# onclick=\"play('\(PlayerModel.testHLS)','Apple BipBop HLS')\">▶ HLS de teste</a>"
        return """
        <!doctype html><html><head><meta charset=utf-8>
        <meta name=viewport content="width=device-width,initial-scale=1">
        <style>
        body{background:#000;color:#eee;font-family:-apple-system;text-align:center;padding:24px}
        .btn{display:inline-block;margin:12px;padding:16px 22px;border:1px solid #444;border-radius:12px;color:#fff;text-decoration:none;font-size:20px}
        hr{border:0;border-top:1px solid #333;margin:24px}
        p{color:#888}
        </style></head><body>
        <h2>CarMedia no carro</h2>
        <p>Páginas protegidas por DRM podem não reproduzir aqui.</p>
        \(rows)
        <script>
        function go(u){webkit.messageHandlers.car.postMessage({action:"nav",url:u})}
        function play(u,t){webkit.messageHandlers.car.postMessage({action:"play",url:u,title:t})}
        function carMediaPauseWebVideo(){document.querySelectorAll("video").forEach(v=>v.pause())}
        </script></body></html>
        """
    }

    private static let pauseHelperJS = """
    window.carMediaPauseWebVideo = function(){document.querySelectorAll('video').forEach(v=>v.pause());};
    """
}
