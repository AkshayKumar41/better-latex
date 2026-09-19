// Assertion harness for the transpiler. Run: ./build.sh test
import Foundation

var failures = 0
var checks = 0

func expect(_ input: String, _ wanted: String, _ note: String = "") {
    checks += 1
    let got = MathParser.latex(input)
    let norm = got.split(separator: " ").joined(separator: " ")
    if norm != wanted {
        failures += 1
        print("FAIL \(note.isEmpty ? input : note)")
        print("  in   \(input)")
        print("  want \(wanted)")
        print("  got  \(norm)")
    }
}

func expectContains(_ input: String, _ needle: String, _ note: String = "") {
    checks += 1
    let got = DocTranspiler.render(input)
    if !got.latex.contains(needle) {
        failures += 1
        print("FAIL doc \(note)")
        print("  want substring \(needle)")
        print("  got \(got.latex)")
    }
}

// --- the spec's own examples
expect("sum from k = 1 to n of a^kx^k", "\\sum_{k = 1}^{n} a^{k} x^{k}", "sum with limits")
expect("for all s in S", "\\forall s \\in S", "for all / in")
expect("1/2", "\\frac{1}{2}", "default fraction")
expect("a//b", "a / b", "// is a literal slash")
expect("x_max", "x_{\\mathrm{max}}", "underscore takes the whole word")
expect("x^2", "x^{2}", "caret")
expect("(x+1)/(y+2)", "\\frac{x + 1}{y + 2}", "parens drop inside a fraction")
expect("x + 1/y", "x + \\frac{1}{y}", "fraction binds tighter than plus")

// --- big operators
expect("integral from 0 to 1 of x^2 dx", "\\int_{0}^{1} x^{2} \\,dx", "integral")
expect("product from i = 1 to n of x_i", "\\prod_{i = 1}^{n} x_{i}", "product")
expect("limit as x -> 0 of sin x / x", "\\lim_{x \\to 0} \\frac{\\sin x}{x}", "limit")
expect("sum over k of a_k", "\\sum_{k} a_{k}", "sum over")
expect("double integral over D of f", "\\iint_{D} f", "double integral")

// --- set / logic language
expect("there exists x in reals such that x^2 = 2", "\\exists x \\in \\mathbb{R} \\mid x^{2} = 2", "exists")
expect("A union B intersect C", "A \\cup B \\cap C", "union / intersect")
expect("A subset of B", "A \\subset B", "subset phrase")
expect("x not in empty set", "x \\notin \\varnothing", "notin, empty set")
expect("p implies q", "p \\implies q", "implies")
expect("n is at most 10", "n \\le 10", "at most")

// --- greek, functions, accents
expect("alpha + Omega", "\\alpha + \\Omega", "greek")
expect("sin theta ^ 2", "\\sin \\theta^{2}", "function and greek")
expect("vec v dot vec w", "\\vec{v} \\cdot \\vec{w}", "vectors")
expect("sqrt of x + 1", "\\sqrt{x} + 1", "sqrt of one unit")
expect("sqrt(x + 1)", "\\sqrt{x + 1}", "sqrt of a group")
expect("root 3 of 8", "\\sqrt[3]{8}", "nth root")
expect("abs(x - y)", "\\left| x - y \\right|", "abs")
expect("n choose k", "\\binom{n}{k}", "binomial")
expect("x squared + y cubed", "x^{2} + y^{3}", "squared / cubed")
expect("A transpose", "A^{\\mathsf{T}}", "transpose")

// --- structures
expect("matrix [1, 2; 3, 4]", "\\begin{pmatrix}1 & 2 \\\\ 3 & 4\\end{pmatrix}", "matrix")
expect("d/dx", "\\frac{d}{dx}", "derivative shorthand")
expect("derivative of f with respect to x", "\\frac{d f}{d x}", "derivative in words")
expect("partial derivative of u with respect to t", "\\frac{\\partial u}{\\partial t}", "partial derivative")
expect("\\frac{a}{b}", "\\frac {a} {b}", "raw LaTeX passes through")
expect("text(hello world)", "\\text{hello world}", "text escape hatch")
expect("a over b", "\\frac{a}{b}", "over")
expect("P(A given B)", "P \\left( A \\mid B \\right)", "conditional probability")

