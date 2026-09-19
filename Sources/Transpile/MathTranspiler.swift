// English math -> LaTeX. Single pass lexer + recursive-descent emitter.
// Design: LaTeX output is linear, so only frac, scripts, roots, delimiters and
// big-operator limits need real structure. Everything else concatenates.
import Foundation

enum Tok: Equatable {
    case word(String)
    case num(String)
    case sym(String)          // already mapped to LaTeX
    case raw(String)          // \command passthrough
    case lit(String, String)  // (\text, literal content)
    case open(Character)      // ( [ {
    case close(Character)     // ) ] }
    case frac                 // /
    case slashLit             // //
    case caret                // ^
    case under                // _
    case bang                 // !
    case quote                // '
    case pipe                 // |
}

struct MathLexer {
    static func lex(_ src: String) -> [Tok] {
        let c = Array(src)
        var out: [Tok] = []
        var i = 0
        func isLetter(_ ch: Character) -> Bool { ch.isLetter }
        while i < c.count {
            let ch = c[i]
            if ch.isWhitespace { i += 1; continue }
            if isLetter(ch) {
                var j = i
                while j < c.count, isLetter(c[j]) { j += 1 }
                let run = String(c[i..<j])
                var k = j
                while k < c.count, c[k] == " " { k += 1 }
                if Sym.literalArg.contains(run.lowercased()), k < c.count, c[k] == "(" {
                    let (body, next) = balanced(c, k, "(", ")")
                    out.append(.lit(Sym.literalArgCommand[run.lowercased()] ?? "\\text", body))
                    i = next
                    continue
                }
                out.append(.word(run))
                i = j
                continue
            }
            if ch.isNumber || (ch == "." && i + 1 < c.count && c[i + 1].isNumber) {
                var j = i
                var seenDot = false
                while j < c.count, c[j].isNumber || (c[j] == "." && !seenDot && j + 1 < c.count && c[j + 1].isNumber) {
                    if c[j] == "." { seenDot = true }
                    j += 1
                }
                out.append(.num(String(c[i..<j])))
                i = j
                continue
            }
            switch ch {
            case "\\":
                var j = i + 1
                if j < c.count, isLetter(c[j]) {
                    while j < c.count, isLetter(c[j]) { j += 1 }
                } else if j < c.count {
                    j += 1
                }
                out.append(.raw(String(c[i..<j])))
                i = j
                continue
            case "\"":
                var j = i + 1
                var body = ""
                while j < c.count, c[j] != "\"" { body.append(c[j]); j += 1 }
                out.append(.lit("\\text", body))
                i = min(j + 1, c.count)
                continue
            case "(", "[", "{": out.append(.open(ch)); i += 1; continue
            case ")", "]", "}": out.append(.close(ch)); i += 1; continue
            case "^": out.append(.caret); i += 1; continue
            case "_": out.append(.under); i += 1; continue
            case "!": out.append(.bang); i += 1; continue
            case "'": out.append(.quote); i += 1; continue
            case "|": out.append(.pipe); i += 1; continue
            case "/":
                if i + 1 < c.count, c[i + 1] == "/" { out.append(.slashLit); i += 2 } else { out.append(.frac); i += 1 }
                continue
            default: break
            }
            var matched = false
            for (pat, latex) in Sym.operators where pat.count <= c.count - i {
                if String(c[i..<(i + pat.count)]) == pat {
                    out.append(.sym(latex))
                    i += pat.count
                    matched = true
                    break
                }
            }
            if !matched { out.append(.sym(String(ch))); i += 1 }
        }
        return out
    }

    /// Returns the text inside a balanced delimiter pair starting at `start`, plus the index after it.
    private static func balanced(_ c: [Character], _ start: Int, _ o: Character, _ cl: Character) -> (String, Int) {
        var depth = 0
        var i = start
        var body = ""
        while i < c.count {
            if c[i] == o {
                depth += 1
                if depth == 1 { i += 1; continue }
            } else if c[i] == cl {
                depth -= 1
                if depth == 0 { return (body, i + 1) }
            }
            body.append(c[i])
            i += 1
        }
        return (body, i)
    }
}

final class MathParser {
    private var t: [Tok]
    private var i = 0
    private var units: [String] = []
    private var prevRaw = false
    private let depth: Int

    init(_ toks: [Tok], depth: Int = 0) {
        t = toks
        self.depth = depth
    }

    static func latex(_ src: String) -> String { MathParser(MathLexer.lex(src)).run() }

    /// A nested parse at the same expansion depth.
    private func nested(_ toks: [Tok]) -> String { MathParser(toks, depth: depth).run() }

