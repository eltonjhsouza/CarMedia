// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).

import Foundation
import WebKit

@MainActor
public final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published public var addressText: String = ""
    @Published public private(set) var currentURL: URL?
    @Published public private(set) var pageTitle: String = ""
    @Published public private(set) var canGoBack = false
    @Published public private(set) var canGoForward = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var loadError: BrowserError?
    /// Bumped after a visit is recorded so sheets (favorites/history) refresh.
    @Published public private(set) var visitCounter = 0

    public let webView: WKWebView
    public static let shared = BrowserModel()

    public struct BrowserError: Identifiable {
        public let id = UUID()
        public let kind: Kind
        public enum Kind { case invalidURL(String), unavailable(String), failed(String) }
        public var message: String {
            switch kind {
            case .invalidURL(let s): return "URL inválida: \(s)"
            case .unavailable(let s): return "Página indisponível: \(s)"
            case .failed(let s): return "Falha ao carregar: \(s)"
            }
        }
    }

    override init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = {
            let p = WKWebpagePreferences()
            p.preferredContentMode = .mobile
            return p
        }()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        config.applicationNameForUserAgent = "CarMedia"
    }

    // MARK: - Commands

    public func submit(_ raw: String) {
        loadError = nil
        switch URLNormalizer.interpret(raw) {
        case .url(let url): load(url)
        case .search(let q):
            if let url = URLNormalizer.searchURL(for: q) { load(url) }
            else { loadError = BrowserError(kind: .invalidURL(raw)) }
        case .empty: break
        case .invalid(let s): loadError = BrowserError(kind: .invalidURL(s))
        }
    }

    public func load(_ url: URL) {
        addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    public func goHome() { load(URLNormalizer.homeURL()) }
    public func reload() { webView.reload() }
    public func goBack() { webView.goBack() }
    public func goForward() { webView.goForward() }

    public func stop() { webView.stopLoading() }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction)
        async -> WKNavigationActionPolicy {
        // Non-web schemes leave the browser instead of erroring inside it.
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
           !["http", "https", "about", "blob", "data"].contains(scheme) {
            EventLog.shared.record(.browser, "external scheme \(scheme) denied inline")
            if UIApplication.shared.canOpenURL(url) { await UIApplication.shared.open(url) }
            return .cancel
        }
        return .allow
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        loadError = nil
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        currentURL = webView.url
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        pageTitle = webView.title ?? (webView.url?.host ?? "")
        addressText = webView.url?.absoluteString ?? addressText
        if let url = webView.url, !url.isFileURL, url.scheme?.hasPrefix("http") == true {
            Persistence.recordVisit(url: url, title: pageTitle, context: Persistence.container.mainContext)
            visitCounter += 1
        }
        EventLog.shared.record(.browser, "loaded \(LogScrubber.scrubURL(webView.url?.absoluteString ?? "?"))")
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, with error: Error) {
        finishFailure(error)
    }

    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!, with error: Error) {
        finishFailure(error)
    }

    private func finishFailure(_ error: Error) {
        isLoading = false
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        let kind: BrowserError.Kind = (ns.domain == NSURLErrorDomain &&
            [NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost].contains(ns.code))
            ? .unavailable(ns.localizedDescription)
            : .failed(ns.localizedDescription)
        loadError = BrowserError(kind: kind)
        EventLog.shared.record(.browser, "load error: \(kind == .unavailable(ns.localizedDescription) ? "unreachable" : "failed") \(ns.localizedDescription)")
    }

    // Open-target blank windows (window.open) load in the same view.
    public func webView(_ webView: WKWebView,
                        createWebViewWith configuration: WKWebViewConfiguration,
                        for navigationAction: WKNavigationAction,
                        windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { webView.load(URLRequest(url: url)) }
        return nil
    }
}