// --- document level
expectContains("# Intro\n\nhello math(x^2)", "\\section{Intro}", "heading")
expectContains("hello math(x^2)", "$x^{2}$", "inline math in a paragraph")
expectContains("display(sum from k=1 to n of k)", "\\sum_{k = 1}^{n}", "display math")
expectContains("- one\n- two", "\\begin{itemize}", "bullets")
expectContains("1. one\n2. two", "\\begin{enumerate}", "numbered list")
expectContains("title: Paper\nauthor: Me\n\nbody", "\\title{Paper}", "front matter")
expectContains("theorem: every group has an identity", "\\begin{theorem}", "theorem environment")
expectContains("\\math(x)", "math(x)", "backslash disables a construct")
expectContains("| a | b |\n|---|---|\n| 1 | 2 |", "\\begin{tabular}", "table")
expectContains("**bold** and *italic*", "\\textbf{bold}", "bold")
expectContains("$x^2$", "$x^{2}$", "dollar math still works")

// --- alignment must not land inside a subscript group
expectContains("align(\nsum from k = 1 to n of k = n(n+1)/2\n)", "\\sum_{k = 1}^{n} k &= ", "align breaks at the outer relation")
expectContains("align(\nx^{2} = y\n)", "x^{2} &= y", "align with a brace group")

// --- display math is a block of its own, not wrapped in a paragraph
checks += 1
let displayHTML = DocTranspiler.render("text before\n\ndisplay(x^2)\n\ntext after").html
if displayHTML.contains("<p data-l=\"2\"><div") || displayHTML.range(of: "<p[^>]*><div class=\"km kd\"", options: .regularExpression) != nil {
    failures += 1
    print("FAIL display math is wrapped in a paragraph")
    print("  got \(displayHTML)")
}

// --- constructs inside backticks are documentation, not constructs
expectContains("use `math(x^2)` for inline math", "\\texttt{math(x\\textasciicircum{}2)}", "code span keeps its text")
expectContains("```\nmath(x)\n$y$\n```", "math(x)", "fenced block keeps its text")

// --- differentials keep their case and their thin space
expect("double integral over D of f dA", "\\iint_{D} f \\,dA", "dA is one atom")
expect("triple integral over V of f dV", "\\iiint_{V} f \\,dV", "dV is one atom")
expect("integral from 0 to 1 of f dt", "\\int_{0}^{1} f \\,dt", "dt is one atom")

// --- user-defined shortcuts
let shortcutFile = NSTemporaryDirectory() + "bltx-shortcuts-test.conf"
try? """
# comment line
qed = \\blacksquare
hess = matrix [a, b; c, d]
grad f = nabla f
loopy = loopy
built on = reals
chi2 = chi^2
""".write(toFile: shortcutFile, atomically: true, encoding: .utf8)
UserSymbols.pathOverride = shortcutFile
UserSymbols.shared.load()
expect("qed", "\\blacksquare", "user shortcut")
expect("hess", "\\begin{pmatrix}a & b \\\\ c & d\\end{pmatrix}", "shortcut with structure")
expect("grad f", "\\nabla f", "multi-word shortcut")
expect("x = hess", "x = \\begin{pmatrix}a & b \\\\ c & d\\end{pmatrix}", "shortcut inside an expression")
expect("built on", "\\mathbb{R}", "a shortcut can override a built-in phrase")
expect("chi2", "\\chi^{2}", "a trigger may contain digits")
checks += 1
if MathParser.latex("loopy").isEmpty { failures += 1; print("FAIL self-referential shortcut did not terminate") }
// point at a path that does not exist: the checks must never depend on the
// shortcuts file of whoever is running them
UserSymbols.pathOverride = NSTemporaryDirectory() + "bltx-no-such-shortcuts.conf"
UserSymbols.shared.load()
expect("qed", "q e d", "shortcuts stop applying once unloaded")