    /// Expands a user-defined shortcut; stops recursing at three levels.
    private func expand(_ source: String) -> String {
        guard depth < 3 else { return Tex.escape(source) }
        return MathParser(MathLexer.lex(source), depth: depth + 1).run()
    }

    func run() -> String {
        while i < t.count { step() }
        return units.joined(separator: " ")
    }

    // MARK: sequence

    private func step() {
        switch t[i] {
        case .frac:
            i += 1
            makeFrac()
        case .slashLit:
            i += 1
            units.append("/")
        case .caret:
            i += 1
            let g = script(sub: false)
            units.append(pop() + "^{" + g + "}")
        case .under:
            i += 1
            let g = script(sub: true)
            units.append(pop() + "_{" + g + "}")
        case .bang:
            i += 1
            units.append(pop() + "!")
        case .quote:
            i += 1
            units.append(pop() + "'")
        default:
            if let u = unit() { units.append(u) }
        }
    }

    private func pop() -> String { units.popLast() ?? "{}" }

    private func makeFrac() {
        let lhs = thin(unwrap(pop()))
        let rhs = thin(unwrap(unit() ?? ""))
        units.append("\\frac{" + lhs + "}{" + rhs + "}")
    }

    /// A thin space belongs before an integrand, never inside a fraction.
    private func thin(_ s: String) -> String {
        s.hasPrefix("\\,") ? String(s.dropFirst(2)) : s
    }

    /// `\left( x \right)` -> `x`, so `(a+b)/(c+d)` renders without redundant parens.
    private func unwrap(_ s: String) -> String {
        let l = "\\left(", r = "\\right)"
        guard s.hasPrefix(l), s.hasSuffix(r) else { return s }
        let inner = String(s.dropFirst(l.count).dropLast(r.count))
        var depth = 0
        var idx = inner.startIndex
        while idx < inner.endIndex {
            if inner[idx...].hasPrefix("\\left") { depth += 1 }
            if inner[idx...].hasPrefix("\\right") { depth -= 1; if depth < 0 { return s } }
            idx = inner.index(after: idx)
        }
        return depth == 0 ? inner.trimmingCharacters(in: .whitespaces) : s
    }

    // MARK: scripts

    /// The group after `^` or `_`. `_` takes a whole word (x_max); `^` takes one
    /// letter so `a^kx^k` means a^{k}x^{k}. Braces or parens override both.
    private func script(sub: Bool) -> String {
        guard i < t.count else { return "{}" }
        switch t[i] {
        case .open(let ch) where ch == "{" || ch == "(":
            let inner = collectGroup()
            return nested(inner)
        case .num(let n):
            i += 1
            return n
        case .sym(let s) where s == "-" || s == "+":
            i += 1
            return s + script(sub: sub)
        case .word(let w):
            if sub {
                i += 1
                if let g = Sym.greek(w) { return g }
                if w.count <= 2 { return w }
                return "\\mathrm{" + w + "}"
            }
            if keyword(w) != nil || w.count == 1 { return unit() ?? "" }
            let first = String(w.first!)
            t[i] = .word(String(w.dropFirst()))
            return first
        default:
            return unit() ?? "{}"
        }
    }

    private func keyword(_ w: String) -> String? {
        let l = w.lowercased()
        if UserSymbols.shared.lookup(l) != nil { return "user" }
        if Sym.bigOps[l] != nil { return "big" }
        if Sym.prefixOps[l] != nil { return "prefix" }
        if Sym.functions.contains(l) || Sym.functions.contains(w) { return "fn" }
        if Sym.greek(w) != nil { return "greek" }
        if Sym.words[l] != nil { return "word" }
        if Sym.phrases[l] != nil { return "phrase" }
        return nil
    }

    // MARK: units

    private func unit() -> String? {
        guard i < t.count else { return nil }
        let tok = t[i]
        switch tok {
        case .num(let n): i += 1; prevRaw = false; return n
        case .raw(let r): i += 1; prevRaw = true; return r
        case .lit(let cmd, let body): i += 1; return cmd + "{" + Tex.escape(body) + "}"
        case .sym(let s): i += 1; return s
        case .close: i += 1; return nil
        case .open(let ch):
            let wasRaw = prevRaw
            prevRaw = false
            let inner = collectGroup()
            let body = nested(inner)
            switch ch {
            case "(": return "\\left( " + body + " \\right)"
            case "[": return "\\left[ " + body + " \\right]"
            default:
                // Chained groups after a raw command stay LaTeX groups: \frac{a}{b}
                prevRaw = wasRaw
                return wasRaw ? "{" + body + "}" : "\\left\\{ " + body + " \\right\\}"
            }
        case .pipe:
            i += 1
            if let close = findPipe() {
                let inner = Array(t[i..<close])
                i = close + 1
                return "\\left| " + nested(inner) + " \\right|"
            }
            return "\\mid"
        case .word: return word()
        case .frac, .slashLit, .caret, .under, .bang, .quote:
            step()
            return nil
        }
    }

