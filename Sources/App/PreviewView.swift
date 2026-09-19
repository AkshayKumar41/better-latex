// Live preview: one long-lived WKWebView that the bridge owns, so toggling the
// pane never reloads it and KaTeX's render cache survives.
import AppKit
import SwiftUI
import WebKit

final class PreviewBridge: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    private var loaded = false
    private var pending: String?

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: cfg)
        super.init()
        webView.navigationDelegate = self
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        load()
    }

    private func load() {
        guard let res = Bundle.main.resourceURL else { return }
        let page = res.appendingPathComponent("preview.html")
        webView.loadFileURL(page, allowingReadAccessTo: res)
    }

    func set(html: String) {
        guard let json = encode(html) else { return }
        guard loaded else { pending = html; return }
        webView.evaluateJavaScript("window.bl.set(\(json))")
    }

    func scroll(toLine line: Int) {
        guard loaded else { return }
        webView.evaluateJavaScript("window.bl.syncTo(\(line))")
    }

    func appearance(dark: Bool) {
        guard loaded else { return }
        webView.evaluateJavaScript("window.bl.theme(\(dark))")
    }

    private func encode(_ s: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: [s], options: []),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return String(str.dropFirst().dropLast())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        appearance(dark: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        if let pending {
            set(html: pending)
            self.pending = nil
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

}

struct PreviewPane: NSViewRepresentable {
    let bridge: PreviewBridge

    func makeNSView(context: Context) -> WKWebView { bridge.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
