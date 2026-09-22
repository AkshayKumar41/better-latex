// PDF export: render the document once in an offscreen web view, then cut it
// into letter pages at block boundaries. WebKit's own print path is avoided -
// printOperation(with:) blocks forever on a windowless WKWebView.
import AppKit
import PDFKit
import WebKit

final class PDFExportJob: NSObject, WKNavigationDelegate {
    private static var live: Set<PDFExportJob> = []

    private let html: String
    private let dest: URL
    private let done: (String?) -> Void
    private let web: WKWebView

    /// 96dpi CSS pixels per 72pt inch: a 6.5in column is 624px, a 9in body 864px.
    private let columnPX: CGFloat = 624
    private let pageHeightPX: CGFloat = 864
    private let margin: CGFloat = 72
    private let paper = CGSize(width: 612, height: 792)

    static func write(html: String, resources: URL, to dest: URL, completion: @escaping (String?) -> Void) {
        let job = PDFExportJob(html: html, resources: resources, dest: dest, completion: completion)
        live.insert(job)
    }

    private init(html: String, resources: URL, dest: URL, completion: @escaping (String?) -> Void) {
        self.html = html
        self.dest = dest
        self.done = completion
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: columnPX, height: pageHeightPX), configuration: cfg)
        super.init()
        web.navigationDelegate = self
        web.loadFileURL(resources.appendingPathComponent("preview.html"), allowingReadAccessTo: resources)
    }

    private func finish(_ error: String?) {
        done(error)
        PDFExportJob.live.remove(self)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let payload = jsString(html) else { return finish("Could not encode the document") }
        let js = """
        window.bl.exportOn();
        window.bl.set(\(payload));
        await window.bl.ready();
        window.bl.set(\(payload));
        return window.bl.metrics(\(Int(pageHeightPX)));
        """
        web.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.finish("Layout failed: \(error.localizedDescription)")
            case .success(let value):
                guard let json = value as? String,
                      let data = json.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let total = (dict["total"] as? NSNumber)?.doubleValue,
                      let width = (dict["width"] as? NSNumber)?.doubleValue,
                      let breaks = dict["breaks"] as? [NSNumber] else {
                    return self.finish("Could not measure the page")
                }
                self.renderPDF(total: CGFloat(total),
                               width: CGFloat(width),
                               breaks: breaks.map { CGFloat($0.doubleValue) })
            }
        }
    }

    private func renderPDF(total: CGFloat, width: CGFloat, breaks: [CGFloat]) {
        web.frame = NSRect(x: 0, y: 0, width: columnPX, height: max(total, pageHeightPX))
        web.createPDF(configuration: WKPDFConfiguration()) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.finish(error.localizedDescription)
            case .success(let data):
                self.finish(self.slice(data, total: total, width: width, breaks: breaks))
            }
        }
    }

    /// Draws the one tall page into letter pages, clipped and scaled to the margins.
    private func slice(_ data: Data, total: CGFloat, width: CGFloat, breaks: [CGFloat]) -> String? {
        guard let provider = CGDataProvider(data: data as CFData),
              let src = CGPDFDocument(provider), let page = src.page(at: 1) else {
            return "WebKit returned an unreadable PDF"
        }
        let box = page.getBoxRect(.mediaBox)
        let scale = (paper.width - margin * 2) / max(width, 1)
        var mediaBox = CGRect(origin: .zero, size: paper)
        guard let ctx = CGContext(dest as CFURL, mediaBox: &mediaBox, nil) else {
            return "Could not create the file"
        }
        var top: CGFloat = 0
        for cut in breaks {
            let bottom = min(cut, total)
            guard bottom > top + 1 else { continue }
            // The clip has to stop exactly where this slice's content ends, not at
            // the nominal full-page height: a safe break almost never lands exactly
            // on that nominal boundary, so a fixed-height clip let a few pixels of
            // the next line bleed through at the bottom of the page - which then
            // drew again in full at the top of the next page.
            let clipHeight = min((bottom - top) * scale, paper.height - margin * 2)
            let clipY = paper.height - margin - clipHeight
            ctx.beginPDFPage(nil)
            ctx.saveGState()
            ctx.clip(to: CGRect(x: margin, y: clipY, width: paper.width - margin * 2, height: clipHeight))
            // CSS y grows downward; the source page's origin is bottom-left.
            ctx.translateBy(x: margin, y: paper.height - margin - scale * box.height + scale * top)
            ctx.scaleBy(x: scale, y: scale)
            ctx.drawPDFPage(page)
            ctx.restoreGState()
            ctx.endPDFPage()
            top = bottom
        }
        ctx.closePDF()
        return nil
    }

    private func jsString(_ s: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: [s]),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return String(str.dropFirst().dropLast())
    }
}