    private func findPipe() -> Int? {
        var depth = 0
        var j = i
        while j < t.count {
            switch t[j] {
            case .open: depth += 1
            case .close: depth -= 1
            case .pipe where depth == 0: return j
            default: break
            }
            j += 1
        }
        return nil
    }

    private func word() -> String? {
        // Longest phrase first.
        if let (value, len) = phraseMatch() {
            i += len
            return resolve(value, source: "")
        }
        guard case .word(let w) = t[i] else { return nil }
        let l = w.lowercased()
        i += 1
        // A trigger may carry digits (chi2, R3); the lexer split them, so try the
        // longer key first.
        if i < t.count, case .num(let n) = t[i], let shortcut = UserSymbols.shared.lookup(l + n) {
            i += 1
            return expand(shortcut)
        }
        if let shortcut = UserSymbols.shared.lookup(l) { return expand(shortcut) }
        if let op = Sym.bigOps[l] { return bigOp(op) }
        if let m = Sym.prefixOps[l] { return prefixOp(m) }
        if Sym.functions.contains(l) || Sym.functions.contains(w) {
            return function("\\" + (w == "Pr" ? "Pr" : l))
        }
        if let g = Sym.greek(w) { return g }
        // Differentials keep their own case: dx, dt, dA, dV all read as one atom.
        if w.count == 2, w.hasPrefix("d"), let second = w.last, second.isLetter {
            return "\\,d" + String(second)
        }
        if let v = Sym.words[l] { return resolve(v, source: w) }
        if let v = Sym.phrases[l] { return resolve(v, source: w) }
        if w.count == 1 { return w }
        return w.map { String($0) }.joined(separator: " ")
    }

    private func phraseMatch() -> (String, Int)? {
        var wordsRun: [String] = []
        var j = i
        let limit = max(Sym.maxPhraseWords, UserSymbols.shared.maxWords)
        while j < t.count, wordsRun.count < limit, case .word(let w) = t[j] {
            wordsRun.append(w.lowercased())
            j += 1
        }
        guard wordsRun.count >= 2 else { return nil }
        var n = wordsRun.count
        while n >= 2 {
            let key = wordsRun[0..<n].joined(separator: " ")
            if let shortcut = UserSymbols.shared.lookup(key) { return ("@user " + shortcut, n) }
            if let v = Sym.phrases[key] { return (v, n) }
            n -= 1
        }
        return nil
    }

    /// Markers (`@name`) need structure; anything else is plain LaTeX.
    private func resolve(_ v: String, source: String) -> String? {
        guard v.hasPrefix("@") else { return v }
        if v.hasPrefix("@user ") { return expand(String(v.dropFirst(6))) }
        switch v {
        case "@skip": return nil
        case "@over": makeFrac(); return nil
        case "@choose":
            let lhs = unwrap(pop())
            let rhs = unwrap(unit() ?? "")
            units.append("\\binom{" + lhs + "}{" + rhs + "}")
            return nil
        case "@choose_nk": return "\\binom{n}{k}"
        case "@fact_n": return "n!"
        case "@sq": return postfix("^{2}")
        case "@cube": return postfix("^{3}")
        case "@inv": return postfix("^{-1}")
        case "@transpose": return postfix("^{\\mathsf{T}}")
        case "@complement": return postfix("^{c}")
        case "@dagger": return postfix("^{\\dagger}")
        case "@fact": return postfix("!")
        case "@conj":
            units.append("\\overline{" + pop() + "}")
            return nil
        case "@of":
            let arg = unwrap(unit() ?? "")
            units.append(pop() + "\\left( " + arg + " \\right)")
            return nil
        case "@sqrt", "@abs": return prefixOp(v)
        case "@cbrt":
            skipWord("of")
            return "\\sqrt[3]{" + arg() + "}"
        case "@iint": return bigOp("\\iint")
        case "@iiint": return bigOp("\\iiint")
        case "@oint": return bigOp("\\oint")
        case "@bigcup": return bigOp("\\bigcup")
        case "@bigcap": return bigOp("\\bigcap")
        case "@bmatrix", "@Bmatrix", "@vmatrix", "@pmatrix": return prefixOp(v)
        case "@deriv": return derivative(order: 1, partial: false)
        case "@deriv2": return derivative(order: 2, partial: false)
        case "@pderiv": return derivative(order: 1, partial: true)
        case "@if": return "&\\ \\text{if } "
        case "@otherwise": return "&\\ \\text{otherwise}"
        default:
            // A limit word used outside a big operator is just that word, set upright.
            return "\\ \\text{" + Tex.escape(source.isEmpty ? String(v.dropFirst()) : source) + "}\\ "
        }
    }

