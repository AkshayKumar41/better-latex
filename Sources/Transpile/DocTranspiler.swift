// Document-level English -> (HTML preview, LaTeX export).
// Phase 1 lifts math/code constructs out of the source so that phase 2 can be
// a flat line scan. Both emitters run in the same pass over the block list.
import Foundation

struct Rendered {
    var html: String = ""
    var latex: String = ""
    var mathCount = 0
    var wordCount = 0
    var title = ""
}

private struct Chunk {
    enum Kind { case inlineMath, display, equation, align, rawLatex, code }
    var kind: Kind
    var body: String
}

enum DocTranspiler {

    private static let openMark: Character = "\u{E000}"
    private static let closeMark: Character = "\u{E001}"
    private static let breakMark: Character = "\u{E002}"

    private static let constructs: [String: Chunk.Kind] = [
        "math": .inlineMath, "m": .inlineMath,
        "display": .display, "displaymath": .display, "block": .display,
        "equation": .equation, "eq": .equation,
        "align": .align, "aligned": .align, "gather": .align,
        "latex": .rawLatex, "tex": .rawLatex,
        "code": .code, "verb": .code, "mono": .code,
    ]

    private static let environments: [String: String] = [
        "theorem": "Theorem", "lemma": "Lemma", "corollary": "Corollary",
        "definition": "Definition", "proposition": "Proposition",
        "proof": "Proof", "remark": "Remark", "example": "Example",
        "note": "Note", "claim": "Claim",
    ]

    // MARK: entry

    static func render(_ src: String) -> Rendered {
        var chunks: [Chunk] = []
        let skeleton = lift(src, into: &chunks)
        var out = Rendered()
        out.mathCount = chunks.count
        blocks(skeleton, chunks: chunks, into: &out)
        return out
    }

    // MARK: phase 1 - lift constructs

    private static func lift(_ src: String, into chunks: inout [Chunk]) -> String {
        let c = Array(src)
        var out = ""
        out.reserveCapacity(src.count)
        var i = 0
        while i < c.count {
            let ch = c[i]
            // backslash disables the construct that follows it
            if ch == "\\", i + 1 < c.count {
                let rest = String(c[(i + 1)...])
                if let name = constructName(rest) {
                    out += name + "("
                    i += 1 + name.count + 1
                    continue
                }
                out.append("\\")
                out.append(c[i + 1])
                i += 2
                continue
            }
            // Literal spans are copied through untouched: a construct written inside
            // backticks is documentation, not a construct.
            if ch == "`" {
                let fence = i + 2 < c.count && c[i + 1] == "`" && c[i + 2] == "`"
                let marker = fence ? "```" : "`"
                let markerCount = marker.count
                var j = i + markerCount
                var found = -1
                while j + markerCount <= c.count {
                    if String(c[j..<(j + markerCount)]) == marker { found = j; break }
                    if !fence, c[j] == "\n" { break }
                    j += 1
                }
                if found >= 0 {
                    out += String(c[i..<(found + markerCount)])
                    i = found + markerCount
                    continue
                }
            }
            if ch == "$" {
                let isDouble = i + 1 < c.count && c[i + 1] == "$"
                let delim = isDouble ? "$$" : "$"
                if let end = find(c, from: i + delim.count, delim: delim) {
                    let body = String(c[(i + delim.count)..<end])
                    chunks.append(Chunk(kind: isDouble ? .display : .inlineMath, body: body))
                    out += token(chunks.count - 1)
                    i = end + delim.count
                    continue
                }
            }
            if ch.isLetter {
                var j = i
                while j < c.count, c[j].isLetter { j += 1 }
                let name = String(c[i..<j]).lowercased()
                if let kind = constructs[name], j < c.count, c[j] == "(" {
                    let (body, next) = balanced(c, j)
                    chunks.append(Chunk(kind: kind, body: body))
                    out += token(chunks.count - 1)
                    i = next
                    continue
                }
                out += String(c[i..<j])
                i = j
                continue
            }
            out.append(ch)
            i += 1
        }
        return out
    }

    private static func constructName(_ rest: String) -> String? {
        var name = ""
        for ch in rest {
            if ch.isLetter { name.append(ch); if name.count > 12 { return nil }; continue }
            if ch == "(", constructs[name.lowercased()] != nil { return name }
            return nil
        }
        return nil
    }

    private static func token(_ n: Int) -> String { "\(openMark)\(n)\(closeMark)" }

