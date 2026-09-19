// Headless check of the render + export path against the built bundle:
// does KaTeX load with no network, does every formula render, does PDF write.
import AppKit
import WebKit
import PDFKit

let bundleRes = URL(fileURLWithPath: CommandLine.arguments[1])
let docPath = CommandLine.arguments[2]
let pdfOut = CommandLine.arguments[3]
let source = try! String(contentsOf: URL(fileURLWithPath: docPath), encoding: .utf8)

let t0 = DispatchTime.now().uptimeNanoseconds
let result = DocTranspiler.render(source)
let transpileMS = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
print(String(format: "transpile: %.2f ms for %d chars, %d math chunks", transpileMS, source.count, result.mathCount))

final class Runner: NSObject, WKNavigationDelegate {
    let web: WKWebView
    var done = false

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1000), configuration: cfg)
        super.init()
        web.navigationDelegate = self
        web.loadFileURL(bundleRes.appendingPathComponent("preview.html"), allowingReadAccessTo: bundleRes)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let json = String(data: try! JSONSerialization.data(withJSONObject: [result.html]), encoding: .utf8)!
        let payload = String(json.dropFirst().dropLast())
        let t1 = DispatchTime.now().uptimeNanoseconds
        web.evaluateJavaScript("window.bl.set(\(payload)); 1") { _, err in
            let ms = Double(DispatchTime.now().uptimeNanoseconds - t1) / 1_000_000
            if let err { print("FAIL injecting document: \(err)"); exit(1) }
            print(String(format: "first render: %.1f ms", ms))
            self.audit()
        }
    }

    func audit() {
        let probe = """
        JSON.stringify({
          katex: document.querySelectorAll('.katex').length,
          errors: document.querySelectorAll('.katex-error, .err').length,
          errorText: Array.from(document.querySelectorAll('.katex-error, .err')).slice(0,6).map(e => e.textContent),
          fonts: document.fonts ? document.fonts.size : -1,
          fontsLoaded: !!(document.fonts && document.fonts.check('12px KaTeX_Main')),
          paragraphs: document.querySelectorAll('#doc p').length,
          tables: document.querySelectorAll('#doc table').length
        })
        """
        web.evaluateJavaScript(probe) { value, err in
            if let err { print("FAIL probe: \(err)"); exit(1) }
            print("dom: \(value as? String ?? "?")")
            // second render of the same doc exercises the math cache
            let t2 = DispatchTime.now().uptimeNanoseconds
            let json = String(data: try! JSONSerialization.data(withJSONObject: [result.html]), encoding: .utf8)!
            self.web.evaluateJavaScript("window.bl.set(\(String(json.dropFirst().dropLast()))); 1") { _, _ in
                print(String(format: "cached re-render: %.1f ms", Double(DispatchTime.now().uptimeNanoseconds - t2) / 1_000_000))
                self.pdf()
            }
        }
    }

    func pdf() {
        PDFExportJob.write(html: result.html, resources: bundleRes, to: URL(fileURLWithPath: pdfOut)) { error in
            if let error {
                print("FAIL pdf export: \(error)")
                exit(1)
            }
            guard let doc = PDFDocument(url: URL(fileURLWithPath: pdfOut)) else {
                print("FAIL pdf unreadable")
                exit(1)
            }
            let size = doc.page(at: 0)?.bounds(for: .mediaBox) ?? .zero
            let bytes = (try? Data(contentsOf: URL(fileURLWithPath: pdfOut)).count) ?? 0
            let text = (0..<doc.pageCount).compactMap { doc.page(at: $0)?.string }.joined()
            print("pdf: \(doc.pageCount) pages of \(Int(size.width))x\(Int(size.height))pt, \(bytes / 1024) KB, \(text.count) selectable chars")
            self.done = true
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let runner = Runner()
let deadline = Date().addingTimeInterval(25)
while !runner.done, Date() < deadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}
if !runner.done { print("FAIL timed out"); exit(1) }
exit(0)
