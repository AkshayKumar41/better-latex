# BetterLaTeX

*Boredom to the point of creation.*

A Mac app for writing mathematics in English. You type `sum from k = 1 to n of a^k x^k`;
a typeset page appears beside it; `Cmd-E` gives you a PDF. No LaTeX distribution, no
Node, no network, no account.

Built for a MacBook that should not notice the app is running: a 3.1MB bundle, about
0.35% of one core when idle, and roughly 60MB of private memory.

---

## Contents

- [Install and run](#install-and-run)
- [The window](#the-window)
- [Writing](#writing)
- [Your own shortcuts](#your-own-shortcuts)
- [Exporting](#exporting)
- [Keyboard](#keyboard)
- [Where files live](#where-files-live)
- [How it works](#how-it-works)
- [Performance](#performance)
- [Developing](#developing)
- [Limits and troubleshooting](#limits-and-troubleshooting)

---

## Install and run

```bash
./build.sh && open dist/BetterLaTeX.app
```

The build takes about 20 seconds and needs nothing installed beyond the Xcode Command
Line Tools. To keep the app around, drag `dist/BetterLaTeX.app` into `/Applications`
and double-click it like anything else on the Mac. It is ad-hoc signed, so Gatekeeper
allows it; there is no installer and nothing to uninstall but the bundle itself.

The app creates nothing on disk and opens no documents of its own. It launches on a
**Reference** tab: the complete syntax, typeset by the app itself, read-only. Your own
work needs a folder, so the sidebar asks for one before anything can be created or
edited - click **Choose Folder…**, point it at any directory, and that becomes the
project. The folder is remembered for next launch.

## The window

Three columns, each of which can be collapsed.

**Reference** is the first tab and cannot be closed or edited. It is the same document
as [COMMANDS.md](COMMANDS.md), rendered: every construct and every word, with the
mathematics typeset. `Cmd-Shift-/` returns to it from anywhere.

**Files** (left, `Cmd-B`) is the project folder, once you have chosen one. Until then it
shows a single action, and the new-file buttons stay disabled. Click a file to open it in a tab.
Right-click for new document, new folder, rename, reveal in Finder, and move to Trash
(the Trash, not an unlink, so a misclick is recoverable).

**Editor** (middle) holds the tabs. Text files are editable; PDFs open in a viewer;
images display; anything else offers a Reveal in Finder button. As you type, words the
converter recognizes turn brass and math regions get a faint tint, which is the feedback
loop for the language: **a word that stays grey is being treated as a plain variable**,
which is what you want for `x`, `y` and `theta`, and a warning for anything else.

**Folding** collapses lines you choose, so you can stop looking at everything. Select some
lines and either press `Control-Cmd--` or click the small grey arrow that appears in the
gutter beside the selection. The first line stays visible, followed by a `⋯ 4 lines` badge;
the rest is hidden. Click the brass arrow or the badge, or press `Control-Cmd-=`, to open it
again, and `Control-Shift-Cmd-=` opens everything. Nothing is detected automatically: a fold
is exactly the lines you selected. Folding never changes the document - the text, the
preview and the export all still see every character. A fold is released if you edit
inside it, and moves with the text if you edit above it. Folds last for the session, not
after quitting.

**Page** (right, `Cmd-R`) is the rendered document, redrawn about 70ms after you stop
typing. It scrolls to follow the cursor. The paper keeps letter proportions at every pane
width: narrowing the pane zooms the page out rather than reflowing the text into a
skinnier column, the way a PDF viewer behaves. Pinch to zoom further.

**Meter** (corner, `Cmd-Shift-M`) shows what the app is costing you right now: processor
time per second, memory footprint, and how long the last redraw took, with a sparkline of
recent processor use. It counts this process; WebKit's renderer is a separate helper.

Files save themselves about 1.2 seconds after you stop typing, and on quit.

## Writing

A document is plain text with light structure:

```
title: On Prime Numbers
author: A. Kumar

# The idea

Every integer math(n > 1) has a prime factor, so display(sum from k = 1 to n of a^k x^k)
converges whenever math(abs(x) < 1).

theorem: There are infinitely many primes.

proof: Suppose not, and let math(N = product from i = 1 to n of p_i + 1).
```

**To break a line inside mathematics, press return.** A newline inside `display(...)`,
`equation(...)` or `align(...)` starts a new row, aligned on its relation, so

```
display(
(a + b)^2 = a^2 + 2 a b + b^2
(a - b)^2 = a^2 - 2 a b + b^2
)
```

sets two aligned lines. Writing `\\` instead of a newline does the same thing, for the
LaTeX habit. A single-line block stays a single centred formula.

**To break a line inside mathematics, press return.** A newline inside `display(...)`,
`equation(...)` or `align(...)` starts a new row, aligned on its relation:

```
display(
(a + b)^2 = a^2 + 2 a b + b^2
(a - b)^2 = a^2 - 2 a b + b^2
)
```

Writing `\\` instead of a newline does the same, for the LaTeX habit. A single-line block
stays one centred formula.

Four constructs put mathematics on the page: `math(...)` inline, `display(...)` on its
own line, `equation(...)` numbered, `align(...)` with one row per source line aligned on
its relation. `$x^2$` and `$$x^2$$` work too. A leading backslash switches any construct
off, so `\math(x)` stays as text, and anything inside backticks is shown rather than run.

The rules worth memorising:

| | |
|---|---|
| `/` | fraction, binding tighter than `+` and implicit multiplication |
| `//` | a literal slash |
| `^` | power, taking one letter, so `a^kx^k` means two factors |
| `_` | subscript, taking a whole word, so `x_max` is one name |
| `(...)` | grouping; dropped inside a fraction, so `(a+b)/(c+d)` looks right |
| `{...}` | silent grouping after `^` or `_`, as in LaTeX; a set anywhere else |
| `\command` | raw LaTeX, passed straight through |

Everything else is English: `for all s in S`, `there exists x in reals such that x^2 = 2`,
`integral from 0 to 1 of x^2 dx`, `limit as n -> infinity of (1 + 1/n)^n`,
`matrix [1, 2; 3, 4]`, `cases {x^2 if x >= 0; -x^2 otherwise}`, `n choose k`,
`derivative of f with respect to x`, `A transpose`, `sqrt of x`, `vec v dot vec w`.

Indentation is deliberate rather than ignored: a paragraph that starts with a tab or two
spaces is indented as a block, four spaces indents it twice as far, and `box:` at the
start of a paragraph puts it in a frame. Inside mathematics, `boxed(E = m c^2)` frames a
formula. Exports use `\leftskip` and `\fbox{\begin{minipage}...}`, so the `.tex` compiles
anywhere without extra packages.

Line endings follow LaTeX, not a word processor: a plain newline keeps flowing in the
same paragraph, a blank line starts a new paragraph, and a line ending in a backslash (or
two spaces, if that is the habit you have) forces a break without starting a paragraph.
Inside `align(...)`, one source line is one row.

Indentation is deliberate rather than ignored. A paragraph starting with a tab or two
spaces is indented as a block (four spaces indents twice as far), and `box:` at the start
of a paragraph frames it. Inside mathematics, `boxed(E = m c^2)` frames just the formula.
Both export without extra packages, as `\leftskip` and `\fbox{\begin{minipage}...}`.

A `box:` never splits across a page unless it is genuinely taller than one whole page - it
either fits, or moves whole onto the next page, the same as a table or a display equation.
An oversized box has no page to fit on, so it rolls over freely at that point, still
breaking only at a safe line boundary rather than through a glyph.

Lists come in three kinds: `- ` bullets, `1. ` numbers, and `A. ` / `a) ` / `(a) ` letters.
A lettered item keeps the letter you wrote rather than renumbering, and one written under a
numbered item becomes a sub-part of it, so a problem set reads the way it is written:

```
1. Find a closed-form expression for each sequence.

A. math(a_n = 4^n + 2 cdot 3^n).

B. math(b_n = binom(n + 2, 2) 2^n).
```

Document structure is Markdown-shaped: `#` headings, `-` and `1.` lists, `> ` quotes,
`|a|b|` tables, `**bold**`, `*italic*`, fenced code blocks, `[label](url)` links, and
`title:` / `author:` / `date:` / `abstract:` front matter. Starting a paragraph with
`theorem:`, `lemma:`, `definition:`, `proof:`, `remark:` and friends sets it as that
environment, numbered the way LaTeX would.

**[COMMANDS.md](COMMANDS.md) lists every word the app knows** — 110 phrases, 142 words,
44 prefix constructs, 20 big operators, 25 functions, the Greek alphabet and 30 symbol
sequences, each with the LaTeX it produces. That file is generated from the transpiler's
own tables by `./build.sh docs`, so it cannot drift from the code.

## Your own shortcuts

`Cmd-Shift-K` opens a sheet: type a trigger, type what it should expand to, watch the
LaTeX preview, press Add. The shortcut works immediately, in every document, and after a
restart. If text is selected in the editor when you open the sheet, it is prefilled as
the expansion.

Everything lives in one plain text file:

```
~/Library/Application Support/BetterLaTeX/shortcuts.conf
```

```
# one per line: trigger = what it expands to
qed = blacksquare
hess = matrix [f_xx, f_xy; f_yx, f_yy]
grad f = nabla f
```

The right side is ordinary BetterLaTeX English, so a shortcut can be a whole structure,
can use other shortcuts (three levels deep), and can contain raw LaTeX. Triggers may be
several words, and may contain digits (`chi2` matches before `chi`). Your shortcuts are consulted before the built-in tables, so you can
redefine any word the app ships with. Saving the file — in this app or any editor —
updates open documents on the next keystroke.

Shortcuts menu: **Add Shortcut** (`Cmd-Shift-K`), **Edit Shortcuts File** (opens it as a
tab here), **Reload Shortcuts**. The sheet also lists what you have defined, with a trash
icon per entry.

## Importing

`Cmd-Shift-I` converts a **PDF** or a **`.tex` file** into English you can edit. Opening
either kind in a tab also shows a **Convert to English** button above it. The result is
written beside the original as `<name>.bltx` and opened in a tab.

### From LaTeX source

A `.tex` file converts directly, because this is the transpiler run backwards, and the
vocabulary is inverted from the same tables it uses, so the two stay in step:

| LaTeX | Imported as |
|---|---|
| `\sum_{n \ge 0} a_n x^n` | `sum over n >= 0 of a_n x^n` |
| `\frac{1}{1-4x}` | `1/(1 - 4 x)` |
| `\binom{n+2}{2}` | `binom(n + 2, 2)` |
| `\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}` | `matrix [1, 2; 3, 4]` |
| `\section{Warm up}` | `# Warm up` |
| `\begin{theorem}...\end{theorem}` | `theorem: ...` |
| `\textbf{x}`, `\emph{x}`, `\href{u}{t}` | `**x**`, `*x*`, `[t](u)` |

The preamble supplies `title:`, `author:` and `date:`; comments and layout-only commands
(`\maketitle`, `\noindent`, `\vfill`) are dropped; and **any command the importer does not
know is left as LaTeX**, which the editor passes straight through and still renders. That
is the safety valve: an import never silently loses content.

A `.tex` file opened in the app is shown as source rather than previewed as English,
since raw LaTeX is not the language the preview reads.

### From a PDF

PDF import works by reading the glyphs the PDF actually draws - their font, size and position -
and decoding them through each font's embedded character map, so it is not tied to one
producer. The font a glyph is drawn in says what it is: Computer Modern Roman is prose,
CMMI is a variable or a Greek letter, CMSY a relation, CMEX a big operator or delimiter.
Size and baseline offset give superscripts and subscripts, a thin drawn rule gives a
fraction, glyphs stacked inside big parentheses give a binomial, and small glyphs centred
under a sigma give its limits. Those are turned back into the same English the editor
accepts, so `\sum_{n\ge0} a_n x^n` comes back as `sum over n >= 0 of a_n x^n`.

On a LaTeX-produced problem set, expect the prose to come back verbatim, with hyphenated
line breaks rejoined, and most mathematics to come back correct:

| From the PDF | Imported as |
|---|---|
| a Σ with limits and arguments | `math(sum over n >= 0 of a_n x^n)` |
| a binomial identity | `display(sum from j = 0 to n of binom(r + j - 1, r - 1) binom(s + n - j - 1, s - 1) = binom(r + s + n - 1, r + s - 1).)` |
| subscripts and powers | `math(a_n = 4^n + 2 cdot 3^n)` |

**Treat the result as a draft, not a conversion you can trust unread.** Every imported
file starts with a comment line saying so, along with the page and formula count. What
works and what does not:

| Input | Result |
|---|---|
| pdfLaTeX / XeLaTeX with embedded character maps | prose verbatim, most mathematics correct |
| Word, Google Docs, most exporters | prose good, mathematics weaker |
| a PDF with no character maps | text may be wrong; the file says so in a comment |
| scanned or handwritten pages | nothing to recover - there is no text, only pixels |

Structure is recovered too: the title, paragraph breaks taken from the document's own line
spacing, problem numbering kept exactly as written, centred equations as `display(...)`,
and page numbers dropped.

## Exporting

`Cmd-E` writes a PDF: letter paper, 1in margins, selectable text, embedded fonts, page
breaks that fall between blocks rather than through an equation. It is produced from the
same page you are looking at, so what you see is what you get.

`Cmd-Shift-E` writes the generated `.tex` source with a full preamble (`amsmath`,
`amssymb`, `amsthm`, `mathtools`, `geometry`, `hyperref`, theorem environments). That file
compiles in any LaTeX distribution, so the English you type is never a dead end — hand it
to Overleaf, a journal, or a co-author who wants the source.

## Keyboard

| Key | Action |
|---|---|
| `Cmd-N` | new document |
| `Cmd-O` | open a project folder |
| `Cmd-S` | save now |
| `Cmd-E` | export PDF |
| `Cmd-Shift-E` | export the `.tex` source |
| `Cmd-W` | close the current tab |
| `Cmd-Shift-K` | add a shortcut |
| `Cmd-Shift-I` | convert a PDF or `.tex` file into an editable document |
| `Control-Cmd--` | fold the selected lines |
| `Control-Cmd-=` | unfold the fold at the cursor |
| `Control-Shift-Cmd-=` | unfold everything |
| `Cmd-Shift-/` | back to the reference |
| `Cmd-B` | show or hide the file list |
| `Cmd-R` | show or hide the rendered page |
| `Cmd-Shift-M` | show or hide the performance meter |
| `Cmd-Shift-]` / `Cmd-Shift-[` | next / previous document |
| `Cmd-F` | find in the editor |
| `Tab` | two spaces |
| `(` | auto-closes |

## Where files live

| Path | What |
|---|---|
| `~/Library/Application Support/BetterLaTeX/shortcuts.conf` | your shortcuts, the only file the app creates |
| `dist/BetterLaTeX.app` | the built app |
| anywhere | your projects: whatever folder you link, remembered between launches |

Documents are yours: plain UTF-8 text, `.bltx` by convention but `.txt` and `.md` open the
same way. Nothing is stored in a database and nothing leaves the machine.

## How it works

```
Sources/Import/        TeXImport.swift      LaTeX source back into English
                       PDFText.swift        glyph extraction and character maps
                       PDFLayout.swift      rows, scripts, fractions, operators
                       PDFToEnglish.swift   structure back into English
Sources/Transpile/     Symbols.swift        the word tables
                       MathTranspiler.swift lexer + recursive-descent emitter
                       DocTranspiler.swift  document structure, HTML and LaTeX back ends
                       UserSymbols.swift    your shortcuts file
Sources/App/           Folding.swift       which lines are folded, and keeping that honest
                       FoldingTextView.swift the gutter arrows and the fold badge
                       Workspace.swift      folder, tabs, render pipeline, saving
                       EditorView.swift     NSTextView + incremental highlighter
                       PreviewView.swift    the long-lived WebKit view
                       PDFExport.swift      render once, slice into pages
                       PerfMeter.swift      the cost readout
                       RootView.swift       layout, sidebar, tabs, status bar
                       ShortcutsUI.swift    the Add Shortcut sheet
                       Palette.swift        colours for both appearances
Resources/preview.html the page shell, KaTeX bootstrap, page-break measuring
Resources/katex/       KaTeX 0.16.22 and 20 woff2 fonts, vendored
tools/                 icon generator, reference generator, headless verifier
tests/main.swift       63 transpiler checks, run on every build
```

1. **Typing** goes into an `NSTextView`. The highlighter re-scans only the paragraph
   block around the edit.
2. **Rendering** is debounced 70ms, runs on a background queue, and is skipped entirely if
   the text has not changed. The transpiler walks the source once and emits HTML for the
   preview and LaTeX for export from the same pass.
3. **The preview** is one long-lived WebKit view that the app owns, so hiding the pane
   never reloads it. Rendered formulas are cached in the page by their source text, so
   editing one line re-renders one formula.
4. **PDF export** renders the document once in an offscreen view at an exact 624px column,
   asks the page where its blocks end, and draws those slices into letter pages. WebKit's
   own print path is deliberately unused: it hangs on a windowless view and, when it does
   run, paginates a document like this into gigabytes.
5. **Nothing polls.** Every timer is a one-shot work item; the only repeating timer in the
   app is the 1Hz performance meter, which stops when you hide it.

## Performance

Measured on this machine, M-series, macOS 26:

| | |
|---|---|
| Bundle | 2.8 MB |
| Idle processor | 0.07s of CPU over 20s, about 0.35% of one core |
| Memory | ~60 MB private (157 MB RSS including shared system frameworks) |
| Transpile | 2.3 ms for a 6 KB document with 113 formulas |
| Typing, main thread | about 1.5 ms per character at 7 KB, 2.5 ms at 35 KB (measured by typing into the real editor) |
| Keystroke to repaint | 70 ms debounce + about 7 ms redraw |
| Cold first render | 70–100 ms, including font load |
| PDF export | 6 pages in well under a second |

`./build.sh test` runs the transpiler checks in about a second.

## Developing

| Command | What it does |
|---|---|
| `./build.sh` | run the tests, build the icon if missing, compile, bundle, sign |
| `./build.sh test` | transpiler checks only |
| `./build.sh docs` | regenerate `COMMANDS.md` from the symbol tables |
| `./build.sh clean` | remove `build/` and `dist/` |

The tests gate the build: if a check fails, no app is produced. To add vocabulary, add a
line to the table in `Sources/Transpile/Symbols.swift`, add a check in `tests/main.swift`,
and run `./build.sh docs` so the reference follows. To add vocabulary *without* touching
the code, use a shortcut (`Cmd-Shift-K`) instead.

`tools/Verify` is a headless harness that renders a document through the real bundle and
reports how many formulas rendered, how many failed, and what the PDF came out as:

```bash
swiftc -O Sources/Transpile/*.swift Sources/App/PDFExport.swift tools/Verify/main.swift -o build/verify
./build/verify dist/BetterLaTeX.app/Contents/Resources Resources/sample/welcome.bltx /tmp/out.pdf
```

## Limits and troubleshooting

- **Coverage.** The renderer is KaTeX: essentially all of `amsmath` inline and display
  mathematics, but no TikZ, no custom `\newcommand` macros, no bibliographies, no figure
  floats. For those, export the `.tex` and compile it.
- **`.tex` files** opened here are read as English, not as LaTeX. Backslash commands pass
  through, so formulas survive, but a real preamble will not render.
- **A red formula** in the preview means KaTeX rejected it; the error text is the message.
  Usually it is an unknown backslash command or an unbalanced brace.
- **A word rendered as separate letters** was not recognized, so it was treated as a
  product of variables. Check [COMMANDS.md](COMMANDS.md), or define it as a shortcut.
- **The app will not open** after being moved between machines: right-click, Open, or
  rebuild it locally with `./build.sh`.
- **Nothing in the preview** immediately after launch means the page is still loading;
  it fills in as soon as the first render completes.
