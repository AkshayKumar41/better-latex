// Three columns: files, editor, live paper. The splitter positions are the
// user's; the panes themselves only appear when they have something to show.
import AppKit
import PDFKit
import SwiftUI

struct RootView: View {
    @ObservedObject var ws: Workspace
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
            HSplitView {
                if ws.showSidebar {
                    Sidebar(ws: ws)
                        .frame(minWidth: 170, idealWidth: 224, maxWidth: 380)
                }
                EditorColumn(ws: ws)
                    .frame(minWidth: 340)
                if ws.showPreview, ws.currentDoc != nil, ws.currentDoc?.previewable == true {
                    PreviewPane(bridge: ws.bridge)
                        .frame(minWidth: 320)
                        .background(Palette.surroundC)
                }
            }
            if ws.showMeter {
                PerfOverlay(meter: ws.meter, renderMS: ws.renderMS)
                    .padding(.top, 9)
                    .padding(.trailing, 11)
                    .transition(.opacity)
            }
            }
            StatusBar(ws: ws)
        }
        .background(Palette.editorC)
        .onChange(of: scheme) {
            ws.bridge.appearance(dark: scheme == .dark)
        }
        .onAppear {
            if ws.showMeter { ws.meter.start() }
        }
        .sheet(isPresented: $ws.showAddShortcut) {
            ShortcutSheet(ws: ws)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    ws.showSidebar.toggle()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help("Show or hide the file list (Cmd-B)")
            }
            ToolbarItemGroup {
                Button { pickFolder(ws) } label: { Image(systemName: "folder") }
                    .help("Open a project folder (Cmd-O)")
                Button {
                    if let dir = ws.currentDoc?.url.deletingLastPathComponent() ?? ws.root { ws.newFile(in: dir) }
                } label: { Image(systemName: "doc.badge.plus") }
                    .help("New document (Cmd-N)")
                Spacer()
                Button { ws.exportLaTeX() } label: { Image(systemName: "function") }
                    .help("Export the generated .tex source (Cmd-Shift-E)")
                Button { ws.exportPDF() } label: { Image(systemName: "arrow.down.document") }
                    .help("Save the rendered document as PDF (Cmd-E)")
                Button { ws.showAddShortcut = true } label: { Image(systemName: "wand.and.stars") }
                    .help("Add a shortcut of your own (Cmd-Shift-K)")
                Button { ws.showPreview.toggle() } label: {
                    Image(systemName: ws.showPreview ? "rectangle.righthalf.filled" : "rectangle")
                }
                .help("Show or hide the rendered page (Cmd-R)")
            }
        }
    }
}

func pickFolder(_ ws: Workspace) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Open Project"
    if panel.runModal() == .OK, let url = panel.url { ws.openFolder(url) }
}

// MARK: - editor column

private struct EditorColumn: View {
    @ObservedObject var ws: Workspace

    var body: some View {
        VStack(spacing: 0) {
            TabStrip(ws: ws)
            Divider()
            if let doc = ws.currentDoc {
                content(for: doc)
            } else {
                ReferencePane(ws: ws)
            }
        }
        .background(Palette.editorC)
    }

    @ViewBuilder private func content(for doc: Doc) -> some View {
        switch doc.kind {
        case .text where doc.isTeX:
            VStack(spacing: 0) {
                ConvertBar(name: doc.name,
                           note: "LaTeX source",
                           action: { ws.importTeX(doc.url) })
                Divider()
                EditorPane(doc: doc, workspace: ws).id(doc.id)
            }
        case .text:
            EditorPane(doc: doc, workspace: ws).id(doc.id)
        case .pdf:
            VStack(spacing: 0) {
                ConvertBar(name: doc.name,
                           note: "read only",
                           action: { ws.importPDF(doc.url) })
                Divider()
                PDFPane(url: doc.url).id(doc.id)
            }
        case .image:
            ScrollView { 
                if let img = NSImage(contentsOf: doc.url) {
                    Image(nsImage: img).resizable().scaledToFit().padding(20)
                }
            }
            .background(Palette.surroundC)
        case .binary:
            VStack(spacing: 8) {
                Text(doc.name).font(.system(size: 13, weight: .semibold))
                Text("This file is not text, so there is nothing to edit here.")
                    .font(.system(size: 12)).foregroundColor(Palette.mutedC)
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([doc.url]) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.editorC)
        }
    }
}

/// Offered above anything that can be rebuilt as an editable document.
private struct ConvertBar: View {
    let name: String
    let note: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11))
                .foregroundColor(Palette.tealC)
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Palette.inkC)
                .lineLimit(1)
            Text(note)
                .font(.system(size: 10))
                .foregroundColor(Palette.mutedC)
            Spacer()
            Button("Convert to English") { action() }
                .controlSize(.small)
                .help("Rewrite this as an editable document. The conversion is a draft to check, not a compiler.")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Palette.panelC)
    }
}

