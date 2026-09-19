// Workspace state: folder tree, open tabs, the render pipeline, export.
// Everything is one-shot work items: nothing polls, nothing runs while idle.
import AppKit
import Combine
import SwiftUI

final class Doc: ObservableObject, Identifiable {
    enum Kind { case text, pdf, image, binary }

    let id = UUID()
    @Published var url: URL
    @Published var dirty = false
    var text: String
    let kind: Kind

    var name: String { url.lastPathComponent }

    init(url: URL) {
        self.url = url
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            kind = .pdf
            text = ""
        } else if ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff"].contains(ext) {
            kind = .image
            text = ""
        } else if let s = try? String(contentsOf: url, encoding: .utf8) {
            kind = .text
            text = s
        } else {
            kind = .binary
            text = ""
        }
    }

    /// English-source files get the live LaTeX preview.
    var previewable: Bool {
        kind == .text && ["bltx", "tex", "md", "txt", "markdown", ""].contains(url.pathExtension.lowercased())
    }
}

final class Workspace: ObservableObject {
    @Published var root: URL?
    @Published var docs: [Doc] = []
    @Published var currentID: Doc.ID?
    @Published var showSidebar = true
    @Published var showPreview = true
    @Published var rendered = Rendered()
    @Published var renderMS: Double = 0
    @Published var status = "Ready"
    @Published var treeVersion = 0

