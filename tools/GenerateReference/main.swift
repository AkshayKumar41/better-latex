// Emits COMMANDS.md from the live symbol tables, so the reference cannot drift
// from the transpiler. Run: ./build.sh docs
import Foundation

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "COMMANDS.md")
var md = ""

func line(_ s: String = "") { md += s + "\n" }

/// Table cells are code spans; a pipe inside one still splits the row.
func cell(_ s: String) -> String { "`" + s.replacingOccurrences(of: "|", with: "\\|") + "`" }

func rendered(_ input: String) -> String { cell(MathParser.latex(input)) }

func table(_ rows: [(String, String)], head: (String, String) = ("You type", "LaTeX produced")) {
    line("| \(head.0) | \(head.1) |")
    line("|---|---|")
    for (a, b) in rows { line("| \(a) | \(b) |") }
    line()
}

/// Examples for words whose meaning is structural rather than a single symbol.
let examples: [String: String] = [
    "divided by": "x divided by y", "over": "a over b", "out of": "3 out of 4",
    "square root of": "square root of x", "the square root of": "the square root of x",
    "sqrt of": "sqrt of x", "cube root of": "cube root of 8",
    "absolute value of": "absolute value of x",
    "with respect to": "derivative of f with respect to x",
    "derivative of": "derivative of f with respect to x",
    "second derivative of": "second derivative of y with respect to x",
    "partial derivative of": "partial derivative of u with respect to t",
    "double integral": "double integral over D of f dA",
    "triple integral": "triple integral over V of f dV",
    "contour integral": "contour integral over C of f dz",
    "line integral": "line integral over C of f ds",
    "big union": "big union from i = 1 to n of A_i",
    "big intersection": "big intersection from i = 1 to n of A_i",
    "bracket matrix": "bracket matrix [1, 0; 0, 1]",
    "brace matrix": "brace matrix [1, 0; 0, 1]",
    "det matrix": "det matrix [a, b; c, d]",
    "determinant of the matrix": "determinant of the matrix [a, b; c, d]",
    "n choose k": "n choose k", "n factorial": "n factorial",
    "the": "x in the reals", "an": "an x", "is": "n is 5",
    "are": "x are y", "be": "x be y",
    "of": "f of x", "as": "limit as x -> 0 of f(x)",
    "from": "sum from k = 1 to n of a_k", "choose": "n choose k",
    "at": "f at x", "where": "f(x) where x > 0",
    "if": "cases {1 if x > 0; 0 otherwise}",
    "otherwise": "cases {1 if x > 0; 0 otherwise}",
    "else": "cases {1 if x > 0; 0 else}",
    "squared": "x squared", "cubed": "y cubed", "inverse": "A inverse",
    "transpose": "A transpose", "complement": "A complement",
    "factorial": "n factorial", "conjugate": "z conjugate", "adjoint": "A adjoint",
    "root": "root 3 of 8", "sqrt": "sqrt of x",
    "matrix": "matrix [1, 2; 3, 4]", "pmatrix": "pmatrix [1, 2; 3, 4]",
    "bmatrix": "bmatrix [1, 2; 3, 4]", "vmatrix": "vmatrix [a, b; c, d]",
    "determinant": "determinant [a, b; c, d]",
    "cases": "cases {1 if x > 0; 0 otherwise}",
    "set": "set(1, 2, 3)", "inner": "inner(u, v)", "ip": "ip(u, v)",
    "binom": "binom(n, k)", "binomial": "binomial(n, k)",
    "abs": "abs(x)", "magnitude": "magnitude(v)", "norm": "norm(v)", "length": "length(v)",
    "floor": "floor(x)", "ceil": "ceil(x)", "ceiling": "ceiling(x)", "round": "round(x)",
    "overbrace": "overbrace(a + b)", "underbrace": "underbrace(a + b)",
    "boxed": "boxed(E = m c^2)", "cancel": "cancel(x)",
]