private struct PDFPane: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.backgroundColor = Palette.surround
        v.document = PDFDocument(url: url)
        return v
    }

    func updateNSView(_ v: PDFView, context: Context) {
        if v.document?.documentURL != url { v.document = PDFDocument(url: url) }
    }
}

// MARK: - tabs

private struct TabStrip: View {
    @ObservedObject var ws: Workspace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ReferenceChip(ws: ws, active: ws.currentID == nil)
                ForEach(ws.docs) { doc in
                    TabChip(doc: doc, ws: ws, active: doc.id == ws.currentID)
                }
            }
        }
        .frame(height: 34)
        .background(Palette.panelC)
    }
}

private struct ReferenceChip: View {
    @ObservedObject var ws: Workspace
    let active: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 10))
                .foregroundColor(active ? Palette.brassC : Palette.mutedC)
            Text("Reference")
                .font(.system(size: 12, weight: active ? .semibold : .regular))
                .foregroundColor(active ? Palette.inkC : Palette.mutedC)
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(active ? Palette.editorC : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(active ? Palette.brassC : Color.clear).frame(height: 2)
        }
        .overlay(alignment: .trailing) { Rectangle().fill(Palette.borderC).frame(width: 1) }
        .contentShape(Rectangle())
        .onTapGesture { ws.showReference() }
        .help("Every word the converter knows. Read only.")
    }
}

/// The launch state: the reference, rendered and read-only, with the one action
/// that has to happen before any writing can start.
private struct ReferencePane: View {
    @ObservedObject var ws: Workspace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("English to LaTeX")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.inkC)
                    Text(ws.root == nil
                         ? "Reference only. Choose a folder before writing."
                         : "Reference only. Open a file, or make a new document.")
                        .font(.system(size: 11))
                        .foregroundColor(Palette.mutedC)
                }
                Spacer()
                if let root = ws.root {
                    Button("New Document") { ws.newFile(in: root) }
                        .controlSize(.small)
                    Button("Change Folder…") { pickFolder(ws) }
                        .controlSize(.small)
                } else {
                    Button("Choose Folder…") { pickFolder(ws) }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Palette.panelC)
            Divider()
            PreviewPane(bridge: ws.bridge)
                .background(Palette.surroundC)
        }
    }
}

private struct TabChip: View {
    @ObservedObject var doc: Doc
    @ObservedObject var ws: Workspace
    let active: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(active ? Palette.brassC : Palette.mutedC)
            Text(doc.name)
                .font(.system(size: 12, weight: active ? .semibold : .regular))
                .foregroundColor(active ? Palette.inkC : Palette.mutedC)
                .lineLimit(1)
            if doc.dirty {
                Circle().fill(Palette.brassC).frame(width: 5, height: 5)
            }
            Button { ws.close(doc) } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundColor(Palette.mutedC)
            .opacity(hovering || active ? 1 : 0)
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(active ? Palette.editorC : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(active ? Palette.brassC : Color.clear)
                .frame(height: 2)
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.borderC).frame(width: 1)
        }
        .onHover { hovering = $0 }
        .onTapGesture { ws.select(doc) }
        .contextMenu {
            Button("Close") { ws.close(doc) }
            Button("Close Others") { ws.docs.filter { $0.id != doc.id }.forEach { ws.close($0) } }
            Divider()
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([doc.url]) }
        }
    }

    private var icon: String {
        switch doc.kind {
        case .pdf: return "doc.richtext"
        case .image: return "photo"
        case .binary: return "doc"
        case .text: return doc.previewable ? "text.alignleft" : "doc.plaintext"
        }
    }
}

// MARK: - sidebar

private struct Sidebar: View {
    @ObservedObject var ws: Workspace
    @State private var expanded: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(ws.root?.lastPathComponent.uppercased() ?? "NO FOLDER")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Palette.mutedC)
                    .lineLimit(1)
                Spacer()
                Button { if let r = ws.root { ws.newFile(in: r) } } label: {
                    Image(systemName: "doc.badge.plus").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundColor(Palette.mutedC)
                .disabled(!ws.canEdit)
                .help(ws.canEdit ? "New document" : "Choose a folder first")
                Button { if let r = ws.root { ws.newFolder(in: r) } } label: {
                    Image(systemName: "folder.badge.plus").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundColor(Palette.mutedC)
                .disabled(!ws.canEdit)
                .help(ws.canEdit ? "New folder" : "Choose a folder first")
                Button { ws.treeVersion += 1 } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundColor(Palette.mutedC)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            Divider()
            if ws.root == nil {
                NoFolder(ws: ws)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let root = ws.root {
                            TreeLevel(dir: root, depth: 0, ws: ws, expanded: $expanded)
                        }
                    }
                    .padding(.vertical, 6)
                    .id(ws.treeVersion)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .background(Palette.panelC)
    }
}

