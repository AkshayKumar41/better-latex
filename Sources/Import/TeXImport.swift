// LaTeX source -> BetterLaTeX English. The inverse of the transpiler, and the
// vocabulary is inverted from the same tables the transpiler uses, so the two
// stay in step. Anything unrecognised is passed through as raw LaTeX, which the
// editor also accepts - an import is never allowed to lose content silently.
import Foundation

enum TeXImport {

    // MARK: vocabulary

    /// `\le` -> `<=`, built by reversing the editor's own word tables.
    static let commandWords: [String: String] = {
        var map: [String: String] = [:]
        func add(_ english: String, _ latex: String) {
            guard latex.hasPrefix("\\") else { return }
            let command = String(latex.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
            guard !command.isEmpty, command.allSatisfy({ $0.isLetter }) else { return }
            // prefer the shortest spelling, so `in` wins over `is an element of`
            if let existing = map[command], existing.count <= english.count { return }
            map[command] = english
        }
        for (english, latex) in Sym.words where !latex.hasPrefix("@") { add(english, latex) }
        for (english, latex) in Sym.phrases where !latex.hasPrefix("@") { add(english, latex) }
        for name in Sym.greekLower.union(Sym.greekUpper) { map[name] = name }
        for name in Sym.functions { map[name] = name }
        // structural or ambiguous ones the tables cannot express
        map["ge"] = ">="
        map["le"] = "<="
        map["ne"] = "!="
        map["cdot"] = "cdot"
        map["times"] = "times"
        map["cdots"] = "cdots"
        map["ldots"] = "dots"
        map["dots"] = "dots"
        map["infty"] = "infinity"
        map["neq"] = "!="
        map["leq"] = "<="
        map["geq"] = ">="
        map["to"] = "->"
        map["rightarrow"] = "->"
        map["Rightarrow"] = "=>"
        map["Leftrightarrow"] = "<=>"
        map["iff"] = "iff"
        map["implies"] = "implies"
        map["mid"] = "mid"
        map["colon"] = ":"
        map["quad"] = "quad"
        map["qquad"] = "qquad"
        map["bmod"] = "mod"
        map["pmod"] = "mod"
        map["varnothing"] = "empty set"
        map["emptyset"] = "empty set"
        map["mathbb"] = "@blackboard"
        return map
    }()

    private static let blackboard: [String: String] = [
        "R": "reals", "N": "naturals", "Z": "integers",
        "Q": "rationals", "C": "complexes", "P": "primes",
    ]

    private static let accents: [String: String] = [
        "vec": "vec", "hat": "hat", "bar": "bar", "tilde": "tilde",
        "overline": "overline", "underline": "underline", "mathbf": "bold",
        "mathcal": "script", "mathfrak": "frak", "boldsymbol": "bold",
        "boxed": "boxed", "cancel": "cancel", "overbrace": "overbrace",
        "underbrace": "underbrace", "mathrm": "text", "operatorname": "text",
    ]

    private static let bigOperators: [String: String] = [
        "sum": "sum", "prod": "product", "int": "integral", "iint": "double integral",
        "iiint": "triple integral", "oint": "contour integral", "bigcup": "big union",
        "bigcap": "big intersection", "lim": "limit", "max": "max", "min": "min",
        "sup": "sup", "inf": "inf", "coprod": "coproduct", "limsup": "limsup",
        "liminf": "liminf", "argmax": "argmax", "argmin": "argmin",
    ]

    private static let sectionCommands: [String: String] = [
        "section": "#", "subsection": "##", "subsubsection": "###",
        "paragraph": "####", "subparagraph": "#####",
        "section*": "#", "subsection*": "##", "subsubsection*": "###",
    ]

    private static let theoremEnvironments: Set<String> = [
        "theorem", "lemma", "corollary", "proposition", "claim",
        "definition", "example", "proof", "remark", "note",
    ]

    /// Commands that only affect layout, and carry nothing to convert.
    private static let droppedCommands: Set<String> = [
        "maketitle", "noindent", "indent", "centering", "newpage", "clearpage",
        "pagebreak", "bigskip", "medskip", "smallskip", "tableofcontents",
        "hline", "toprule", "midrule", "bottomrule", "hfill", "vfill", "par",
        "raggedright", "raggedleft", "normalsize", "small", "large", "Large",
        "footnotesize", "scriptsize", "displaystyle", "textstyle", "protect",
    ]

    struct Result {
        var source = ""
        var notes: [String] = []
        var mathRuns = 0
    }

    // MARK: document

    static func convert(_ tex: String) -> Result {
        var result = Result()
        var meta: [String: String] = [:]

        var body = tex
        if let range = body.range(of: "\\begin{document}") {
            let preamble = String(body[body.startIndex..<range.lowerBound])
            for key in ["title", "author", "date"] {
                if let value = argument(of: "\\\(key)", in: preamble) {
                    meta[key] = inlineEnglish(value, result: &result)
                }
            }
            body = String(body[range.upperBound...])
        }
        if let range = body.range(of: "\\end{document}") {
            body = String(body[body.startIndex..<range.lowerBound])
        }

        body = liftDisplayMath(body, result: &result)

        var out: [String] = []
        if let title = meta["title"] { out.append("title: \(title)") }
        if let author = meta["author"], !author.isEmpty { out.append("author: \(author)") }
        if let date = meta["date"], !date.isEmpty { out.append("date: \(date)") }
        if !out.isEmpty { out.append("") }

        out.append(contentsOf: blocks(in: body, result: &result))
        result.source = out.joined(separator: "\n").replacingOccurrences(of: "\n\n\n", with: "\n\n") + "\n"
        return result
    }

    /// Rewrites multi-line display mathematics as one line each, before the body
    /// is split into lines: `\[ ... \]` and the equation environments routinely
    /// span several source lines.
    private static func liftDisplayMath(_ body: String, result: inout Result) -> String {
        var text = body
        let environments = ["equation*", "equation", "align*", "align", "gather*",
                            "gather", "displaymath", "multline*", "multline"]
        for environment in environments {
            let open = "\\begin{\(environment)}"
            let close = "\\end{\(environment)}"
            while let start = text.range(of: open), let end = text.range(of: close, range: start.upperBound..<text.endIndex) {
                let inner = String(text[start.upperBound..<end.lowerBound])
                result.mathRuns += 1
                let keyword = environment.hasPrefix("align") || environment.hasPrefix("gather")
                    ? "align" : (environment.hasSuffix("*") || environment == "displaymath" ? "display" : "equation")
                let converted: String
                if keyword == "align" {
                    let rows = inner.components(separatedBy: "\\\\")
                        .map { mathEnglish($0.replacingOccurrences(of: "&", with: "")) }
                        .filter { !$0.isEmpty }
                    converted = "align(\n" + rows.joined(separator: "\n") + "\n)"
                } else {
                    converted = "\(keyword)(" + mathEnglish(inner) + ")"
                }
                text.replaceSubrange(start.lowerBound..<end.upperBound, with: "\n\n" + converted + "\n\n")
            }
        }
        for (open, close) in [("\\[", "\\]"), ("$$", "$$")] {
            while let start = text.range(of: open), let end = text.range(of: close, range: start.upperBound..<text.endIndex) {
                let inner = String(text[start.upperBound..<end.lowerBound])
                result.mathRuns += 1
                text.replaceSubrange(start.lowerBound..<end.upperBound,
                                     with: "\n\ndisplay(" + mathEnglish(inner) + ")\n\n")
            }
        }
        return text
    }

    /// Splits the body into blocks and converts each one.
    private static func blocks(in body: String, result: inout Result) -> [String] {
        var out: [String] = []
        var paragraph: [String] = []
        var listDepth = 0
        var pendingPrefix: String?
        var enumerateCounters: [Int] = []
        var verbatim: [String]?

        func flush() {
            let text = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            paragraph = []
            guard !text.isEmpty else { return }
            if let prefix = pendingPrefix {
                out.append("\(prefix) \(text)")
                pendingPrefix = nil
            } else {
                out.append(text)
            }
            out.append("")
        }

        for rawLine in body.components(separatedBy: .newlines) {
            var line = rawLine

            if var buffer = verbatim {
                if line.contains("\\end{verbatim}") || line.contains("\\end{lstlisting}") {
                    out.append("```")
                    out.append(contentsOf: buffer)
                    out.append("```")
                    out.append("")
                    verbatim = nil
                } else {
                    buffer.append(line)
                    verbatim = buffer
                }
                continue
            }

            // comments, but not an escaped percent
            if let hash = commentIndex(line) {
                line = String(line[line.startIndex..<hash])
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flush()
                continue
            }
            if trimmed.hasPrefix("\\begin{verbatim}") || trimmed.hasPrefix("\\begin{lstlisting}") {
                flush()
                verbatim = []
                continue
            }

            // environments that map onto document structure
            if let name = environmentName(trimmed, opening: true) {
                flush()
                switch name {
                case "itemize", "description":
                    listDepth += 1
                case "enumerate":
                    listDepth += 1
                    enumerateCounters.append(0)
                case "quote", "quotation":
                    pendingPrefix = ">"
                case "abstract":
                    pendingPrefix = "abstract:"
                case "center", "flushleft", "flushright", "figure", "table":
                    break
                case "equation", "equation*", "align", "align*", "gather", "gather*", "displaymath", "multline":
                    continue
                default:
                    if theoremEnvironments.contains(name) { pendingPrefix = "\(name):" }
                }
                continue
            }
            if let name = environmentName(trimmed, opening: false) {
                flush()
                if name == "itemize" || name == "description" { listDepth = max(0, listDepth - 1) }
                if name == "enumerate" {
                    listDepth = max(0, listDepth - 1)
                    if !enumerateCounters.isEmpty { enumerateCounters.removeLast() }
                }
                continue
            }

            if trimmed.hasPrefix("\\item") {
                flush()
                let content = trimmed.replacingOccurrences(of: "\\item", with: "").trimmingCharacters(in: .whitespaces)
                let indent = String(repeating: "  ", count: max(listDepth - 1, 0))
                if !enumerateCounters.isEmpty {
                    enumerateCounters[enumerateCounters.count - 1] += 1
                    out.append("\(indent)\(enumerateCounters[enumerateCounters.count - 1]). \(inlineEnglish(content, result: &result))")
                } else {
                    out.append("\(indent)- \(inlineEnglish(content, result: &result))")
                }
                continue
            }

            if let (level, title) = section(trimmed, result: &result) {
                flush()
                out.append("\(level) \(title)")
                out.append("")
                continue
            }

            paragraph.append(inlineEnglish(trimmed, result: &result))
        }
        flush()
        return out
    }

    private static func commentIndex(_ line: String) -> String.Index? {
        var previous: Character?
        for index in line.indices {
            if line[index] == "%", previous != "\\" { return index }
            previous = line[index]
        }
        return nil
    }

    private static func environmentName(_ line: String, opening: Bool) -> String? {
        let marker = opening ? "\\begin{" : "\\end{"
        guard line.hasPrefix(marker), let close = line.firstIndex(of: "}") else { return nil }
        return String(line[line.index(line.startIndex, offsetBy: marker.count)..<close])
    }

    private static func section(_ line: String, result: inout Result) -> (String, String)? {
        for (command, marker) in sectionCommands {
            let prefix = "\\\(command){"
            guard line.hasPrefix(prefix) else { continue }
            let inner = balanced(line, from: line.index(line.startIndex, offsetBy: prefix.count - 1))
            return (marker, inlineEnglish(inner.body, result: &result))
        }
        return nil
    }

    private static func argument(of command: String, in text: String) -> String? {
        guard let range = text.range(of: command + "{") else { return nil }
        let start = text.index(before: range.upperBound)
        return balanced(text, from: start).body
    }

    /// The contents of the `{...}` starting at `index`, plus where it ended.
    private static func balanced(_ text: String, from index: String.Index) -> (body: String, end: String.Index) {
        var depth = 0
        var body = ""
        var i = index
        while i < text.endIndex {
            let ch = text[i]
            if ch == "\\", text.index(after: i) < text.endIndex {
                let next = text.index(after: i)
                if depth > 0 { body.append(ch); body.append(text[next]) }
                i = text.index(after: next)
                continue
            }
            if ch == "{" {
                depth += 1
                i = text.index(after: i)
                if depth == 1 { continue }
            } else if ch == "}" {
                depth -= 1
                i = text.index(after: i)
                if depth == 0 { return (body, i) }
                body.append(ch)
                continue
            } else {
                i = text.index(after: i)
            }
            if depth >= 1, ch != "{" { body.append(ch) }
            else if depth > 1 { body.append(ch) }
        }
        return (body, i)
    }

    // MARK: inline text

    /// Prose with inline commands and mathematics converted.
    static func inlineEnglish(_ text: String, result: inout Result) -> String {
        var out = ""
        let chars = Array(text)
        var i = 0

        func balancedArgument(_ start: Int) -> (String, Int)? {
            guard start < chars.count, chars[start] == "{" else { return nil }
            var depth = 0
            var body = ""
            var j = start
            while j < chars.count {
                if chars[j] == "\\", j + 1 < chars.count {
                    body.append(chars[j])
                    body.append(chars[j + 1])
                    j += 2
                    continue
                }
                if chars[j] == "{" {
                    depth += 1
                    j += 1
                    if depth == 1 { continue }
                } else if chars[j] == "}" {
                    depth -= 1
                    j += 1
                    if depth == 0 { return (body, j) }
                    body.append("}")
                    continue
                } else {
                    body.append(chars[j])
                    j += 1
                    continue
                }
                body.append("{")
            }
            return (body, j)
        }

        while i < chars.count {
            let ch = chars[i]

            // display mathematics
            if ch == "\\", i + 1 < chars.count, chars[i + 1] == "[" {
                if let end = find(chars, from: i + 2, marker: ["\\", "]"]) {
                    let math = String(chars[(i + 2)..<end])
                    result.mathRuns += 1
                    out += "display(" + mathEnglish(math) + ")"
                    i = end + 2
                    continue
                }
            }
            if ch == "\\", i + 1 < chars.count, chars[i + 1] == "(" {
                if let end = find(chars, from: i + 2, marker: ["\\", ")"]) {
                    let math = String(chars[(i + 2)..<end])
                    result.mathRuns += 1
                    out += "math(" + mathEnglish(math) + ")"
                    i = end + 2
                    continue
                }
            }
            if ch == "$" {
                let display = i + 1 < chars.count && chars[i + 1] == "$"
                let marker: [Character] = display ? ["$", "$"] : ["$"]
                if let end = find(chars, from: i + marker.count, marker: marker) {
                    let math = String(chars[(i + marker.count)..<end])
                    result.mathRuns += 1
                    out += (display ? "display(" : "math(") + mathEnglish(math) + ")"
                    i = end + marker.count
                    continue
                }
            }

            if ch == "\\", i + 1 < chars.count {
                // a line break becomes the editor's own line break
                if chars[i + 1] == "\\" {
                    out += "\\"
                    i += 2
                    continue
                }
                if !chars[i + 1].isLetter {
                    // an escaped character stays escaped
                    out += "\\" + String(chars[i + 1])
                    i += 2
                    continue
                }
                var j = i + 1
                var name = ""
                while j < chars.count, chars[j].isLetter { name.append(chars[j]); j += 1 }
                switch name {
                case "textbf", "bf", "strong":
                    if let (body, next) = balancedArgument(j) {
                        out += "**" + inlineEnglish(body, result: &result) + "**"
                        i = next
                        continue
                    }
                case "emph", "textit", "it":
                    if let (body, next) = balancedArgument(j) {
                        out += "*" + inlineEnglish(body, result: &result) + "*"
                        i = next
                        continue
                    }
                case "texttt", "verb":
                    if let (body, next) = balancedArgument(j) {
                        out += "`" + body + "`"
                        i = next
                        continue
                    }
                case "href":
                    if let (url, afterURL) = balancedArgument(j), let (label, next) = balancedArgument(afterURL) {
                        out += "[" + inlineEnglish(label, result: &result) + "](" + url + ")"
                        i = next
                        continue
                    }
                case "url":
                    if let (url, next) = balancedArgument(j) {
                        out += "[" + url + "](" + url + ")"
                        i = next
                        continue
                    }
                case "label", "index":
                    if let (_, next) = balancedArgument(j) {
                        i = next
                        continue
                    }
                case "LaTeX", "TeX":
                    out += name == "TeX" ? "TeX" : "LaTeX"
                    i = j
                    continue
                case "item":
                    i = j
                    continue
                case _ where droppedCommands.contains(name):
                    i = j
                    continue
                default:
                    break
                }
                // anything else keeps its LaTeX spelling, which still renders
                out += "\\" + name
                i = j
                continue
            }

            out.append(ch)
            i += 1
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    private static func find(_ chars: [Character], from: Int, marker: [Character]) -> Int? {
        var i = from
        while i + marker.count <= chars.count {
            if Array(chars[i..<(i + marker.count)]) == marker { return i }
            i += 1
        }
        return nil
    }

    // MARK: mathematics

    /// LaTeX maths -> the English the editor accepts.
    static func mathEnglish(_ tex: String) -> String {
        var out: [String] = []
        let chars = Array(tex)
        var i = 0

        func group(_ start: Int) -> (String, Int)? {
            guard start < chars.count else { return nil }
            if chars[start] == "{" {
                var depth = 0
                var body = ""
                var j = start
                while j < chars.count {
                    if chars[j] == "{" {
                        depth += 1
                        j += 1
                        if depth == 1 { continue }
                        body.append("{")
                        continue
                    }
                    if chars[j] == "}" {
                        depth -= 1
                        j += 1
                        if depth == 0 { return (body, j) }
                        body.append("}")
                        continue
                    }
                    body.append(chars[j])
                    j += 1
                }
                return (body, j)
            }
            if chars[start] == "\\" {
                var j = start + 1
                var name = "\\"
                while j < chars.count, chars[j].isLetter { name.append(chars[j]); j += 1 }
                return (name, j)
            }
            return (String(chars[start]), start + 1)
        }

        func wrap(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.count <= 1 { return trimmed }
            if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") { return trimmed }
            return "(" + trimmed + ")"
        }

        while i < chars.count {
            let ch = chars[i]

            if ch == "\\", i + 1 < chars.count {
                if !chars[i + 1].isLetter {
                    // \{ \} \, \; and friends
                    let next = chars[i + 1]
                    if next == "," || next == ";" || next == ":" || next == "!" {
                        i += 2
                        continue
                    }
                    out.append("\\" + String(next))
                    i += 2
                    continue
                }
                var j = i + 1
                var name = ""
                while j < chars.count, chars[j].isLetter { name.append(chars[j]); j += 1 }

                if name == "frac" || name == "dfrac" || name == "tfrac" {
                    if let (top, afterTop) = group(j), let (bottom, next) = group(afterTop) {
                        out.append(wrap(mathEnglish(top)) + "/" + wrap(mathEnglish(bottom)))
                        i = next
                        continue
                    }
                }
                if name == "binom" || name == "dbinom" || name == "choose" {
                    if let (top, afterTop) = group(j), let (bottom, next) = group(afterTop) {
                        out.append("binom(" + mathEnglish(top) + ", " + mathEnglish(bottom) + ")")
                        i = next
                        continue
                    }
                }
                if name == "sqrt" {
                    var degree: String?
                    var k = j
                    if k < chars.count, chars[k] == "[" {
                        var body = ""
                        k += 1
                        while k < chars.count, chars[k] != "]" { body.append(chars[k]); k += 1 }
                        k += 1
                        degree = body
                    }
                    if let (body, next) = group(k) {
                        if let degree {
                            out.append("root \(mathEnglish(degree)) of (" + mathEnglish(body) + ")")
                        } else {
                            out.append("sqrt(" + mathEnglish(body) + ")")
                        }
                        i = next
                        continue
                    }
                }
                if name == "text" || name == "textrm" || name == "mbox" {
                    if let (body, next) = group(j) {
                        out.append("text(" + body + ")")
                        i = next
                        continue
                    }
                }
                if name == "mathbb", let (body, next) = group(j) {
                    out.append(blackboard[body.trimmingCharacters(in: .whitespaces)] ?? "blackboard \(body)")
                    i = next
                    continue
                }
                if let accent = accents[name], let (body, next) = group(j) {
                    out.append("\(accent)(" + mathEnglish(body) + ")")
                    i = next
                    continue
                }
                if let big = bigOperators[name] {
                    var sub: String?
                    var sup: String?
                    var k = j
                    for _ in 0..<2 {
                        guard k < chars.count else { break }
                        if chars[k] == "_", let (body, next) = group(k + 1) {
                            sub = mathEnglish(body)
                            k = next
                        } else if chars[k] == "^", let (body, next) = group(k + 1) {
                            sup = mathEnglish(body)
                            k = next
                        } else {
                            break
                        }
                    }
                    if let sub, let sup {
                        out.append("\(big) from \(sub) to \(sup) of")
                    } else if let sub {
                        out.append(big == "limit" ? "limit as \(sub) of" : "\(big) over \(sub) of")
                    } else if let sup {
                        out.append("\(big) to \(sup) of")
                    } else {
                        out.append(big)
                    }
                    i = k
                    continue
                }
                if name == "left" || name == "right" {
                    i = j
                    continue
                }
                if name == "begin" || name == "end", let (environment, next) = group(j) {
                    if name == "begin" {
                        let close = "\\end{\(environment)}"
                        if let endRange = String(chars[next...]).range(of: close) {
                            let inner = String(String(chars[next...])[String(chars[next...]).startIndex..<endRange.lowerBound])
                            out.append(environmentEnglish(environment, inner))
                            i = next + String(chars[next...]).distance(from: String(chars[next...]).startIndex, to: endRange.upperBound)
                            continue
                        }
                    }
                    i = next
                    continue
                }
                if let word = commandWords[name] {
                    out.append(word)
                    i = j
                    continue
                }
                // unknown: keep the command, which the editor passes through
                out.append("\\" + name)
                i = j
                continue
            }

            if ch == "^" || ch == "_" {
                if let (body, next) = group(i + 1) {
                    let english = mathEnglish(body)
                    let script = english.count == 1 ? english : "(" + english + ")"
                    if var last = out.popLast() {
                        last += String(ch) + script
                        out.append(last)
                    } else {
                        out.append(String(ch) + script)
                    }
                    i = next
                    continue
                }
            }

            if ch == "{" || ch == "}" {
                i += 1
                continue
            }
            if ch.isWhitespace {
                i += 1
                continue
            }
            out.append(String(ch))
            i += 1
        }

        // join, keeping letters that spell one name together
        var text = ""
        for (index, part) in out.enumerated() {
            if index > 0 {
                let previous = out[index - 1]
                let tight = part == "," || part == "." || previous.hasSuffix("(") || part == ")"
                    || (previous.count == 1 && part.count == 1 && previous.first!.isNumber && part.first!.isNumber)
                text += tight ? "" : " "
            }
            text += part
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static func environmentEnglish(_ name: String, _ body: String) -> String {
        switch name {
        case "pmatrix", "matrix", "bmatrix", "vmatrix", "Bmatrix":
            let rows = body.components(separatedBy: "\\\\").map { row in
                row.components(separatedBy: "&").map { mathEnglish($0) }.joined(separator: ", ")
            }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let keyword = ["bmatrix": "bracket matrix", "vmatrix": "det matrix",
                           "Bmatrix": "brace matrix"][name] ?? "matrix"
            return "\(keyword) [" + rows.joined(separator: "; ") + "]"
        case "cases":
            let rows = body.components(separatedBy: "\\\\").map { row -> String in
                let parts = row.components(separatedBy: "&")
                let value = mathEnglish(parts.first ?? "")
                guard parts.count > 1 else { return value }
                var condition = mathEnglish(parts[1])
                    .replacingOccurrences(of: "text(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if condition.lowercased().hasPrefix("if ") { condition = String(condition.dropFirst(3)) }
                if condition.lowercased().hasPrefix("otherwise") { return "\(value) otherwise" }
                return "\(value) if \(condition)"
            }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return "cases {" + rows.joined(separator: "; ") + "}"
        case "aligned", "align", "align*", "split", "gathered":
            return body.components(separatedBy: "\\\\")
                .map { mathEnglish($0.replacingOccurrences(of: "&", with: "")) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        default:
            return mathEnglish(body)
        }
    }
}
