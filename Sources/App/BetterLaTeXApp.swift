import AppKit
import SwiftUI

@main
struct BetterLaTeXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var ws = Workspace()

    var body: some Scene {
        WindowGroup {
            RootView(ws: ws)
                .frame(minWidth: 820, minHeight: 520)
                .onAppear {
                    delegate.workspace = ws
                    ws.start()
                }
        }
        .defaultSize(width: 1420, height: 900)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    if let dir = ws.currentDoc?.url.deletingLastPathComponent() ?? ws.root {
                        ws.newFile(in: dir)
                    } else {
                        pickFolder(ws)
                    }
                }
                .keyboardShortcut("n")
                Button("Open Folder…") { pickFolder(ws) }
                    .keyboardShortcut("o")
                Divider()
                Button("Import PDF or LaTeX…") { ws.chooseAndImport() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { ws.save(ws.currentDoc) }
                    .keyboardShortcut("s")
                Divider()
                Button("Export PDF…") { ws.exportPDF() }
                    .keyboardShortcut("e")
                Button("Export LaTeX Source…") { ws.exportLaTeX() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Divider()
                Button("Close Document") {
                    if let doc = ws.currentDoc { ws.close(doc) }
                }
                .keyboardShortcut("w")
            }
            CommandMenu("View") {
                Button("Toggle File List") { ws.showSidebar.toggle() }
                    .keyboardShortcut("b")
                Button("Toggle Rendered Page") { ws.showPreview.toggle() }
                    .keyboardShortcut("r")
                Button(ws.showMeter ? "Hide Performance Meter" : "Show Performance Meter") {
                    ws.showMeter.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                Divider()
                Button("Next Document") { cycle(1) }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Previous Document") { cycle(-1) }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
            }
            CommandMenu("Shortcuts") {
                Button("Add Shortcut…") { ws.showAddShortcut = true }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Divider()
                Button("Edit Shortcuts File") { ws.openShortcutsFile() }
                Button("Reload Shortcuts") { ws.reloadShortcuts() }
            }
            CommandGroup(replacing: .help) {
                Button("English-to-LaTeX Reference") { ws.showReference() }
                    .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }
    }

    private func cycle(_ delta: Int) {
        guard !ws.docs.isEmpty, let cur = ws.docs.firstIndex(where: { $0.id == ws.currentID }) else { return }
        let next = (cur + delta + ws.docs.count) % ws.docs.count
        ws.select(ws.docs[next])
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var workspace: Workspace?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        workspace?.saveAll()
    }
}
