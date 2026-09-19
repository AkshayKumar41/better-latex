// Plain-text editor on TextKit 1 with an incremental highlighter.
// Recognized English keywords light up, which is also the feedback loop for the
// syntax: if a word stays grey, the transpiler does not know it.
import AppKit
import SwiftUI

struct EditorPane: NSViewRepresentable {
    @ObservedObject var doc: Doc
    let workspace: Workspace

    func makeCoordinator() -> Coordinator { Coordinator(workspace: workspace) }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)

        let tv = NSTextView(frame: .zero, textContainer: container)
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.backgroundColor = Palette.editorBG
        tv.insertionPointColor = Palette.brass
        tv.selectedTextAttributes = [NSAttributedString.Key.backgroundColor: Palette.selection]
        tv.textContainerInset = NSSize(width: 18, height: 16)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.defaultParagraphStyle = Highlighter.paragraphStyle
        tv.typingAttributes = Highlighter.baseAttributes

        let scroll = NSScrollView()
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Palette.editorBG

        context.coordinator.textView = tv
        context.coordinator.load(doc)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.load(doc)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        let workspace: Workspace
        private var loadedID: Doc.ID?
        private weak var doc: Doc?
        private var loading = false
        private var syncWork: DispatchWorkItem?

        init(workspace: Workspace) { self.workspace = workspace }

        func load(_ doc: Doc) {
            guard loadedID != doc.id, let tv = textView else { return }
            loadedID = doc.id
            self.doc = doc
            // Filling the view is not an edit: without this the file would be
            // marked dirty and rewritten the moment it was opened.
            loading = true
            defer { loading = false }
            tv.string = doc.text
            tv.undoManager?.removeAllActions()
            Highlighter.apply(to: tv.textStorage!, range: NSRange(location: 0, length: (doc.text as NSString).length))
            tv.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }

        func textDidChange(_ notification: Notification) {
            guard !loading, let tv = textView, let doc else { return }
            let text = tv.string
            workspace.textChanged(doc, to: text)
            Highlighter.apply(to: tv.textStorage!, range: Highlighter.block(in: text, around: tv.selectedRange()))
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = textView else { return }
            let selected = (tv.string as NSString).substring(with: tv.selectedRange())
            workspace.lastSelection = selected.trimmingCharacters(in: .whitespacesAndNewlines)
            guard workspace.showPreview else { return }
            syncWork?.cancel()
            let line = Highlighter.lineIndex(in: tv.string, at: tv.selectedRange().location)
            let work = DispatchWorkItem { [weak self] in self?.workspace.bridge.scroll(toLine: line) }
            syncWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }

        /// Soft tabs, and `(` auto-closes so `math(` is one keystroke less.
        func textView(_ tv: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
            guard let text else { return true }
            if text == "\t" {
                tv.insertText("  ", replacementRange: range)
                return false
            }
            if text == "(" {
                tv.insertText("()", replacementRange: range)
                tv.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                return false
            }
            if text == ")", range.length == 0 {
                let ns = tv.string as NSString
                if range.location < ns.length, ns.substring(with: NSRange(location: range.location, length: 1)) == ")" {
                    tv.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                    return false
                }
            }
            return true
        }
    }
}

enum Highlighter {
    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let boldFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
    static let headingFont = NSFont.monospacedSystemFont(ofSize: 14.5, weight: .bold)
    static let italicFont = NSFontManager.shared.convert(NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                                                         toHaveTrait: .italicFontMask)