    /// `\sin` plus its scripts and one tight argument, as a single unit.
    private func function(_ name: String) -> String {
        var out = name
        while i < t.count, t[i] == .caret || t[i] == .under {
            let isSup = t[i] == .caret
            i += 1
            out += (isSup ? "^{" : "_{") + script(sub: !isSup) + "}"
        }
        guard i < t.count else { return out }
        switch t[i] {
        case .num, .word, .open, .raw, .lit:
            if case .word(let w) = t[i], Sym.words[w.lowercased()]?.hasPrefix("@") == true { return out }
            var a = unit() ?? ""
            while i < t.count, t[i] == .caret || t[i] == .under {
                let isSup = t[i] == .caret
                i += 1
                a += (isSup ? "^{" : "_{") + script(sub: !isSup) + "}"
            }
            return out + " " + a
        default:
            return out
        }
    }

    private func postfix(_ s: String) -> String? {
        units.append(pop() + s)
        return nil
    }

    // MARK: constructs

    private func skipWord(_ w: String) {
        if i < t.count, case .word(let x) = t[i], x.lowercased() == w { i += 1 }
    }

    /// One argument: a bracketed group, or a single unit.
    private func arg() -> String {
        skipWord("of")
        guard i < t.count else { return "{}" }
        if case .open = t[i] {
            let inner = collectGroup()
            return nested(inner)
        }
        var out = unit() ?? "{}"
        // let x^2, x_i bind into the argument
        while i < t.count, t[i] == .caret || t[i] == .under {
            let isSup = t[i] == .caret
            i += 1
            out += (isSup ? "^{" : "_{") + script(sub: !isSup) + "}"
        }
        return unwrap(out)
    }

    private func prefixOp(_ m: String) -> String? {
        switch m {
        case "@sqrt": return "\\sqrt{" + arg() + "}"
        case "@root":
            let deg = arg()
            skipWord("of")
            return "\\sqrt[" + deg + "]{" + arg() + "}"
        case "@vec": return "\\vec{" + arg() + "}"
        case "@hat": return "\\hat{" + arg() + "}"
        case "@bar": return "\\bar{" + arg() + "}"
        case "@tilde": return "\\tilde{" + arg() + "}"
        case "@overline": return "\\overline{" + arg() + "}"
        case "@underline": return "\\underline{" + arg() + "}"
        case "@bold": return "\\mathbf{" + arg() + "}"
        case "@cal": return "\\mathcal{" + arg() + "}"
        case "@frak": return "\\mathfrak{" + arg() + "}"
        case "@bb": return "\\mathbb{" + arg() + "}"
        case "@boxed": return "\\boxed{" + arg() + "}"
        case "@cancel": return "\\cancel{" + arg() + "}"
        case "@overbrace": return "\\overbrace{" + arg() + "}"
        case "@underbrace": return "\\underbrace{" + arg() + "}"
        case "@abs": return "\\left| " + arg() + " \\right|"
        case "@norm": return "\\left\\| " + arg() + " \\right\\|"
        case "@floor": return "\\left\\lfloor " + arg() + " \\right\\rfloor"
        case "@ceil": return "\\left\\lceil " + arg() + " \\right\\rceil"
        case "@round": return "\\left\\lfloor " + arg() + " \\right\\rceil"
        case "@set": return "\\left\\{ " + arg() + " \\right\\}"
        case "@inner": return "\\left\\langle " + arg() + " \\right\\rangle"
        case "@binom":
            let parts = splitArgs()
            return "\\binom{" + (parts.first ?? "") + "}{" + (parts.count > 1 ? parts[1] : "") + "}"
        case "@pmatrix": return matrix("pmatrix")
        case "@bmatrix": return matrix("bmatrix")
        case "@Bmatrix": return matrix("Bmatrix")
        case "@vmatrix": return matrix("vmatrix")
        case "@cases": return cases()
        default: return nil
        }
    }