private struct NoFolder: View {
    @ObservedObject var ws: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(Palette.brassC)
            Text("No folder linked")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Palette.inkC)
            Text("Documents live in a folder you choose. Pick one to create files, open them in tabs and export PDFs.")
                .font(.system(size: 11))
                .foregroundColor(Palette.mutedC)
                .fixedSize(horizontal: false, vertical: true)
            Button("Choose Folder…") { pickFolder(ws) }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
            Text("The reference on the right works without one.")
                .font(.system(size: 10))
                .foregroundColor(Palette.mutedC)
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TreeLevel: View {
    let dir: URL
    let depth: Int
    @ObservedObject var ws: Workspace
    @Binding var expanded: Set<URL>

    var body: some View {
        ForEach(FileList.children(of: dir), id: \.self) { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            TreeRow(url: url, isDir: isDir, depth: depth, ws: ws, expanded: $expanded)
            if isDir, expanded.contains(url) {
                TreeLevel(dir: url, depth: depth + 1, ws: ws, expanded: $expanded)
            }
        }
    }
}

private struct TreeRow: View {
    let url: URL
    let isDir: Bool
    let depth: Int
    @ObservedObject var ws: Workspace
    @Binding var expanded: Set<URL>
    @State private var hovering = false
    @State private var renaming = false
    @State private var newName = ""

    var body: some View {
        let selected = ws.currentDoc?.url == url
        HStack(spacing: 5) {
            if isDir {
                Image(systemName: expanded.contains(url) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Palette.mutedC)
                    .frame(width: 9)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)
                    .frame(width: 9)
            }
            Text(url.lastPathComponent)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? Palette.inkC : Palette.inkC.opacity(0.86))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(depth) * 13 + 12)
        .padding(.trailing, 8)
        .frame(height: 23)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Palette.brassC.opacity(0.14) : (hovering ? Palette.inkC.opacity(0.05) : Color.clear))
        .overlay(alignment: .leading) {
            Rectangle().fill(selected ? Palette.brassC : Color.clear).frame(width: 2)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if isDir {
                if expanded.contains(url) { expanded.remove(url) } else { expanded.insert(url) }
            } else {
                ws.open(url)
            }
        }
        .contextMenu {
            if isDir {
                Button("New Document") { ws.newFile(in: url) }
                Button("New Folder") { ws.newFolder(in: url) }
                Divider()
            }
            Button("Rename…") { newName = url.lastPathComponent; renaming = true }
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Divider()
            Button("Move to Trash") { ws.trash(url) }
        }
        .alert("Rename", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Rename") { ws.rename(url, to: newName) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var icon: String {
        switch url.pathExtension.lowercased() {
        case "bltx": return "text.alignleft"
        case "pdf": return "doc.richtext"
        case "tex": return "function"
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff": return "photo"
        case "md", "markdown", "txt": return "doc.plaintext"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        switch url.pathExtension.lowercased() {
        case "bltx": return Palette.brassC
        case "pdf": return Palette.tealC
        default: return Palette.mutedC
        }
    }
}

enum FileList {
    static func children(of dir: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        return items.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let db = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if da != db { return da }
            return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
        }
    }
}

// MARK: - status bar

private struct StatusBar: View {
    @ObservedObject var ws: Workspace

    var body: some View {
        HStack(spacing: 14) {
            Text(ws.status)
                .foregroundColor(Palette.mutedC)
                .lineLimit(1)
            Spacer()
            if ws.currentDoc?.previewable == true {
                Label("\(ws.rendered.wordCount) words", systemImage: "text.word.spacing")
                Label("\(ws.rendered.mathCount) math", systemImage: "x.squareroot")
                Text(String(format: "%.1f ms", ws.renderMS))
                    .monospacedDigit()
                    .foregroundColor(ws.renderMS > 25 ? Palette.brassC : Palette.tealC)
                    .help("Time to convert this document on the last keystroke")
            }
            Text("offline")
                .foregroundColor(Palette.mutedC)
                .help("Rendering is local: no network, no LaTeX installation")
        }
        .labelStyle(.titleAndIcon)
        .font(.system(size: 11))
        .foregroundColor(Palette.mutedC)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Palette.panelC)
        .overlay(alignment: .top) { Rectangle().fill(Palette.borderC).frame(height: 1) }
    }
}
