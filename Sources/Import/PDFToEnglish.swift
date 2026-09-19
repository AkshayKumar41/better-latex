// Turns the recovered structure back into BetterLaTeX English: the inverse of
// the transpiler. Unicode that came out of the PDF maps to the same words the
// editor accepts, so an imported document is editable, not just readable.
import CoreGraphics
import Foundation

enum PDFToEnglish {

    /// Unicode -> what you would type in the editor. Built through `uniquingKeysWith`
    /// rather than as a dictionary literal: a repeated key is a table mistake, not
    /// a reason to kill the import, and `duplicateKeys` reports it to the tests.
    static let wordPairs: [(String, String)] = [
        ("\u{2212}", "-"), ("\u{00B7}", "cdot"), ("\u{00D7}", "times"), ("\u{00F7}", "div"),
        ("\u{00B1}", "+-"), ("\u{2213}", "-+"), ("\u{2217}", "ast"), ("\u{22C6}", "star"),
        ("\u{2264}", "<="), ("\u{2265}", ">="), ("\u{2260}", "!="), ("\u{2261}", "=="),
        ("\u{2248}", "approx"), ("\u{223C}", "sim"), ("\u{2245}", "cong"), ("\u{221D}", "propto"),
        ("\u{226A}", "ll"), ("\u{226B}", "gg"), ("\u{2254}", "is defined as"),
        ("\u{2208}", "in"), ("\u{2209}", "not in"), ("\u{220B}", "ni"),
        ("\u{2282}", "subset"), ("\u{2286}", "subseteq"), ("\u{2283}", "superset"),
        ("\u{2287}", "supseteq"), ("\u{222A}", "union"), ("\u{2229}", "intersect"),
        ("\u{2205}", "empty set"), ("\u{2216}", "without"),
        ("\u{2200}", "for all"), ("\u{2203}", "there exists"), ("\u{2204}", "there is no"),
        ("\u{00AC}", "not"), ("\u{2227}", "and"), ("\u{2228}", "or"),
        ("\u{21D2}", "implies"), ("\u{21D4}", "iff"), ("\u{2192}", "->"), ("\u{2190}", "gets"),
        ("\u{21A6}", "maps to"), ("\u{27F6}", "->"), ("\u{2194}", "<->"),
        ("\u{221E}", "infinity"), ("\u{2202}", "partial"), ("\u{2207}", "nabla"),
        ("\u{2234}", "therefore"), ("\u{2235}", "because"),
        ("\u{22A5}", "perp"), ("\u{2225}", "parallel"), ("\u{2220}", "angle"),
        ("\u{2218}", "circ"), ("\u{2295}", "oplus"), ("\u{2297}", "otimes"), ("\u{2299}", "odot"),
        ("\u{22A4}", "top"), ("\u{22A2}", "vdash"), ("\u{22A8}", "models"),
        ("\u{2026}", "dots"), ("\u{22EF}", "cdots"), ("\u{22EE}", "vdots"), ("\u{22F1}", "ddots"),
        ("\u{211D}", "reals"), ("\u{2115}", "naturals"), ("\u{2124}", "integers"),
        ("\u{211A}", "rationals"), ("\u{2102}", "complexes"), ("\u{2119}", "primes"),
        ("\u{2135}", "aleph"), ("\u{210F}", "hbar"), ("\u{2113}", "ell"), ("\u{2118}", "wp"),
        ("\u{221A}", "sqrt"), ("\u{2223}", "mid"), 
        ("\u{25A0}", "blacksquare"), ("\u{25FB}", "square"), ("\u{2022}", "bullet"),
        ("\u{00B0}", "degrees"), ("\u{2032}", "'"), ("\u{2020}", "adjoint"),
        // Greek, lower then upper
        ("\u{03B1}", "alpha"), ("\u{03B2}", "beta"), ("\u{03B3}", "gamma"), ("\u{03B4}", "delta"),
        ("\u{03B5}", "epsilon"), ("\u{03F5}", "epsilon"), ("\u{03B6}", "zeta"), ("\u{03B7}", "eta"),
        ("\u{03B8}", "theta"), ("\u{03B9}", "iota"), ("\u{03BA}", "kappa"), ("\u{03BB}", "lambda"),
        ("\u{03BC}", "mu"), ("\u{00B5}", "mu"), ("\u{03BD}", "nu"), ("\u{03BE}", "xi"),
        ("\u{03C0}", "pi"), ("\u{03C1}", "rho"), ("\u{03C3}", "sigma"), ("\u{03C2}", "varsigma"),
        ("\u{03C4}", "tau"), ("\u{03C5}", "upsilon"), ("\u{03C6}", "phi"), ("\u{03D5}", "phi"),
        ("\u{03C7}", "chi"), ("\u{03C8}", "psi"), ("\u{03C9}", "omega"),
        // U+2126 OHM is canonically equal to U+03A9 in Swift, so it is not listed.
        ("\u{0393}", "Gamma"), ("\u{2206}", "Delta"), ("\u{0394}", "Delta"), ("\u{0398}", "Theta"),
        ("\u{039B}", "Lambda"), ("\u{039E}", "Xi"), ("\u{03A0}", "Pi"), ("\u{03A3}", "Sigma"),
        ("\u{03A5}", "Upsilon"), ("\u{03A6}", "Phi"), ("\u{03A8}", "Psi"), ("\u{03A9}", "Omega"),
    ]