func example(for word: String) -> String { examples[word] ?? "\(word) x" }

line("# Every command BetterLaTeX knows")
line()
line("Generated from the transpiler's own tables by `./build.sh docs`, so this list is")
line("exactly what the app implements - nothing here is written by hand.")
line()
line("Left column is what you type inside `math(...)`, `display(...)`, `equation(...)`")
line("or `align(...)`. Right column is the LaTeX it becomes, which is also what the")
line("preview renders and what `Cmd-Shift-E` writes out.")
line()
line("## Contents")
line()
line("1. [Constructs](#constructs)")
line("2. [Document structure](#document-structure)")
line("3. [Keyboard](#keyboard)")
line("4. [Grouping and precedence](#grouping-and-precedence)")
line("5. [Symbols you type directly](#symbols-you-type-directly)")
line("6. [Big operators](#big-operators)")
line("7. [Prefix constructs](#prefix-constructs)")
line("8. [Structural words](#structural-words)")
line("9. [Phrases](#phrases)")
line("10. [Single words](#single-words)")
line("11. [Functions](#functions)")
line("12. [Greek letters](#greek-letters)")
line("13. [Your own shortcuts](#your-own-shortcuts)")
line()

// MARK: constructs
line("## Constructs")
line()
table([
    ("`math(...)`, `m(...)`", "mathematics inside a line"),
    ("`display(...)`, `block(...)`, `displaymath(...)`", "mathematics on its own line"),
    ("`equation(...)`, `eq(...)`", "the same, with an equation number"),
    ("`align(...)`, `aligned(...)`, `gather(...)`", "one row per source line, aligned on the relation"),
    ("`latex(...)`, `tex(...)`", "raw LaTeX, passed through untouched"),
    ("`code(...)`, `verb(...)`, `mono(...)`", "literal monospace text"),
    ("`text(...)`, `word(...)`", "words inside mathematics (also `\"quoted text\"`)"),
    ("`$x^2$`, `$$x^2$$`", "inline and display math, for habit"),
    ("`\\math(x)`", "a leading backslash switches any construct off"),
    ("`` `math(x)` ``", "anything inside backticks is shown, never executed"),
], head: ("Construct", "What it does"))

// MARK: document
line("## Document structure")
line()
table([
    ("`title:`, `author:`, `date:`, `abstract:`, `keywords:`", "front matter, at the top of the file"),
    ("`#`, `##`, `###`, `####`", "section, subsection, subsubsection, paragraph"),
    ("`- `, `* `, `+ `", "bullet list; indent two spaces to nest"),
    ("`1. `, `1) `", "numbered list"),
    ("blank line", "new paragraph"),
    ("plain newline", "keeps flowing in the same paragraph, like LaTeX"),
    ("backslash at end of line", "forced line break inside the paragraph"),
    ("two spaces at end of line", "the same, for Markdown habit"),
    ("`> `", "block quotation"),
    ("`---`, `***`", "horizontal rule"),
    ("three backticks", "verbatim code block"),
    ("`| a | b |`", "table row; a `|---|` row marks the header"),
    ("`**bold**`", "bold"),
    ("`*italic*`", "italic"),
    ("`` `code` ``", "monospace"),
    ("`[label](https://url)`", "link"),
    ("`theorem:`", "starts the paragraph as a theorem environment"),
    ("`lemma:`, `corollary:`, `proposition:`, `claim:`", "the same, numbered with theorems"),
    ("`definition:`, `example:`", "definition-style environments"),
    ("`proof:`, `remark:`, `note:`", "unnumbered environments"),
], head: ("You write", "You get"))