// --- line breaks
expectContains("first line\\\nsecond line", "first line \\\\\nsecond line", "trailing backslash breaks the line")
expectContains("first line  \nsecond line", "first line \\\\\nsecond line", "two trailing spaces break the line")
expectContains("one\ntwo", "one two", "an ordinary newline keeps the paragraph flowing")
checks += 1
if DocTranspiler.render("only line\\\n").latex.contains("\\\\") {
    failures += 1
    print("FAIL a break at the end of a paragraph should be dropped")
}
checks += 1
if !DocTranspiler.render("first\\\nsecond").html.contains("<br>") {
    failures += 1
    print("FAIL html line break missing")
}

// --- lettered sub-lists
expectContains("A. first", "\\item[A.]", "a lettered item keeps its label")
expectContains("a) first", "\\item[a)]", "a closing paren marker works too")
expectContains("(b) second", "\\item[(b)]", "a parenthesised marker works too")
checks += 1
let lettered = DocTranspiler.render("1. problem\n\nA. part one\n\nB. part two").latex
if !lettered.contains("\\item[A.]") || !lettered.contains("\\item[B.]") {
    failures += 1
    print("FAIL lettered parts lost their labels: \(lettered)")
}
checks += 1
// a letter under a number is a sub-part, so its list opens inside the numbered one
let nested = DocTranspiler.render("1. problem\nA. part").html
if !nested.contains("<ol class=\"lettered\">") {
    failures += 1
    print("FAIL lettered sub-list not opened: \(nested)")
}
checks += 1
if DocTranspiler.render("Sentence. A. B. Smith wrote it.").latex.contains("\\item") {
    failures += 1
    print("FAIL a sentence was mistaken for a lettered item")
}

// --- new rows inside a maths block
expectContains("display(a = b\nc = d)", "a &= b \\\\\nc &= d", "a newline starts a new row in display")
expectContains("display(a = b \\\\ c = d)", "a &= b \\\\\nc &= d", "a LaTeX row break also works")
expectContains("equation(x = 1\ny = 2)", "\\begin{align}", "a multi-row equation is numbered as align")
expectContains("display(x^2 + y^2 = r^2)", "\\[", "a single row is still a plain display")
expectContains("display(\\begin{pmatrix} a \\\\ b \\end{pmatrix})", "pmatrix", "an environment keeps its own row breaks")

// --- indentation and boxes
expectContains("plain line\n\n  indented line", "\\setlength{\\leftskip}{2em}", "two spaces indent a block")
expectContains("plain line\n\n\tindented line", "\\setlength{\\leftskip}{2em}", "a tab indents a block")
expectContains("    deeper", "\\setlength{\\leftskip}{4em}", "indentation accumulates")
expectContains("box: remember this", "\\fbox{", "box environment")
checks += 1
if !DocTranspiler.render("box: remember this").html.contains("class=\"boxed\"") {
    failures += 1
    print("FAIL box did not render as a box")
}
checks += 1
if DocTranspiler.render("- item\n  - nested").latex.contains("leftskip") {
    failures += 1
    print("FAIL nested list items were treated as indented paragraphs")
}

// --- comments
expectContains("% a note\nvisible text", "visible text", "a comment line is dropped")
checks += 1
if DocTranspiler.render("% a note\nvisible").latex.contains("a note") {
    failures += 1
    print("FAIL comment text leaked into the document")
}

// --- PDF import: tables, character maps, and layout on synthetic glyphs
checks += 1
if !PDFToEnglish.duplicateKeys.isEmpty {
    failures += 1
    print("FAIL the unicode table repeats \(PDFToEnglish.duplicateKeys)")
}

checks += 1
let cmap = """
2 beginbfchar
<01> <00B7>
<06> <03A3>
endbfchar
1 beginbfrange
<41> <43> <0041>
endbfrange
"""
let parsed = PDFTextExtractor.parseCMap(cmap.data(using: .utf8)!)
if parsed[0x01] != "\u{00B7}" || parsed[0x06] != "\u{03A3}" || parsed[0x42] != "B" {
    failures += 1
    print("FAIL character map parsing: \(parsed)")
}

