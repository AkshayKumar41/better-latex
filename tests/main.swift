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

print("\(checks - failures)/\(checks) transpiler checks passed")
if failures > 0 { exit(1) }
