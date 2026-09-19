// Add-a-shortcut sheet. Writes one line to the shortcuts file, which every open
// document picks up on the next keystroke.
import AppKit
import SwiftUI

struct ShortcutSheet: View {
    @ObservedObject var ws: Workspace
    @State private var trigger = ""
    @State private var expansion = ""
    @State private var error: String?
    @State private var entries: [(String, String)] = []
    @FocusState private var focus: Field?

    private enum Field { case trigger, expansion }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("New shortcut")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.inkC)

                HStack(spacing: 10) {
                    field("When I type", text: $trigger, placeholder: "qed", focused: .trigger)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Palette.mutedC)
                        .padding(.top, 16)
                    field("Write this", text: $expansion, placeholder: "blacksquare", focused: .expansion)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("PREVIEW")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.7)
                        .foregroundColor(Palette.mutedC)
                    Text(preview)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(expansion.isEmpty ? Palette.mutedC : Palette.tealC)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Palette.surroundC))
                }

                Text("The right side is ordinary English, so it can use other shortcuts, and a backslash command passes straight through.")
                    .font(.system(size: 10.5))
                    .foregroundColor(Palette.mutedC)
                    .fixedSize(horizontal: false, vertical: true)

                if let error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(Color(nsColor: .systemRed))
                }
            }
            .padding(18)

            if !entries.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    Text("YOUR SHORTCUTS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.7)
                        .foregroundColor(Palette.mutedC)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(entries, id: \.0) { key, value in
                                HStack(spacing: 8) {
                                    Text(key)
                                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                        .foregroundColor(Palette.brassC)
                                    Text(value)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundColor(Palette.inkC.opacity(0.8))
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        UserSymbols.shared.remove(trigger: key)
                                        refresh()
                                        ws.render(immediate: true)
                                    } label: {
                                        Image(systemName: "trash").font(.system(size: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(Palette.mutedC)
                                    .help("Delete this shortcut")
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 5)
                            }
                        }
                    }
                    .frame(maxHeight: 132)
                }
                .padding(.bottom, 6)
            }

            Divider()
            HStack(spacing: 10) {
                Button("Open the file") {
                    ws.openShortcutsFile()
                    ws.showAddShortcut = false
                }
                Spacer()
                Button("Done") { ws.showAddShortcut = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trigger.isEmpty || expansion.isEmpty)
            }
            .padding(14)
        }
        .frame(width: 520)
        .background(Palette.panelC)
        .onAppear {
            expansion = ws.lastSelection
            refresh()
            focus = .trigger
        }
    }

    private var preview: String {
        guard !expansion.isEmpty else { return "the LaTeX appears here" }
        return MathParser.latex(expansion)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, focused: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundColor(Palette.mutedC)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .focused($focus, equals: focused)
        }
    }

    private func save() {
        if let problem = UserSymbols.shared.add(trigger: trigger, expansion: expansion) {
            error = problem
            return
        }
        ws.status = "Added shortcut \(trigger.lowercased())"
        trigger = ""
        expansion = ""
        error = nil
        refresh()
        ws.render(immediate: true)
    }

    private func refresh() { entries = UserSymbols.shared.entries }
}