// a_n = 4^n, built the way the extractor would report it
func glyph(_ text: String, _ font: String, _ size: CGFloat, _ x: CGFloat, _ y: CGFloat) -> PDFGlyph {
    PDFGlyph(text: text, font: font, size: size, x: x, y: y, width: size * 0.5)
}
let sample = PDFPageContent(
    glyphs: [
        glyph("a", "CMMI10", 10.9, 100, 500),
        glyph("n", "CMMI8", 8, 105, 498.4),
        glyph("=", "CMR10", 10.9, 112, 500),
        glyph("4", "CMR10", 10.9, 120, 500),
        glyph("n", "CMMI8", 8, 126, 503.9),
    ],
    rules: [], unsupportedFonts: [], height: 792)
checks += 1
let sampleRows = PDFLayout.rows(sample)
if sampleRows.count != 1 {
    failures += 1
    print("FAIL scripts should stay on their own line, got \(sampleRows.count) rows")
} else {
    let segments = PDFLayout.analyse(row: sampleRows[0], rules: [], body: 10.9)
    let text = segments.map { segment -> String in
        if case .math(let node) = segment { return PDFToEnglish.english(node) }
        if case .prose(let t) = segment { return t }
        return ""
    }.joined()
    if text != "a_n = 4^n" {
        failures += 1
        print("FAIL subscript and superscript recovery")
        print("  want a_n = 4^n")
        print("  got  \(text)")
    }
}

// --- LaTeX import
func expectTeX(_ tex: String, _ needle: String, _ note: String) {
    checks += 1
    let converted = TeXImport.convert(tex).source
    if !converted.contains(needle) {
        failures += 1
        print("FAIL tex import \(note)")
        print("  want substring \(needle)")
        print("  got \(converted)")
    }
}

expectTeX("$a_n = 4^n$", "math(a_n = 4^n)", "inline maths")
expectTeX("\\[ \\sum_{n \\ge 0} a_n x^n \\]", "display(sum over n >= 0 of a_n x^n)", "display sum")
expectTeX("$\\frac{1}{1-4x}$", "1/(1 - 4 x)", "fraction")
expectTeX("$\\binom{n+2}{2}$", "binom(n + 2, 2)", "binomial")
expectTeX("$\\sqrt{N} \\le N$", "sqrt(N) <= N", "root and relation")
expectTeX("\\section{Warm up}", "# Warm up", "section")
expectTeX("\\begin{enumerate}\n\\item first\n\\item second\n\\end{enumerate}", "1. first", "enumerate")
expectTeX("\\begin{theorem}\nThere are infinitely many primes.\n\\end{theorem}", "theorem: There are infinitely many primes.", "theorem environment")
expectTeX("$\\begin{pmatrix} 1 & 2 \\\\ 3 & 4 \\end{pmatrix}$", "matrix [1, 2; 3, 4]", "matrix")
expectTeX("\\textbf{bold} and \\emph{italic}", "**bold** and *italic*", "text styling")
expectTeX("text % a comment", "text", "comments are dropped")
expectTeX("$\\mathbb{R}$", "reals", "blackboard bold")
expectTeX("\\maketitle\nBody text.", "Body text.", "layout-only commands are dropped")
expectTeX("$\\unknowncommand{x}$", "\\unknowncommand", "an unknown command is passed through")

// --- round trip: the editor's own document, exported and read back
checks += 1
let original = """
title: Round trip

# Section

The sum display(sum from k = 1 to n of k^2) and a fraction math(1/2).
"""
let exported = DocTranspiler.render(original).latex
let reimported = TeXImport.convert(exported).source
let rerendered = DocTranspiler.render(reimported).latex
for needle in ["\\sum_{k = 1}^{n} k^{2}", "\\frac{1}{2}", "\\section{Section}"] {
    if !rerendered.contains(needle) {
        failures += 1
        print("FAIL round trip lost \(needle)")
        print("  reimported: \(reimported)")
        break
    }
}

print("\(checks - failures)/\(checks) transpiler checks passed")
if failures > 0 { exit(1) }