    private static func find(_ c: [Character], from: Int, delim: String) -> Int? {
        let d = Array(delim)
        var i = from
        while i + d.count <= c.count {
            if c[i] == "\n", i + 1 < c.count, c[i + 1] == "\n" { return nil }
            if Array(c[i..<(i + d.count)]) == d { return i }
            i += 1
        }
        return nil
    }

    private static func balanced(_ c: [Character], _ start: Int) -> (String, Int) {
        var depth = 0
        var i = start
        var body = ""
        while i < c.count {
            if c[i] == "\\", i + 1 < c.count, c[i + 1] == "(" || c[i + 1] == ")" {
                body.append(c[i + 1])
                i += 2
                continue
            }
            if c[i] == "(" {
                depth += 1
                if depth == 1 { i += 1; continue }
            } else if c[i] == ")" {
                depth -= 1
                if depth == 0 { return (body, i + 1) }
            }
            body.append(c[i])
            i += 1
        }
        return (body, i)
    }

    // MARK: phase 2 - blocks

    private static func blocks(_ skeleton: String, chunks: [Chunk], into out: inout Rendered) {
        var meta: [String: String] = [:]
        var html = ""
        var tex = ""
        var listStack: [(kind: String, indent: Int)] = []
        var inCode = false
        var codeBuf: [String] = []
        var para: [String] = []
        var paraLine = 0
        var metaPhase = true
        var tableBuf: [String] = []
        var tableLine = 0

        let lines = skeleton.components(separatedBy: "\n")

        func closeLists(to level: Int) {
            while listStack.count > level {
                let top = listStack.removeLast()
                html += top.kind == "ul" ? "</ul>\n" : "</ol>\n"
                tex += top.kind == "ul" ? "\\end{itemize}\n" : "\\end{enumerate}\n"
            }
        }

        func flushPara() {
            guard !para.isEmpty else { return }
            var text = para.joined(separator: " ")
            while text.last == breakMark { text.removeLast() }
            para.removeAll()
            var body = text
            var env: String?
            for (key, label) in environments {
                let prefix = key + ":"
                if body.lowercased().hasPrefix(prefix) {
                    env = key
                    body = String(body.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    _ = label
                    break
                }
            }
            let r = inline(body, chunks: chunks)
            out.wordCount += text.split(separator: " ").count
            if env == nil, displayOnly(body, chunks: chunks) {
                // A line that is nothing but display math is its own block, never
                // wrapped in a paragraph: the exporter breaks pages on blocks.
                html += r.html + "\n"
                tex += r.tex + "\n"
                return
            }
            if let env {
                html += "<div class=\"env \(env)\" data-l=\"\(paraLine)\"><span class=\"envname\">\(environments[env] ?? env).</span> \(r.html)</div>\n"
                tex += "\\begin{\(env)}\n\(r.tex)\n\\end{\(env)}\n\n"
            } else {
                html += "<p data-l=\"\(paraLine)\">\(r.html)</p>\n"
                tex += r.tex + "\n\n"
            }
        }

        func flushTable() {
            guard !tableBuf.isEmpty else { return }
            let rows = tableBuf.map { row -> [String] in
                var cells = row.trimmingCharacters(in: .whitespaces)
                if cells.hasPrefix("|") { cells.removeFirst() }
                if cells.hasSuffix("|") { cells.removeLast() }
                return cells.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            tableBuf.removeAll()
            guard let first = rows.first else { return }
            let cols = first.count
            var headerRows = 1
            var bodyRows = rows
            let isSep: ([String]) -> Bool = { $0.allSatisfy { $0.allSatisfy { c in c == "-" || c == ":" || c == " " } && !$0.isEmpty } }
            if rows.count > 1, isSep(rows[1]) {
                bodyRows = [rows[0]] + rows[2...]
            } else {
                headerRows = 0
            }
            html += "<div class=\"tablewrap\" data-l=\"\(tableLine)\"><table>\n"
            tex += "\\begin{center}\\begin{tabular}{" + String(repeating: "l", count: cols) + "}\n\\hline\n"
            for (idx, row) in bodyRows.enumerated() {
                let rendered = row.map { inline($0, chunks: chunks) }
                let tag = (headerRows == 1 && idx == 0) ? "th" : "td"
                html += "<tr>" + rendered.map { "<\(tag)>\($0.html)</\(tag)>" }.joined() + "</tr>\n"
                tex += rendered.map { headerRows == 1 && idx == 0 ? "\\textbf{\($0.tex)}" : $0.tex }.joined(separator: " & ") + " \\\\\n"
                if headerRows == 1 && idx == 0 { tex += "\\hline\n" }
            }
            html += "</table></div>\n"
            tex += "\\hline\n\\end{tabular}\\end{center}\n\n"
        }

        for (n, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCode {
                    let body = codeBuf.joined(separator: "\n")
                    html += "<pre data-l=\"\(n)\"><code>\(escapeHTML(body))</code></pre>\n"
                    tex += "\\begin{verbatim}\n\(body)\n\\end{verbatim}\n\n"
                    codeBuf.removeAll()
                    inCode = false
                } else {
                    flushPara(); flushTable(); closeLists(to: 0)
                    inCode = true
                }
                continue
            }
            if inCode { codeBuf.append(rawLine); continue }

            if line.hasPrefix("|"), line.count > 1 {
                flushPara(); closeLists(to: 0)
                if tableBuf.isEmpty { tableLine = n }
                tableBuf.append(line)
                continue
            }
            flushTable()

            if line.isEmpty {
                flushPara()
                closeLists(to: 0)
                continue
            }

            if metaPhase, let colon = line.firstIndex(of: ":"), !line.hasPrefix("#") {
                let key = String(line[line.startIndex..<colon]).lowercased()
                if ["title", "author", "date", "abstract", "keywords"].contains(key) {
                    meta[key] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    continue
                }
            }
            metaPhase = false

            if line.hasPrefix("#") {
                flushPara(); closeLists(to: 0)
                var level = 0
                var rest = Substring(line)
                while rest.hasPrefix("#") { level += 1; rest = rest.dropFirst() }
                let r = inline(rest.trimmingCharacters(in: .whitespaces), chunks: chunks)
                let tags = ["h1", "h2", "h3", "h4", "h5"]
                let cmds = ["section", "subsection", "subsubsection", "paragraph", "subparagraph"]
                let li = min(max(level - 1, 0), 4)
                html += "<\(tags[li]) data-l=\"\(n)\">\(r.html)</\(tags[li])>\n"
                tex += "\\\(cmds[li]){\(r.tex)}\n\n"
                continue
            }

            if line == "---" || line == "***" {
                flushPara(); closeLists(to: 0)
                html += "<hr data-l=\"\(n)\">\n"
                tex += "\\par\\noindent\\hrulefill\\par\n\n"
                continue
            }

            if line.hasPrefix("> ") {
                flushPara(); closeLists(to: 0)
                let r = inline(String(line.dropFirst(2)), chunks: chunks)
                html += "<blockquote data-l=\"\(n)\">\(r.html)</blockquote>\n"
                tex += "\\begin{quote}\n\(r.tex)\n\\end{quote}\n\n"
                continue
            }

            let indent = rawLine.prefix { $0 == " " }.count / 2
            if let (marker, content) = listItem(line) {
                flushPara()
                let kind = marker == "ul" ? "ul" : "ol"
                if listStack.count > indent + 1 { closeLists(to: indent + 1) }
                if listStack.count == indent + 1, listStack[indent].kind != kind {
                    closeLists(to: indent)
                }
                while listStack.count < indent + 1 {
                    html += kind == "ul" ? "<ul>\n" : "<ol>\n"
                    tex += kind == "ul" ? "\\begin{itemize}\n" : "\\begin{enumerate}\n"
                    listStack.append((kind, indent))
                }
                let r = inline(content, chunks: chunks)
                out.wordCount += content.split(separator: " ").count
                html += "<li data-l=\"\(n)\">\(r.html)</li>\n"
                tex += "\\item \(r.tex)\n"
                continue
            }
            closeLists(to: 0)

            if para.isEmpty { paraLine = n }
            // A trailing backslash, or two trailing spaces, forces a line break;
            // an ordinary newline keeps flowing in the same paragraph.
            if line.hasSuffix("\\") {
                para.append(String(line.dropLast()) + String(breakMark))
            } else if rawLine.hasSuffix("  ") {
                para.append(line + String(breakMark))
            } else {
                para.append(line)
            }
        }
        flushPara()
        flushTable()
        closeLists(to: 0)
        if inCode, !codeBuf.isEmpty {
            html += "<pre><code>\(escapeHTML(codeBuf.joined(separator: "\n")))</code></pre>\n"
        }

        out.title = meta["title"] ?? ""
        var head = ""
        var texHead = ""
        if let t = meta["title"], !t.isEmpty {
            let r = inline(t, chunks: chunks)
            head += "<header class=\"docmeta\"><h1 class=\"doctitle\">\(r.html)</h1>"
            texHead += "\\title{\(r.tex)}\n"
            if let a = meta["author"], !a.isEmpty {
                let ra = inline(a, chunks: chunks)
                head += "<div class=\"docauthor\">\(ra.html)</div>"
                texHead += "\\author{\(ra.tex)}\n"
            } else {
                texHead += "\\author{}\n"
            }
            let dateText = meta["date"] ?? ""
            if !dateText.isEmpty {
                let rd = inline(dateText, chunks: chunks)
                head += "<div class=\"docdate\">\(rd.html)</div>"
                texHead += "\\date{\(rd.tex)}\n"
            } else {
                texHead += "\\date{}\n"
            }
            head += "</header>\n"
        }
        if let ab = meta["abstract"], !ab.isEmpty {
            let r = inline(ab, chunks: chunks)
            head += "<div class=\"abstract\"><div class=\"abstitle\">Abstract</div>\(r.html)</div>\n"
        }

        out.html = head + html
        out.latex = preamble(texHead) + (meta["title"] != nil ? "\\maketitle\n" : "")
            + (meta["abstract"].map { "\\begin{abstract}\n\(inline($0, chunks: chunks).tex)\n\\end{abstract}\n\n" } ?? "")
            + tex + "\\end{document}\n"
    }

    /// True when the line holds only display-level math placeholders.
    private static func displayOnly(_ body: String, chunks: [Chunk]) -> Bool {
        var sawDisplay = false
        var i = body.startIndex
        while i < body.endIndex {
            let ch = body[i]
            if ch == openMark {
                var num = ""
                i = body.index(after: i)
                while i < body.endIndex, body[i] != closeMark {
                    num.append(body[i])
                    i = body.index(after: i)
                }
                if i < body.endIndex { i = body.index(after: i) }
                guard let n = Int(num), n < chunks.count else { return false }
                switch chunks[n].kind {
                case .display, .equation, .align: sawDisplay = true
                default: return false
                }
                continue
            }
            if !ch.isWhitespace { return false }
            i = body.index(after: i)
        }
        return sawDisplay
    }

    private static func listItem(_ line: String) -> (String, String)? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return ("ul", String(line.dropFirst(2)))
        }
        var digits = ""
        var rest = Substring(line)
        while let f = rest.first, f.isNumber { digits.append(f); rest = rest.dropFirst() }
        if !digits.isEmpty, rest.hasPrefix(". ") || rest.hasPrefix(") ") {
            return ("ol", String(rest.dropFirst(2)))
        }
        return nil
    }

    // MARK: inline

    private static func inline(_ s: String, chunks: [Chunk]) -> (html: String, tex: String) {
        var html = ""
        var tex = ""
        let c = Array(s)
        var i = 0
        var bold = false, ital = false
        while i < c.count {
            let ch = c[i]
            if ch == openMark {
                var j = i + 1
                var num = ""
                while j < c.count, c[j] != closeMark { num.append(c[j]); j += 1 }
                if let n = Int(num), n < chunks.count {
                    let e = emit(chunks[n])
                    html += e.html
                    tex += e.tex
                }
                i = j + 1
                continue
            }
            if ch == breakMark {
                html += "<br>"
                tex += " \\\\\n"
                i += 1
                continue
            }
            if ch == "\\", i + 1 < c.count {
                html += escapeHTML(String(c[i + 1]))
                tex += Tex.escape(String(c[i + 1]))
                i += 2
                continue
            }
            if ch == "`" {
                var j = i + 1
                var body = ""
                while j < c.count, c[j] != "`" { body.append(c[j]); j += 1 }
                html += "<code>\(escapeHTML(body))</code>"
                tex += "\\texttt{\(Tex.escape(body))}"
                i = j + 1
                continue
            }
            if ch == "[", let close = c[i...].firstIndex(of: "]"), close + 1 < c.count, c[close + 1] == "(" {
                var j = close + 2
                var url = ""
                while j < c.count, c[j] != ")" { url.append(c[j]); j += 1 }
                let label = String(c[(i + 1)..<close])
                let inner = inline(label, chunks: chunks)
                html += "<a href=\"\(escapeHTML(url))\">\(inner.html)</a>"
                tex += "\\href{\(url)}{\(inner.tex)}"
                i = j + 1
                continue
            }
            if ch == "*" {
                if i + 1 < c.count, c[i + 1] == "*" {
                    html += bold ? "</strong>" : "<strong>"
                    tex += bold ? "}" : "\\textbf{"
                    bold.toggle()
                    i += 2
                    continue
                }
                html += ital ? "</em>" : "<em>"
                tex += ital ? "}" : "\\emph{"
                ital.toggle()
                i += 1
                continue
            }
            html += escapeHTML(String(ch))
            tex += Tex.escape(String(ch))
            i += 1
        }
        if bold { html += "</strong>"; tex += "}" }
        if ital { html += "</em>"; tex += "}" }
        return (html, tex)
    }

    private static func emit(_ chunk: Chunk) -> (html: String, tex: String) {
        switch chunk.kind {
        case .inlineMath:
            let m = MathParser.latex(chunk.body)
            return ("<span class=\"km\">\(escapeHTML(m))</span>", "$\(m)$")
        case .display:
            let m = MathParser.latex(chunk.body)
            return ("<div class=\"km kd\">\(escapeHTML(m))</div>", "\\[\n\(m)\n\\]\n")
        case .equation:
            let m = MathParser.latex(chunk.body)
            return ("<div class=\"km kd numbered\">\(escapeHTML(m))</div>",
                    "\\begin{equation}\n\(m)\n\\end{equation}\n")
        case .align:
            let rows = chunk.body.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { row -> String in
                    let m = MathParser.latex(row)
                    return m.contains("&") ? m : alignAtRelation(m)
                }
            let body = rows.joined(separator: " \\\\\n")
            return ("<div class=\"km kd\">\(escapeHTML("\\begin{aligned}\n\(body)\n\\end{aligned}"))</div>",
                    "\\begin{align*}\n\(body)\n\\end{align*}\n")
        case .rawLatex:
            return ("<span class=\"km\">\(escapeHTML(chunk.body))</span>", chunk.body)
        case .code:
            return ("<code>\(escapeHTML(chunk.body))</code>", "\\texttt{\(Tex.escape(chunk.body))}")
        }
    }

    /// `x = y` -> `x &= y` so align rows line up on the relation. The relation has
    /// to be found at brace depth zero: the `=` in `\sum_{k = 1}` is not the one.
    private static func alignAtRelation(_ s: String) -> String {
        let chars = Array(s)
        let commands = ["\\le", "\\ge", "\\ne", "\\approx", "\\equiv", "\\to",
                        "\\subseteq", "\\subset", "\\in", "\\implies", "\\iff"]
        var depth = 0
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\\" {
                if depth == 0 {
                    for cmd in commands {
                        let n = cmd.count
                        if i + n <= chars.count, String(chars[i..<(i + n)]) == cmd {
                            return String(chars[0..<i]) + "&" + String(chars[i...])
                        }
                    }
                }
                i += 2
                continue
            }
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1 }
            if c == "=", depth == 0 {
                return String(chars[0..<i]) + "&" + String(chars[i...])
            }
            i += 1
        }
        return s
    }

    static func escapeHTML(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    private static func preamble(_ meta: String) -> String {
        """
        % Generated by BetterLaTeX
        \\documentclass[11pt]{article}
        \\usepackage[margin=1in]{geometry}
        \\usepackage[T1]{fontenc}
        \\usepackage{lmodern}
        \\usepackage{amsmath,amssymb,amsthm,mathtools}
        \\usepackage{graphicx}
        \\usepackage[hidelinks]{hyperref}
        \\theoremstyle{plain}
        \\newtheorem{theorem}{Theorem}
        \\newtheorem{lemma}[theorem]{Lemma}
        \\newtheorem{corollary}[theorem]{Corollary}
        \\newtheorem{proposition}[theorem]{Proposition}
        \\newtheorem{claim}[theorem]{Claim}
        \\theoremstyle{definition}
        \\newtheorem{definition}[theorem]{Definition}
        \\newtheorem{example}[theorem]{Example}
        \\theoremstyle{remark}
        \\newtheorem*{remark}{Remark}
        \\newtheorem*{note}{Note}
        \(meta)\\begin{document}

        """
    }
}