    private func derivative(order: Int, partial: Bool) -> String? {
        skipWord("of")
        var body: [Tok] = []
        var depth = 0
        while i < t.count {
            if case .word(let w) = t[i], w.lowercased() == "with", depth == 0 {
                i += 1
                skipWord("respect")
                skipWord("to")
                break
            }
            if case .open = t[i] { depth += 1 }
            if case .close = t[i] { depth -= 1 }
            body.append(t[i])
            i += 1
        }
        let f = nested(body)
        let v = arg()
        let d = partial ? "\\partial" : "d"
        let pow = order > 1 ? "^{\(order)}" : ""
        return "\\frac{\(d)\(pow) \(f)}{\(d) \(v)\(pow)}"
    }

    private func bigOp(_ op: String) -> String? {
        var sub = "", sup = ""
        var guardCount = 0
        loop: while i < t.count, guardCount < 4 {
            guardCount += 1
            guard case .word(let w) = t[i] else { break loop }
            switch w.lowercased() {
            case "from":
                i += 1
                let (slice, stop) = collectUntilWords(["to", "of"])
                sub = nested(slice)
                if stop == "to" {
                    let (up, _) = collectUntilWords(["of"])
                    sup = nested(up)
                }
            case "over", "as", "where", "for":
                i += 1
                let (slice, _) = collectUntilWords(["of"])
                sub = nested(slice)
            case "to":
                i += 1
                let (up, _) = collectUntilWords(["of"])
                sup = nested(up)
            case "of":
                i += 1
                break loop
            default: break loop
            }
        }
        var out = op
        if !sub.isEmpty { out += "_{" + sub + "}" }
        if !sup.isEmpty { out += "^{" + sup + "}" }
        return out
    }

    private func matrix(_ env: String) -> String? {
        skipWord("of")
        skipWord("the")
        guard i < t.count, case .open = t[i] else { return "\\text{matrix?}" }
        let inner = collectGroup()
        let rows = split(inner, on: ";").map { row in
            split(row, on: ",").map { nested($0) }.joined(separator: " & ")
        }
        return "\\begin{\(env)}" + rows.joined(separator: " \\\\ ") + "\\end{\(env)}"
    }

    private func cases() -> String? {
        skipWord("of")
        guard i < t.count, case .open = t[i] else { return "\\text{cases?}" }
        let inner = collectGroup()
        let rows = split(inner, on: ";").map { nested($0) }
        return "\\begin{cases}" + rows.joined(separator: " \\\\ ") + "\\end{cases}"
    }

    private func splitArgs() -> [String] {
        guard i < t.count, case .open = t[i] else { return [arg()] }
        let inner = collectGroup()
        return split(inner, on: ",").map { nested($0) }
    }

    // MARK: token slicing

    /// Consumes an `(`/`[`/`{` group and returns its interior tokens.
    private func collectGroup() -> [Tok] {
        guard i < t.count, case .open = t[i] else { return [] }
        var depth = 0
        var out: [Tok] = []
        while i < t.count {
            if case .open = t[i] {
                depth += 1
                i += 1
                if depth == 1 { continue }
                out.append(.open(openChar(t[i - 1])))
                continue
            }
            if case .close(let ch) = t[i] {
                depth -= 1
                i += 1
                if depth == 0 { return out }
                out.append(.close(ch))
                continue
            }
            out.append(t[i])
            i += 1
        }
        return out
    }

    private func openChar(_ tok: Tok) -> Character {
        if case .open(let c) = tok { return c }
        return "("
    }

    /// Tokens up to the first depth-0 word in `stops`; that word is consumed.
    private func collectUntilWords(_ stops: Set<String>) -> ([Tok], String?) {
        var depth = 0
        var out: [Tok] = []
        while i < t.count {
            if case .open = t[i] { depth += 1 }
            if case .close = t[i] { depth -= 1 }
            if depth == 0, case .word(let w) = t[i], stops.contains(w.lowercased()) {
                i += 1
                return (out, w.lowercased())
            }
            out.append(t[i])
            i += 1
        }
        return (out, nil)
    }

    private func split(_ toks: [Tok], on ch: Character) -> [[Tok]] {
        var out: [[Tok]] = [[]]
        var depth = 0
        for tok in toks {
            if case .open = tok { depth += 1 }
            if case .close = tok { depth -= 1 }
            if depth == 0, case .sym(let s) = tok, s == String(ch) {
                out.append([])
                continue
            }
            out[out.count - 1].append(tok)
        }
        return out.filter { !$0.isEmpty }
    }
}

enum Tex {
    /// Escape for LaTeX text mode.
    static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "\\": out += "\\textbackslash{}"
            case "&", "%", "$", "#", "_", "{", "}": out += "\\" + String(ch)
            case "~": out += "\\textasciitilde{}"
            case "^": out += "\\textasciicircum{}"
            default: out.append(ch)
            }
        }
        return out
    }
}