// MARK: keyboard
line("## Keyboard")
line()
table([
    ("`Cmd-N`", "new document in the current folder"),
    ("`Cmd-O`", "open a project folder"),
    ("`Cmd-S`", "save now (files also save themselves ~1.2s after you stop typing)"),
    ("`Cmd-E`", "export PDF"),
    ("`Cmd-Shift-E`", "export the generated `.tex` source"),
    ("`Cmd-W`", "close the current tab"),
    ("`Cmd-B`", "show or hide the file list"),
    ("`Cmd-R`", "show or hide the rendered page"),
    ("`Cmd-Shift-M`", "show or hide the performance meter"),
    ("`Cmd-Shift-/`", "back to this reference, which is always the first tab"),
    ("`Cmd-Shift-]`", "next document"),
    ("`Cmd-Shift-[`", "previous document"),
    ("`Cmd-F`", "find in the editor"),
    ("`Cmd-Z`", "undo"),
    ("`Tab`", "inserts two spaces"),
    ("`(`", "auto-closes; typing `)` over a closing paren steps past it"),
], head: ("Key", "Action"))

// MARK: grouping
line("## Grouping and precedence")
line()
table([
    ("1/2", rendered("1/2")),
    ("1//2", rendered("1//2")),
    ("(a+b)/(c+d)", rendered("(a+b)/(c+d)")),
    ("x + 1/y", rendered("x + 1/y")),
    ("a b / c d", rendered("a b / c d")),
    ("a^kx^k", rendered("a^kx^k")),
    ("x_max", rendered("x_max")),
    ("a_ij", rendered("a_ij")),
    ("x^{n+1}", rendered("x^{n+1}")),
    ("e^(2 pi i)", rendered("e^(2 pi i)")),
    ("{1, 2, 3}", rendered("{1, 2, 3}")),
    ("[0, 1]", rendered("[0, 1]")),
    ("|x - y|", rendered("|x - y|")),
    ("sin x / x", rendered("sin x / x")),
    ("\\sqrt{2}", rendered("\\sqrt{2}")),
])
line("Rules in one line each:")
line()
line("- `/` is a fraction and binds tighter than `+` or implicit multiplication; `//` is a literal slash.")
line("- `_` takes a whole word, `^` takes one letter, so `a^kx^k` stays two factors and `x_max` stays one name.")
line("- Parentheses are dropped inside a fraction, kept everywhere else.")
line("- `{...}` right after `^` or `_` groups silently, as in LaTeX; anywhere else it is a set.")
line("- A function takes the next unit as its argument.")
line("- A backslash command passes through with LaTeX's own grouping.")
line()

// MARK: operators
line("## Symbols you type directly")
line()
table(Sym.operators.filter { $0.0.count > 1 || "+-=<>:,;&".contains($0.0) == false || true }
    .map { (cell($0.0), cell($0.1)) }, head: ("You type", "Becomes"))
line("`//` is a literal slash, `/` is a fraction, `^` and `_` are scripts, `!` is a factorial, `'` is a prime.")
line()

// MARK: big operators
line("## Big operators")
line()
line("Each one takes `from ... to ... of`, `over ... of`, or `as ... of`. Written alone it")
line("still accepts `_` and `^` limits.")
line()
table(Sym.bigOps.keys.sorted().map { key in
    let ex = "\(key) from a to b of f"
    return (cell(ex), rendered(ex))
})
table([("double integral", rendered("double integral over D of f dA")),
       ("triple integral", rendered("triple integral over V of f dV")),
       ("contour integral", rendered("contour integral over C of f dz")),
       ("big union", rendered("big union from i = 1 to n of A_i")),
       ("big intersection", rendered("big intersection from i = 1 to n of A_i")),
       ("limit as x -> 0 of f(x)", rendered("limit as x -> 0 of f(x)")),
       ("sum over k in S of a_k", rendered("sum over k in S of a_k"))].map { (cell($0.0), $0.1) })

// MARK: prefix ops
line("## Prefix constructs")
line()
line("These take either a bracketed group or the next single unit; `of` is optional.")
line()
table(Sym.prefixOps.keys.sorted().map { key in
    let ex = example(for: key)
    return (cell(ex), rendered(ex))
})