    static let words: [String: String] = Dictionary(wordPairs, uniquingKeysWith: { first, _ in first })

    /// Keys written more than once, for the checks to assert on.
    static var duplicateKeys: [String] {
        var seen = Set<String>()
        var repeated: [String] = []
        for (key, _) in wordPairs where !seen.insert(key).inserted { repeated.append(key) }
        return repeated
    }

    /// Operator names LaTeX sets upright, recovered from consecutive letters.
    private static let functions: Set<String> = [
        "sin", "cos", "tan", "cot", "sec", "csc", "log", "ln", "exp", "det", "dim",
        "ker", "deg", "gcd", "max", "min", "sup", "inf", "lim", "arg", "mod",
    ]

    // MARK: math

    static func english(_ node: MathNode) -> String {
        switch node {
        case .atom(let text):
            return atom(text)
        case .sequence(let parts):
            return join(parts.map { english($0) })
        case .script(let base, let sup, let sub):
            var out = english(base)
            if let sub { out += "_" + group(sub) }
            if let sup { out += "^" + group(sup) }
            return out
        case .fraction(let top, let bottom):
            return group(top, forceParens: !isSimple(top)) + "/" + group(bottom, forceParens: !isSimple(bottom))
        case .bigOp(let name, let sub, let sup):
            if let sub, let sup {
                return "\(name) from \(english(sub)) to \(english(sup)) of"
            }
            if let sub { return "\(name) over \(english(sub)) of" }
            if let sup { return "\(name) to \(english(sup)) of" }
            return name
        case .delimited(let open, let body, let close):
            return open + english(body) + close
        case .binom(let top, let bottom):
            return "binom(\(english(top)), \(english(bottom)))"
        case .radical(let body):
            return "sqrt(\(english(body)))"
        }
    }

    private static func atom(_ text: String) -> String {
        let base = PDFLayout.strip(text)
        if let word = words[base] { return word }
        return base
    }

    private static func isSimple(_ node: MathNode) -> Bool {
        if case .atom = node { return true }
        if case .sequence(let parts) = node { return parts.count == 1 }
        return false
    }

    private static func group(_ node: MathNode, forceParens: Bool = false) -> String {
        let text = english(node)
        if !forceParens, text.count == 1 { return text }
        if text.hasPrefix("(") && text.hasSuffix(")") { return text }
        return "(" + text + ")"
    }