    static var paragraphStyle: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 3
        p.paragraphSpacing = 2
        return p
    }()

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: Palette.ink, .paragraphStyle: paragraphStyle]
    }

    private static let constructNames: Set<String> = [
        "math", "m", "display", "displaymath", "block", "equation", "eq",
        "align", "aligned", "gather", "latex", "tex", "code", "verb", "mono", "text",
    ]

    private static let metaKeys: Set<String> = ["title", "author", "date", "abstract", "keywords"]

    private static let envKeys: Set<String> = [
        "theorem", "lemma", "corollary", "definition", "proposition",
        "proof", "remark", "example", "note", "claim",
    ]

    static func lineIndex(in text: String, at offset: Int) -> Int {
        let ns = text as NSString
        let clamped = min(max(offset, 0), ns.length)
        var line = 0
        ns.substring(to: clamped).enumerateLines { _, _ in line += 1 }
        return max(line - 1, 0)
    }

    /// The paragraph-ish span to re-highlight after an edit: out to blank lines.
    static func block(in text: String, around range: NSRange) -> NSRange {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard ns.length > 0 else { return full }
        let start = ns.paragraphRange(for: NSRange(location: min(range.location, ns.length - 1), length: 0))
        var lo = start.location
        var hi = min(start.location + start.length, ns.length)
        var seen = 0
        while lo > 0, seen < 3 {
            let prev = ns.paragraphRange(for: NSRange(location: lo - 1, length: 0))
            lo = prev.location
            if ns.substring(with: prev).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { seen += 1 }
        }
        seen = 0
        while hi < ns.length, seen < 3 {
            let next = ns.paragraphRange(for: NSRange(location: hi, length: 0))
            hi = min(next.location + next.length, ns.length)
            if ns.substring(with: next).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { seen += 1 }
        }
        return NSRange(location: lo, length: hi - lo)
    }

    static func apply(to storage: NSTextStorage, range: NSRange) {
        let ns = storage.string as NSString
        let safe = NSIntersectionRange(range, NSRange(location: 0, length: ns.length))
        guard safe.length > 0 else { return }
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: safe)

        let chars = Array(ns.substring(with: safe))
        let base = safe.location
        var i = 0

        func mark(_ start: Int, _ len: Int, _ attrs: [NSAttributedString.Key: Any]) {
            guard len > 0 else { return }
            let r = NSRange(location: base + start, length: len)
            guard NSMaxRange(r) <= ns.length else { return }
            storage.addAttributes(attrs, range: r)
        }

        var atLineStart = true
        while i < chars.count {
            let ch = chars[i]

            if ch == "\n" { atLineStart = true; i += 1; continue }
            if atLineStart, ch == " " || ch == "\t" { i += 1; continue }

            if atLineStart {
                if ch == "#" {
                    var j = i
                    while j < chars.count, chars[j] != "\n" { j += 1 }
                    mark(i, j - i, [.font: headingFont, .foregroundColor: Palette.brass])
                    i = j
                    continue
                }
                if ch == "-" || ch == "*" || ch == ">" || ch == "+", i + 1 < chars.count, chars[i + 1] == " " {
                    mark(i, 1, [.foregroundColor: Palette.brass, .font: boldFont])
                    i += 2
                    atLineStart = false
                    continue
                }
                if ch.isNumber {
                    var j = i
                    while j < chars.count, chars[j].isNumber { j += 1 }
                    if j < chars.count, chars[j] == "." || chars[j] == ")" {
                        mark(i, j - i + 1, [.foregroundColor: Palette.brass, .font: boldFont])
                        i = j + 1
                        atLineStart = false
                        continue
                    }
                }
                if ch.isLetter {
                    var j = i
                    while j < chars.count, chars[j].isLetter { j += 1 }
                    let word = String(chars[i..<j]).lowercased()
                    if j < chars.count, chars[j] == ":", metaKeys.contains(word) {
                        mark(i, j - i + 1, [.foregroundColor: Palette.muted, .font: boldFont])
                        i = j + 1
                        atLineStart = false
                        continue
                    }
                    if j < chars.count, chars[j] == ":", envKeys.contains(word) {
                        mark(i, j - i + 1, [.foregroundColor: Palette.brass, .font: boldFont])
                        i = j + 1
                        atLineStart = false
                        continue
                    }
                }
                atLineStart = false
            }

            if ch == "\\", i + 1 < chars.count {
                mark(i, 2, [.foregroundColor: Palette.muted])
                i += 2
                continue
            }

            if ch == "`" {
                var j = i + 1
                while j < chars.count, chars[j] != "`", chars[j] != "\n" { j += 1 }
                mark(i, min(j + 1, chars.count) - i, [.foregroundColor: Palette.teal, .backgroundColor: Palette.mathBG])
                i = min(j + 1, chars.count)
                continue
            }

            if ch == "*", i + 1 < chars.count, chars[i + 1] == "*" {
                if let end = findMarker(chars, from: i + 2, marker: "**") {
                    mark(i, end + 2 - i, [.font: boldFont])
                    i = end + 2
                    continue
                }
            }
            if ch == "*" {
                if let end = findMarker(chars, from: i + 1, marker: "*") {
                    mark(i, end + 1 - i, [.font: italicFont])
                    i = end + 1
                    continue
                }
            }

            if ch.isLetter {
                var j = i
                while j < chars.count, chars[j].isLetter { j += 1 }
                let word = String(chars[i..<j])
                if j < chars.count, chars[j] == "(", constructNames.contains(word.lowercased()) {
                    let (close, _) = balanced(chars, j)
                    mark(i, j - i + 1, [.foregroundColor: Palette.teal, .font: boldFont])
                    let innerStart = j + 1
                    let innerLen = max(close - innerStart, 0)
                    mark(innerStart, innerLen, [.foregroundColor: Palette.ink, .backgroundColor: Palette.mathBG])
                    highlightKeywords(chars, innerStart, innerStart + innerLen, mark)
                    if close < chars.count {
                        mark(close, 1, [.foregroundColor: Palette.teal, .font: boldFont])
                    }
                    i = min(close + 1, chars.count)
                    continue
                }
                i = j
                continue
            }
            if ch == "$" {
                let double = i + 1 < chars.count && chars[i + 1] == "$"
                let marker = double ? "$$" : "$"
                if let end = findMarker(chars, from: i + marker.count, marker: marker) {
                    mark(i, end + marker.count - i, [.backgroundColor: Palette.mathBG])
                    highlightKeywords(chars, i + marker.count, end, mark)
                    i = end + marker.count
                    continue
                }
            }
            i += 1
        }
        storage.endEditing()
    }

    /// Words the transpiler recognizes get the brass tint; unknown words stay plain.
    private static func highlightKeywords(_ chars: [Character], _ from: Int, _ to: Int,
                                         _ mark: (Int, Int, [NSAttributedString.Key: Any]) -> Void) {
        var i = from
        let end = min(to, chars.count)
        while i < end {
            guard chars[i].isLetter else { i += 1; continue }
            var j = i
            while j < end, chars[j].isLetter { j += 1 }
            let w = String(chars[i..<j]).lowercased()
            if Sym.bigOps[w] != nil || Sym.prefixOps[w] != nil || Sym.words[w] != nil
                || Sym.phrases[w] != nil || Sym.functions.contains(w) || Sym.greek(w) != nil
                || Sym.greek(String(chars[i..<j])) != nil {
                mark(i, j - i, [.foregroundColor: Palette.brass])
            }
            i = j
        }
    }

    private static func findMarker(_ chars: [Character], from: Int, marker: String) -> Int? {
        let m = Array(marker)
        var i = from
        while i + m.count <= chars.count {
            if chars[i] == "\n", i + 1 < chars.count, chars[i + 1] == "\n" { return nil }
            if Array(chars[i..<(i + m.count)]) == m { return i }
            i += 1
        }
        return nil
    }

    private static func balanced(_ chars: [Character], _ start: Int) -> (Int, Int) {
        var depth = 0
        var i = start
        while i < chars.count {
            if chars[i] == "\\" { i += 2; continue }
            if chars[i] == "(" { depth += 1 }
            if chars[i] == ")" {
                depth -= 1
                if depth == 0 { return (i, depth) }
            }
            i += 1
        }
        return (chars.count, depth)
    }
}