// MARK: markers
let markerWords = Sym.words.filter { $0.value.hasPrefix("@") }.keys.sorted()
let markerPhrases = Sym.phrases.filter { $0.value.hasPrefix("@") }.keys.sorted()
line("## Structural words")
line()
line("Words that change the shape of what is around them rather than standing for one symbol.")
line()
table((markerPhrases + markerWords).map { key in
    let ex = example(for: key)
    return (cell(ex), rendered(ex))
})
line("`the` and `an` are dropped; `is`, `are` and `be` become an equals sign. `as`, `from`,")
line("`at` and `where` are limit words for big operators - used anywhere else they print as")
line("upright text.")
line()

// MARK: phrases
let plainPhrases = Sym.phrases.filter { !$0.value.hasPrefix("@") }.keys.sorted()
line("## Phrases")
line()
line("\(plainPhrases.count) multi-word phrases, matched greedily before single words.")
line()
table(plainPhrases.map { (cell($0), rendered($0)) })

// MARK: words
let plainWords = Sym.words.filter { !$0.value.hasPrefix("@") }.keys.sorted()
line("## Single words")
line()
line("\(plainWords.count) words. Anything not in this list is treated as a variable, which is")
line("why unknown words stay grey in the editor.")
line()
table(plainWords.map { (cell($0), rendered($0)) })

// MARK: functions
line("## Functions")
line()
line("Set upright, and each takes the next unit as its argument.")
line()
table(Sym.functions.sorted().map { fn in
    let ex = "\(fn) x"
    return (cell(ex), rendered(ex))
})

// MARK: greek
line("## Greek letters")
line()
line("Write the name; capitalise the name for the capital letter.")
line()
table((Sym.greekLower.sorted() + Sym.greekUpper.sorted()).map { (cell($0), rendered($0)) })

line("## Your own shortcuts")
line()
line("`Cmd-Shift-K` opens a sheet: type a trigger, type what it should expand to, press Add.")
line("The shortcut is written to a file and works in every document from that moment on,")
line("including after a restart.")
line()
line("```")
line("~/Library/Application Support/BetterLaTeX/shortcuts.conf")
line("```")
line()
line("The file is plain text, one shortcut per line:")
line()
line("```")
line("# lines starting with # are ignored")
line("qed = blacksquare")
line("hess = matrix [f_xx, f_xy; f_yx, f_yy]")
line("grad f = nabla f")
line("R = reals")
line("```")
line()
table([
    ("Right side", "ordinary BetterLaTeX English, so `hess` above becomes a real matrix"),
    ("Other shortcuts", "usable inside a shortcut, up to three levels deep"),
    ("Raw LaTeX", "works too, because backslash commands pass through"),
    ("Multi-word triggers", "allowed: `grad f = nabla f` matches those two words together"),
    ("Digits in triggers", "allowed: `chi2 = chi^2` matches `chi2` before it matches `chi`"),
    ("Precedence", "your shortcuts win over the built-in tables, so you can redefine any word"),
    ("Reload", "saving the file updates open documents on the next keystroke; no restart"),
    ("Editing by hand", "Shortcuts menu, Edit Shortcuts File, opens it as a tab in the app"),
    ("Deleting", "the trash icon in the Add Shortcut sheet, or delete the line"),
], head: ("Detail", "Behaviour"))

line("---")
line()
line("Counts: \(Sym.phrases.count) phrases, \(Sym.words.count) words, \(Sym.prefixOps.count) prefix constructs, \(Sym.bigOps.count) big operators, \(Sym.functions.count) functions, \(Sym.greekLower.count + Sym.greekUpper.count) greek letters, \(Sym.operators.count) symbol sequences.")

try! md.write(to: out, atomically: true, encoding: .utf8)
print("wrote \(out.lastPathComponent): \(md.components(separatedBy: "\n").count) lines")