    /// Joins atoms, keeping operator spacing readable and gluing letters that
    /// spell an operator name back together.
    private static func join(_ parts: [String]) -> String {
        var out: [String] = []
        var letters = ""

        func flushLetters() {
            guard !letters.isEmpty else { return }
            out.append(letters)
            letters = ""
        }

        for part in parts {
            if part.count == 1, part.first!.isLetter {
                letters += part
                continue
            }
            flushLetters()
            out.append(part)
        }
        flushLetters()

        var text = ""
        for (i, part) in out.enumerated() {
            if i > 0 {
                let previous = out[i - 1]
                let tight = part == "." || part == "," || previous.hasSuffix("(") || part == ")"
                text += tight ? "" : " "
            }
            text += functions.contains(part.lowercased()) ? part.lowercased() : part
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: document

    struct Result {
        var source = ""
        var notes: [String] = []
        var mathRuns = 0
        var pages = 0
    }

    static func convert(_ pages: [PDFPageContent], title fallbackTitle: String) -> Result {
        var result = Result()
        result.pages = pages.count
        var blocks: [String] = []
        var paragraph: [String] = []
        var title: String?
        var previousRow: Row?
        var body: CGFloat = 10

        for (pageIndex, page) in pages.enumerated() {
            let rows = PDFLayout.rows(page)
            guard !rows.isEmpty else { continue }
            if pageIndex == 0 { body = PDFLayout.dominantSize(page.glyphs) }
            result.notes.append(contentsOf: page.unsupportedFonts.map {
                "font \($0) has no character map, so its text may be wrong"
            })

            // A paragraph break is a gap noticeably larger than this page's own line
            // spacing, which varies with the document's typesetting.
            var gaps: [CGFloat] = []
            for (a, b) in zip(rows, rows.dropFirst()) {
                let gap = a.baseline - b.baseline
                if gap > 0 { gaps.append(gap) }
            }
            // The most common gap is the line spacing. A median would be dragged up
            // by the larger gaps that separate problems.
            var gapCounts: [CGFloat: Int] = [:]
            for gap in gaps { gapCounts[(gap * 2).rounded() / 2, default: 0] += 1 }
            let lineGap = gapCounts.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key
                ?? (body * 1.35)

            for row in rows {
                let segments = PDFLayout.analyse(row: row, rules: page.rules, body: body)
                guard !segments.isEmpty else { continue }
                result.mathRuns += segments.filter { if case .math = $0 { return true } else { return false } }.count

                let text = render(segments)
                if text.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                if isPageNumber(text) { continue }

                let gap = previousRow.map { $0.baseline - row.baseline } ?? 0
                let newBlock = previousRow == nil || gap > lineGap * 1.25 || gap < 0
                let indented = previousRow.map { row.minX > $0.minX + body * 0.4 } ?? false

                // the biggest bold line on the first page is the title
                if pageIndex == 0, title == nil, row.isBold, row.size > body * 1.15, row.isCentered {
                    title = text
                    previousRow = row
                    continue
                }

                let displayMath = row.isCentered && segments.allSatisfy { if case .math = $0 { return true } else { return false } }

                if displayMath {
                    flush(&paragraph, into: &blocks)
                    if case .math(let node) = segments[0] {
                        blocks.append("display(" + english(node) + ")")
                    }
                    previousRow = row
                    continue
                }

                if let item = listMarker(text) {
                    flush(&paragraph, into: &blocks)
                    paragraph.append(item)
                    previousRow = row
                    continue
                }
                if indented, !paragraph.isEmpty, newBlock {
                    flush(&paragraph, into: &blocks)
                }

                if newBlock, !paragraph.isEmpty {
                    flush(&paragraph, into: &blocks)
                }
                paragraph.append(text)
                previousRow = row
            }
            previousRow = nil
            flush(&paragraph, into: &blocks)
        }
        flush(&paragraph, into: &blocks)

        var header = ""
        if let title {
            header += "title: \(title)\n"
        } else {
            header += "title: \(fallbackTitle)\n"
        }
        header += "\n"
        var text = blocks.joined(separator: "\n\n")
        for pattern in ["L math(A) TEX", "L math(A) T EX", "LA TEX", "L A TEX"] {
            text = text.replacingOccurrences(of: pattern, with: "LaTeX")
        }
        // an ellipsis arrives as three separate dots
        text = text.replacingOccurrences(of: "cdot cdot cdot", with: "cdots")
        text = text.replacingOccurrences(of: ". . .", with: "dots")
        result.source = header + text + "\n"
        return result
    }

    private static func render(_ segments: [Segment]) -> String {
        var out = ""
        for segment in segments {
            switch segment {
            case .prose(let text):
                if !out.isEmpty, !out.hasSuffix(" ") { out += " " }
                out += text
            case .math(let node):
                var math = english(node)
                var trailing = ""
                while let last = math.last, ".,;:".contains(last) {
                    trailing = String(last) + trailing
                    math.removeLast()
                    math = math.trimmingCharacters(in: .whitespaces)
                }
                guard !math.isEmpty else {
                    out += trailing
                    continue
                }
                if !out.isEmpty, !out.hasSuffix(" ") { out += " " }
                out += "math(\(math))" + trailing
            }
        }
        return out
    }

    /// LaTeX wraps lines, so a paragraph arrives as many rows; hyphenated breaks
    /// are rejoined, everything else is separated by a space.
    private static func flush(_ paragraph: inout [String], into blocks: inout [String]) {
        guard !paragraph.isEmpty else { return }
        var text = ""
        for line in paragraph {
            if text.isEmpty { text = line; continue }
            if text.hasSuffix("-"), let next = line.first, next.isLowercase {
                text.removeLast()
                text += line
            } else {
                text += " " + line
            }
        }
        blocks.append(text)
        paragraph = []
    }

    /// Keeps the document's own numbering as written. A real list would renumber
    /// from one every time a display equation interrupts it, which would silently
    /// change what the questions are called.
    private static func listMarker(_ text: String) -> String? {
        var digits = ""
        var rest = Substring(text)
        while let f = rest.first, f.isNumber { digits.append(f); rest = rest.dropFirst() }
        if !digits.isEmpty, rest.hasPrefix(". ") {
            return "**\(digits).** " + rest.dropFirst(2)
        }
        if text.hasPrefix("("), let close = text.firstIndex(of: ")"),
           text.distance(from: text.startIndex, to: close) == 2 {
            let letter = text[text.index(after: text.startIndex)]
            if letter.isLetter {
                return "**(\(letter))** " + text[text.index(after: close)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func isPageNumber(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.count <= 3 && Int(trimmed) != nil
    }
}