    @Published var showMeter = UserDefaults.standard.object(forKey: "showMeter") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(showMeter, forKey: "showMeter")
            showMeter ? meter.start() : meter.stop()
        }
    }

    @Published var showAddShortcut = false
    var lastSelection = ""

    let bridge = PreviewBridge()
    let meter = PerfMeter()

    private var renderWork: DispatchWorkItem?
    private var saveWork: DispatchWorkItem?
    private let queue = DispatchQueue(label: "bltx.render", qos: .userInitiated)
    private var lastRenderedSource = ""

    var currentDoc: Doc? { docs.first { $0.id == currentID } }

    // MARK: folder

    func openFolder(_ url: URL) {
        root = url
        treeVersion += 1
        UserDefaults.standard.set(url.path, forKey: "lastFolder")
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        status = url.lastPathComponent
    }

    /// Restores the last folder if it still exists. Nothing is created, nothing is
    /// opened: the reference page is what you get until you choose a folder.
    func start() {
        UserSymbols.shared.createIfMissing()
        if let path = UserDefaults.standard.string(forKey: "lastFolder"),
           FileManager.default.fileExists(atPath: path) {
            openFolder(URL(fileURLWithPath: path))
        } else {
            status = "Choose a folder to start writing"
        }
        showReference()
    }

    var lastFolder: URL? {
        guard let path = UserDefaults.standard.string(forKey: "lastFolder"),
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    // MARK: reference page

    /// The bundled syntax reference, rendered read-only. Cached after the first build.
    private var referenceHTML: String?

    func showReference() {
        currentID = nil
        lastRenderedSource = ""
        if referenceHTML == nil {
            let source = (Bundle.main.resourceURL?.appendingPathComponent("sample/syntax.bltx"))
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "# Reference unavailable"
            let doc = DocTranspiler.render(source)
            referenceHTML = doc.html
            rendered = doc
        }
        bridge.set(html: referenceHTML ?? "")
    }

    // MARK: tabs

    func open(_ url: URL) {
        if let existing = docs.first(where: { $0.url == url }) {
            currentID = existing.id
            render(immediate: true)
            return
        }
        let doc = Doc(url: url)
        docs.append(doc)
        currentID = doc.id
        render(immediate: true)
    }

    func close(_ doc: Doc) {
        save(doc)
        let idx = docs.firstIndex { $0.id == doc.id }
        docs.removeAll { $0.id == doc.id }
        if currentID == doc.id {
            let next = min(idx ?? 0, docs.count - 1)
            currentID = docs.indices.contains(next) ? docs[next].id : nil
        }
        render(immediate: true)
        if currentID == nil { showReference() }
    }

    func select(_ doc: Doc) {
        currentID = doc.id
        render(immediate: true)
    }

    // MARK: editing

    func textChanged(_ doc: Doc, to newText: String) {
        doc.text = newText
        if !doc.dirty { doc.dirty = true }
        render()
        scheduleSave(doc)
    }

    // MARK: render

    func render(immediate: Bool = false) {
        renderWork?.cancel()
        guard let doc = currentDoc else {
            showReference()
            return
        }
        guard doc.previewable else {
            if doc.kind == .text { rendered = Rendered() }
            return
        }
        let source = doc.text
        if immediate { lastRenderedSource = "" }
        guard source != lastRenderedSource else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UserSymbols.shared.reloadIfChanged()
            let t0 = DispatchTime.now().uptimeNanoseconds
            let result = DocTranspiler.render(source)
            let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
            DispatchQueue.main.async {
                self.lastRenderedSource = source
                self.rendered = result
                self.renderMS = ms
                self.bridge.set(html: result.html)
            }
        }
        renderWork = work
        // 70ms: below the eye's threshold for "instant", above per-keystroke churn.
        queue.asyncAfter(deadline: .now() + (immediate ? 0 : 0.07), execute: work)
    }

    // MARK: saving

    private func scheduleSave(_ doc: Doc) {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self, weak doc] in
            guard let doc else { return }
            self?.save(doc)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    func save(_ doc: Doc?) {
        guard let doc, doc.kind == .text, doc.dirty else { return }
        do {
            try doc.text.write(to: doc.url, atomically: true, encoding: .utf8)
            doc.dirty = false
            status = "Saved \(doc.name)"
            if doc.url == UserSymbols.shared.url {
                UserSymbols.shared.load()
                lastRenderedSource = ""
                status = "Shortcuts updated"
            }
        } catch {
            status = "Could not save \(doc.name): \(error.localizedDescription)"
        }
    }

    func saveAll() {
        saveWork?.cancel()
        docs.forEach { save($0) }
    }

    // MARK: shortcuts

    func openShortcutsFile() {
        UserSymbols.shared.createIfMissing()
        open(UserSymbols.shared.url)
    }

    func reloadShortcuts() {
        UserSymbols.shared.load()
        status = UserSymbols.shared.isEmpty ? "No shortcuts defined yet" : "Reloaded shortcuts"
        render(immediate: true)
    }

    // MARK: file operations

    var canEdit: Bool { root != nil }

    func newFile(in dir: URL, named suggestion: String = "untitled.bltx") {
        var url = dir.appendingPathComponent(suggestion)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            let base = suggestion.replacingOccurrences(of: ".bltx", with: "")
            url = dir.appendingPathComponent("\(base)-\(n).bltx")
            n += 1
        }
        let starter = "title: \(url.deletingPathExtension().lastPathComponent)\n\n# Section\n\nWrite in English. Inline math like math(x^2 + y^2 = r^2).\n"
        try? starter.write(to: url, atomically: true, encoding: .utf8)
        treeVersion += 1
        open(url)
    }

    func newFolder(in dir: URL) {
        var url = dir.appendingPathComponent("New Folder")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("New Folder \(n)")
            n += 1
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        treeVersion += 1
    }

    func rename(_ url: URL, to newName: String) {
        guard !newName.isEmpty else { return }
        let dest = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: url, to: dest)
            docs.filter { $0.url == url }.forEach { $0.url = dest }
            treeVersion += 1
        } catch {
            status = "Rename failed: \(error.localizedDescription)"
        }
    }

    /// Moves to Trash rather than unlinking, so a misclick is recoverable.
    func trash(_ url: URL) {
        docs.filter { $0.url == url || $0.url.path.hasPrefix(url.path + "/") }.forEach { close($0) }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            treeVersion += 1
            status = "Moved \(url.lastPathComponent) to Trash"
        } catch {
            status = "Delete failed: \(error.localizedDescription)"
        }
    }

    // MARK: export

    func exportPDF() {
        guard let doc = currentDoc, doc.previewable else {
            status = "Open an English document to export"
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = doc.url.deletingPathExtension().lastPathComponent + ".pdf"
        panel.canCreateDirectories = true
        panel.directoryURL = doc.url.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let resources = Bundle.main.resourceURL else { return }
        status = "Writing \(url.lastPathComponent)…"
        let html = DocTranspiler.render(doc.text).html
        PDFExportJob.write(html: html, resources: resources, to: url) { [weak self] error in
            if let error {
                self?.status = "PDF export failed: \(error)"
            } else {
                self?.status = "Exported \(url.lastPathComponent)"
                self?.treeVersion += 1
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    func exportLaTeX() {
        guard let doc = currentDoc, doc.previewable else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = doc.url.deletingPathExtension().lastPathComponent + ".tex"
        panel.directoryURL = doc.url.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let latex = DocTranspiler.render(doc.text).latex
        do {
            try latex.write(to: url, atomically: true, encoding: .utf8)
            status = "Exported \(url.lastPathComponent)"
            treeVersion += 1
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }
}
