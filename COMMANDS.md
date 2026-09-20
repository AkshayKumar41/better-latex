# Every command BetterLaTeX knows

Generated from the transpiler's own tables by `./build.sh docs`, so this list is
exactly what the app implements - nothing here is written by hand.

Left column is what you type inside `math(...)`, `display(...)`, `equation(...)`
or `align(...)`. Right column is the LaTeX it becomes, which is also what the
preview renders and what `Cmd-Shift-E` writes out.

## Contents

1. [Constructs](#constructs)
2. [Document structure](#document-structure)
3. [Keyboard](#keyboard)
4. [Grouping and precedence](#grouping-and-precedence)
5. [Symbols you type directly](#symbols-you-type-directly)
6. [Big operators](#big-operators)
7. [Prefix constructs](#prefix-constructs)
8. [Structural words](#structural-words)
9. [Phrases](#phrases)
10. [Single words](#single-words)
11. [Functions](#functions)
12. [Greek letters](#greek-letters)
13. [Your own shortcuts](#your-own-shortcuts)

## Constructs

| Construct | What it does |
|---|---|
| `math(...)`, `m(...)` | mathematics inside a line |
| `display(...)`, `block(...)`, `displaymath(...)` | mathematics on its own line |
| `equation(...)`, `eq(...)` | the same, with an equation number |
| `align(...)`, `aligned(...)`, `gather(...)` | one row per source line, aligned on the relation |
| a newline inside any display block | a new row, aligned on the relation; `\\` does the same |
| a newline inside any display block | a new row, aligned on the relation; `\\` does the same |
| `latex(...)`, `tex(...)` | raw LaTeX, passed through untouched |
| `code(...)`, `verb(...)`, `mono(...)` | literal monospace text |
| `text(...)`, `word(...)` | words inside mathematics (also `"quoted text"`) |
| `$x^2$`, `$$x^2$$` | inline and display math, for habit |
| `\math(x)` | a leading backslash switches any construct off |
| `` `math(x)` `` | anything inside backticks is shown, never executed |

## Document structure

| You write | You get |
|---|---|
| `title:`, `author:`, `date:`, `abstract:`, `keywords:` | front matter, at the top of the file |
| `#`, `##`, `###`, `####` | section, subsection, subsubsection, paragraph |
| `- `, `* `, `+ ` | bullet list; indent two spaces to nest |
| `A. `, `a) `, `(a) ` | lettered list, keeping the letter you wrote; written under a numbered item it becomes a sub-part |
| `1. `, `1) ` | numbered list |
| blank line | new paragraph |
| plain newline | keeps flowing in the same paragraph, like LaTeX |
| backslash at end of line | forced line break inside the paragraph |
| two spaces at end of line | the same, for Markdown habit |
| a tab or two spaces before a paragraph | indents the whole block; four spaces indents twice as far |
| `box:` | puts the paragraph in a frame |
| a tab or two spaces before a paragraph | indents the whole block; four spaces indents twice as far |
| `box:` | puts the paragraph in a frame |
| `> ` | block quotation |
| `---`, `***` | horizontal rule |
| three backticks | verbatim code block |
| `| a | b |` | table row; a `|---|` row marks the header |
| `**bold**` | bold |
| `*italic*` | italic |
| `` `code` `` | monospace |
| `[label](https://url)` | link |
| `theorem:` | starts the paragraph as a theorem environment |
| `lemma:`, `corollary:`, `proposition:`, `claim:` | the same, numbered with theorems |
| `definition:`, `example:` | definition-style environments |
| `proof:`, `remark:`, `note:` | unnumbered environments |

## Keyboard

| Key | Action |
|---|---|
| `Cmd-N` | new document in the current folder |
| `Cmd-O` | open a project folder |
| `Cmd-S` | save now (files also save themselves ~1.2s after you stop typing) |
| `Cmd-E` | export PDF |
| `Cmd-Shift-E` | export the generated `.tex` source |
| `Cmd-W` | close the current tab |
| `Cmd-B` | show or hide the file list |
| `Cmd-R` | show or hide the rendered page |
| `Cmd-Shift-M` | show or hide the performance meter |
| `Cmd-Shift-K` | add a shortcut of your own |
| `Cmd-Shift-I` | convert a PDF or .tex file into an editable document |
| `Control-Cmd--` | fold the selected lines |
| `Control-Cmd-=` | unfold the fold at the cursor |
| `Control-Shift-Cmd-=` | unfold everything |
| `Cmd-Shift-/` | back to this reference, which is always the first tab |
| `Cmd-Shift-]` | next document |
| `Cmd-Shift-[` | previous document |
| `Cmd-F` | find in the editor |
| `Cmd-Z` | undo |
| `Tab` | inserts two spaces |
| `(` | auto-closes; typing `)` over a closing paren steps past it |

## Grouping and precedence

| You type | LaTeX produced |
|---|---|
| 1/2 | `\frac{1}{2}` |
| 1//2 | `1 / 2` |
| (a+b)/(c+d) | `\frac{a + b}{c + d}` |
| x + 1/y | `x + \frac{1}{y}` |
| a b / c d | `a \frac{b}{c} d` |
| a^kx^k | `a^{k} x^{k}` |
| x_max | `x_{\mathrm{max}}` |
| a_ij | `a_{ij}` |
| x^{n+1} | `x^{n + 1}` |
| e^(2 pi i) | `e^{2 \pi i}` |
| {1, 2, 3} | `\left\{ 1 , 2 , 3 \right\}` |
| [0, 1] | `\left[ 0 , 1 \right]` |
| |x - y| | `\left\| x - y \right\|` |
| sin x / x | `\frac{\sin x}{x}` |
| \sqrt{2} | `\sqrt {2}` |

Rules in one line each:

- `/` is a fraction and binds tighter than `+` or implicit multiplication; `//` is a literal slash.
- `_` takes a whole word, `^` takes one letter, so `a^kx^k` stays two factors and `x_max` stays one name.
- Parentheses are dropped inside a fraction, kept everywhere else.
- `{...}` right after `^` or `_` groups silently, as in LaTeX; anywhere else it is a set.
- A function takes the next unit as its argument.
- A backslash command passes through with LaTeX's own grouping.

## Symbols you type directly

| You type | Becomes |
|---|---|
| `<=>` | `\Leftrightarrow` |
| `<->` | `\leftrightarrow` |
| `\|->` | `\mapsto` |
| `...` | `\dots` |
| `>=` | `\ge` |
| `<=` | `\le` |
| `->` | `\to` |
| `=>` | `\Rightarrow` |
| `!=` | `\ne` |
| `==` | `\equiv` |
| `~=` | `\approx` |
| `+-` | `\pm` |
| `-+` | `\mp` |
| `<<` | `\ll` |
| `>>` | `\gg` |
| `:=` | `\mathrel{:=}` |
| `*` | `\cdot` |
| `~` | `\sim` |
| `%` | `\%` |
| `+` | `+` |
| `-` | `-` |
| `=` | `=` |
| `<` | `<` |
| `>` | `>` |
| `:` | `:` |
| `,` | `,` |
| `;` | `;` |
| `&` | `&` |
| `.` | `.` |
| `@` | `\circ` |

`//` is a literal slash, `/` is a fraction, `^` and `_` are scripts, `!` is a factorial, `'` is a prime.

## Big operators

Each one takes `from ... to ... of`, `over ... of`, or `as ... of`. Written alone it
still accepts `_` and `^` limits.

| You type | LaTeX produced |
|---|---|
| `argmax from a to b of f` | `\operatorname*{arg\,max}_{a}^{b} f` |
| `argmin from a to b of f` | `\operatorname*{arg\,min}_{a}^{b} f` |
| `coproduct from a to b of f` | `\coprod_{a}^{b} f` |
| `inf from a to b of f` | `\inf_{a}^{b} f` |
| `infimum from a to b of f` | `\inf_{a}^{b} f` |
| `int from a to b of f` | `\int_{a}^{b} f` |
| `integral from a to b of f` | `\int_{a}^{b} f` |
| `lim from a to b of f` | `\lim_{a}^{b} f` |
| `liminf from a to b of f` | `\liminf_{a}^{b} f` |
| `limit from a to b of f` | `\lim_{a}^{b} f` |
| `limsup from a to b of f` | `\limsup_{a}^{b} f` |
| `max from a to b of f` | `\max_{a}^{b} f` |
| `maximum from a to b of f` | `\max_{a}^{b} f` |
| `min from a to b of f` | `\min_{a}^{b} f` |
| `minimum from a to b of f` | `\min_{a}^{b} f` |
| `prod from a to b of f` | `\prod_{a}^{b} f` |
| `product from a to b of f` | `\prod_{a}^{b} f` |
| `sum from a to b of f` | `\sum_{a}^{b} f` |
| `sup from a to b of f` | `\sup_{a}^{b} f` |
| `supremum from a to b of f` | `\sup_{a}^{b} f` |

| You type | LaTeX produced |
|---|---|
| `double integral` | `\iint_{D} f \,dA` |
| `triple integral` | `\iiint_{V} f \,dV` |
| `contour integral` | `\oint_{C} f \,dz` |
| `big union` | `\bigcup_{i = 1}^{n} A_{i}` |
| `big intersection` | `\bigcap_{i = 1}^{n} A_{i}` |
| `limit as x -> 0 of f(x)` | `\lim_{x \to 0} f \left( x \right)` |
| `sum over k in S of a_k` | `\sum_{k \in S} a_{k}` |

## Prefix constructs

These take either a bracketed group or the next single unit; `of` is optional.

| You type | LaTeX produced |
|---|---|
| `abs(x)` | `\left\| x \right\|` |
| `average x` | `\bar{x}` |
| `avg x` | `\bar{x}` |
| `bar x` | `\bar{x}` |
| `bb x` | `\mathbb{x}` |
| `binom(n, k)` | `\binom{n}{k}` |
| `binomial(n, k)` | `\binom{n}{k}` |
| `blackboard x` | `\mathbb{x}` |
| `bmatrix [1, 2; 3, 4]` | `\begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}` |
| `bold x` | `\mathbf{x}` |
| `boldface x` | `\mathbf{x}` |
| `boxed(E = m c^2)` | `\boxed{E = m c^{2}}` |
| `cal x` | `\mathcal{x}` |
| `cancel(x)` | `\cancel{x}` |
| `cases {1 if x > 0; 0 otherwise}` | `\begin{cases}1 &\ \text{if }  x > 0 \\ 0 &\ \text{otherwise}\end{cases}` |
| `ceil(x)` | `\left\lceil x \right\rceil` |
| `ceiling(x)` | `\left\lceil x \right\rceil` |
| `determinant [a, b; c, d]` | `\begin{vmatrix}a & b \\ c & d\end{vmatrix}` |
| `floor(x)` | `\left\lfloor x \right\rfloor` |
| `frak x` | `\mathfrak{x}` |
| `fraktur x` | `\mathfrak{x}` |
| `hat x` | `\hat{x}` |
| `inner(u, v)` | `\left\langle u , v \right\rangle` |
| `ip(u, v)` | `\left\langle u , v \right\rangle` |
| `length(v)` | `\left\\| v \right\\|` |
| `magnitude(v)` | `\left\| v \right\|` |
| `matrix [1, 2; 3, 4]` | `\begin{pmatrix}1 & 2 \\ 3 & 4\end{pmatrix}` |
| `mean x` | `\bar{x}` |
| `norm(v)` | `\left\\| v \right\\|` |
| `overbrace(a + b)` | `\overbrace{a + b}` |
| `overline x` | `\overline{x}` |
| `pmatrix [1, 2; 3, 4]` | `\begin{pmatrix}1 & 2 \\ 3 & 4\end{pmatrix}` |
| `root 3 of 8` | `\sqrt[3]{8}` |
| `round(x)` | `\left\lfloor x \right\rceil` |
| `script x` | `\mathcal{x}` |
| `set(1, 2, 3)` | `\left\{ 1 , 2 , 3 \right\}` |
| `sqrt of x` | `\sqrt{x}` |
| `tilde x` | `\tilde{x}` |
| `underbrace(a + b)` | `\underbrace{a + b}` |
| `underline x` | `\underline{x}` |
| `unit x` | `\hat{x}` |
| `vec x` | `\vec{x}` |
| `vector x` | `\vec{x}` |
| `vmatrix [a, b; c, d]` | `\begin{vmatrix}a & b \\ c & d\end{vmatrix}` |

## Structural words

Words that change the shape of what is around them rather than standing for one symbol.

| You type | LaTeX produced |
|---|---|
| `absolute value of x` | `\left\| x \right\|` |
| `big intersection from i = 1 to n of A_i` | `\bigcap_{i = 1}^{n} A_{i}` |
| `big union from i = 1 to n of A_i` | `\bigcup_{i = 1}^{n} A_{i}` |
| `brace matrix [1, 0; 0, 1]` | `\begin{Bmatrix}1 & 0 \\ 0 & 1\end{Bmatrix}` |
| `bracket matrix [1, 0; 0, 1]` | `\begin{bmatrix}1 & 0 \\ 0 & 1\end{bmatrix}` |
| `contour integral over C of f dz` | `\oint_{C} f \,dz` |
| `cube root of 8` | `\sqrt[3]{8}` |
| `derivative of f with respect to x` | `\frac{d f}{d x}` |
| `det matrix [a, b; c, d]` | `\begin{vmatrix}a & b \\ c & d\end{vmatrix}` |
| `determinant of the matrix [a, b; c, d]` | `\begin{vmatrix}a & b \\ c & d\end{vmatrix}` |
| `x divided by y` | `\frac{x}{y}` |
| `double integral over D of f dA` | `\iint_{D} f \,dA` |
| `line integral over C of f ds` | `\oint_{C} f \,ds` |
| `n choose k` | `\binom{n}{k}` |
| `n factorial` | `n!` |
| `3 out of 4` | `\frac{3}{4}` |
| `a over b` | `\frac{a}{b}` |
| `partial derivative of u with respect to t` | `\frac{\partial u}{\partial t}` |
| `second derivative of y with respect to x` | `\frac{d^{2} y}{d x^{2}}` |
| `sqrt of x` | `\sqrt{x}` |
| `square root of x` | `\sqrt{x}` |
| `the square root of x` | `\sqrt{x}` |
| `triple integral over V of f dV` | `\iiint_{V} f \,dV` |
| `derivative of f with respect to x` | `\frac{d f}{d x}` |
| `A adjoint` | `A^{\dagger}` |
| `an x` | `x` |
| `limit as x -> 0 of f(x)` | `\lim_{x \to 0} f \left( x \right)` |
| `f at x` | `f \ \text{at}\  x` |
| `n choose k` | `\binom{n}{k}` |
| `A complement` | `A^{c}` |
| `z conjugate` | `\overline{z}` |
| `y cubed` | `y^{3}` |
| `cases {1 if x > 0; 0 else}` | `\begin{cases}1 &\ \text{if }  x > 0 \\ 0 &\ \text{otherwise}\end{cases}` |
| `n factorial` | `n!` |
| `sum from k = 1 to n of a_k` | `\sum_{k = 1}^{n} a_{k}` |
| `cases {1 if x > 0; 0 otherwise}` | `\begin{cases}1 &\ \text{if }  x > 0 \\ 0 &\ \text{otherwise}\end{cases}` |
| `A inverse` | `A^{-1}` |
| `f of x` | `f\left( x \right)` |
| `cases {1 if x > 0; 0 otherwise}` | `\begin{cases}1 &\ \text{if }  x > 0 \\ 0 &\ \text{otherwise}\end{cases}` |
| `x squared` | `x^{2}` |
| `x in the reals` | `x \in \mathbb{R}` |
| `A transpose` | `A^{\mathsf{T}}` |
| `f(x) where x > 0` | `f \left( x \right) \ \text{where}\  x > 0` |

`the` and `an` are dropped; `is`, `are` and `be` become an equals sign. `as`, `from`,
`at` and `where` are limit words for big operators - used anywhere else they print as
upright text.

## Phrases

86 multi-word phrases, matched greedily before single words.

| You type | LaTeX produced |
|---|---|
| `an element of` | `\in` |
| `approaches` | `\to` |
| `at least` | `\ge` |
| `at most` | `\le` |
| `belongs to` | `\in` |
| `big o` | `O` |
| `big oh` | `O` |
| `complex numbers` | `\mathbb{C}` |
| `conditioned on` | `\mid` |
| `congruent to` | `\cong` |
| `converges to` | `\to` |
| `cross product` | `\times` |
| `does not exist` | `\nexists` |
| `dot product` | `\cdot` |
| `element of` | `\in` |
| `empty set` | `\varnothing` |
| `equal to` | `=` |
| `equals` | `=` |
| `for all` | `\forall` |
| `for each` | `\forall` |
| `for every` | `\forall` |
| `given that` | `\mid` |
| `goes to` | `\to` |
| `greater than` | `>` |
| `greater than or equal to` | `\ge` |
| `identity matrix` | `I` |
| `if and only if` | `\iff` |
| `implies that` | `\implies` |
| `intersected with` | `\cap` |
| `intersection with` | `\cap` |
| `is a member of` | `\in` |
| `is a subset of` | `\subset` |
| `is an element of` | `\in` |
| `is at least` | `\ge` |
| `is at most` | `\le` |
| `is congruent to` | `\cong` |
| `is defined as` | `\mathrel{:=}` |
| `is defined to be` | `\mathrel{:=}` |
| `is equal to` | `=` |
| `is greater than` | `>` |
| `is greater than or equal to` | `> \lor =` |
| `is in` | `\in` |
| `is less than` | `<` |
| `is less than or equal to` | `< \lor =` |
| `is not equal to` | `\ne` |
| `is not in` | `\notin` |
| `is parallel to` | `\parallel` |
| `is perpendicular to` | `\perp` |
| `is proportional to` | `\propto` |
| `is similar to` | `\sim` |
| `less than` | `<` |
| `less than or equal to` | `\le` |
| `lies in` | `\in` |
| `maps to` | `\mapsto` |
| `minus or plus` | `\mp` |
| `mod` | `\bmod` |
| `modulo` | `\bmod` |
| `natural numbers` | `\mathbb{N}` |
| `no more than` | `\le` |
| `not a subset of` | `\not\subset` |
| `not an element of` | `\notin` |
| `not equal to` | `\ne` |
| `not in` | `\notin` |
| `parallel to` | `\parallel` |
| `perpendicular to` | `\perp` |
| `plus or minus` | `\pm` |
| `proper subset of` | `\subsetneq` |
| `proportional to` | `\propto` |
| `rational numbers` | `\mathbb{Q}` |
| `real numbers` | `\mathbb{R}` |
| `similar to` | `\sim` |
| `subset of` | `\subset` |
| `such that` | `\mid` |
| `superset of` | `\supset` |
| `tends to` | `\to` |
| `the empty set` | `\varnothing` |
| `the integers` | `\mathbb{Z}` |
| `the naturals` | `\mathbb{N}` |
| `the reals` | `\mathbb{R}` |
| `there exist` | `\exists` |
| `there exists` | `\exists` |
| `there exists a unique` | `\exists!` |
| `there is` | `\exists` |
| `there is no` | `\nexists` |
| `union with` | `\cup` |
| `whole numbers` | `\mathbb{Z}` |

## Single words

124 words. Anything not in this list is treated as a variable, which is
why unknown words stay grey in the editor.

| You type | LaTeX produced |
|---|---|
| `aleph` | `\aleph` |
| `and` | `\land` |
| `angle` | `\angle` |
| `approx` | `\approx` |
| `approximately` | `\approx` |
| `are` | `=` |
| `ast` | `\ast` |
| `be` | `=` |
| `because` | `\because` |
| `blacksquare` | `\blacksquare` |
| `bot` | `\bot` |
| `bullet` | `\bullet` |
| `cap` | `\cap` |
| `cdot` | `\cdot` |
| `cdots` | `\cdots` |
| `circ` | `\circ` |
| `complexes` | `\mathbb{C}` |
| `compose` | `\circ` |
| `composed` | `\circ` |
| `cong` | `\cong` |
| `cup` | `\cup` |
| `dA` | `\,dA` |
| `dV` | `\,dV` |
| `ddots` | `\ddots` |
| `degrees` | `^{\circ}` |
| `del` | `\partial` |
| `div` | `\div` |
| `dot` | `\cdot` |
| `dots` | `\dots` |
| `downarrow` | `\downarrow` |
| `dr` | `\,dr` |
| `ds` | `\,ds` |
| `dt` | `\,dt` |
| `dtheta` | `\,d\theta` |
| `du` | `\,du` |
| `dv` | `\,dv` |
| `dx` | `\,dx` |
| `dy` | `\,dy` |
| `dz` | `\,dz` |
| `ell` | `\ell` |
| `emptyset` | `\varnothing` |
| `equiv` | `\equiv` |
| `exists` | `\exists` |
| `forall` | `\forall` |
| `ge` | `\ge` |
| `geq` | `\ge` |
| `gets` | `\gets` |
| `gg` | `\gg` |
| `given` | `\mid` |
| `grad` | `\nabla` |
| `gt` | `>` |
| `hbar` | `\hbar` |
| `hookrightarrow` | `\hookrightarrow` |
| `iff` | `\iff` |
| `implies` | `\implies` |
| `in` | `\in` |
| `infinity` | `\infty` |
| `infty` | `\infty` |
| `integers` | `\mathbb{Z}` |
| `intersect` | `\cap` |
| `intersection` | `\cap` |
| `is` | `=` |
| `laplacian` | `\nabla^{2}` |
| `ldots` | `\dots` |
| `le` | `\le` |
| `leftarrow` | `\leftarrow` |
| `leq` | `\le` |
| `ll` | `\ll` |
| `longrightarrow` | `\longrightarrow` |
| `lt` | `<` |
| `mapsto` | `\mapsto` |
| `mid` | `\mid` |
| `models` | `\models` |
| `mp` | `\mp` |
| `nabla` | `\nabla` |
| `naturals` | `\mathbb{N}` |
| `ne` | `\ne` |
| `neg` | `\neg` |
| `neq` | `\ne` |
| `nexists` | `\nexists` |
| `ni` | `\ni` |
| `not` | `\neg` |
| `nothing` | `\varnothing` |
| `notin` | `\notin` |
| `odot` | `\odot` |
| `oplus` | `\oplus` |
| `or` | `\lor` |
| `otimes` | `\otimes` |
| `parallel` | `\parallel` |
| `partial` | `\partial` |
| `percent` | `\%` |
| `perp` | `\perp` |
| `pm` | `\pm` |
| `prime` | `'` |
| `primes` | `\mathbb{P}` |
| `propto` | `\propto` |
| `qquad` | `\qquad` |
| `quad` | `\quad` |
| `rationals` | `\mathbb{Q}` |
| `reals` | `\mathbb{R}` |
| `rightarrow` | `\rightarrow` |
| `setminus` | `\setminus` |
| `sim` | `\sim` |
| `simeq` | `\simeq` |
| `space` | `\;` |
| `square` | `\square` |
| `st` | `\mid` |
| `star` | `\star` |
| `subset` | `\subset` |
| `subseteq` | `\subseteq` |
| `superset` | `\supset` |
| `supseteq` | `\supseteq` |
| `therefore` | `\therefore` |
| `times` | `\times` |
| `to` | `\to` |
| `top` | `\top` |
| `triangle` | `\triangle` |
| `union` | `\cup` |
| `uparrow` | `\uparrow` |
| `vdash` | `\vdash` |
| `vdots` | `\vdots` |
| `without` | `\setminus` |
| `wp` | `\wp` |
| `xor` | `\oplus` |

## Functions

Set upright, and each takes the next unit as its argument.

| You type | LaTeX produced |
|---|---|
| `Pr x` | `\Pr x` |
| `arccos x` | `\arccos x` |
| `arcsin x` | `\arcsin x` |
| `arctan x` | `\arctan x` |
| `arg x` | `\arg x` |
| `cos x` | `\cos x` |
| `cosh x` | `\cosh x` |
| `cot x` | `\cot x` |
| `coth x` | `\coth x` |
| `csc x` | `\csc x` |
| `deg x` | `\deg x` |
| `det x` | `\det x` |
| `dim x` | `\dim x` |
| `exp x` | `\exp x` |
| `gcd x` | `\gcd x` |
| `hom x` | `\hom x` |
| `ker x` | `\ker x` |
| `lg x` | `\lg x` |
| `ln x` | `\ln x` |
| `log x` | `\log x` |
| `sec x` | `\sec x` |
| `sin x` | `\sin x` |
| `sinh x` | `\sinh x` |
| `tan x` | `\tan x` |
| `tanh x` | `\tanh x` |

## Greek letters

Write the name; capitalise the name for the capital letter.

| You type | LaTeX produced |
|---|---|
| `alpha` | `\alpha` |
| `beta` | `\beta` |
| `chi` | `\chi` |
| `delta` | `\delta` |
| `epsilon` | `\epsilon` |
| `eta` | `\eta` |
| `gamma` | `\gamma` |
| `iota` | `\iota` |
| `kappa` | `\kappa` |
| `lambda` | `\lambda` |
| `mu` | `\mu` |
| `nu` | `\nu` |
| `omega` | `\omega` |
| `phi` | `\phi` |
| `pi` | `\pi` |
| `psi` | `\psi` |
| `rho` | `\rho` |
| `sigma` | `\sigma` |
| `tau` | `\tau` |
| `theta` | `\theta` |
| `upsilon` | `\upsilon` |
| `varepsilon` | `\varepsilon` |
| `varphi` | `\varphi` |
| `varpi` | `\varpi` |
| `varrho` | `\varrho` |
| `varsigma` | `\varsigma` |
| `vartheta` | `\vartheta` |
| `xi` | `\xi` |
| `zeta` | `\zeta` |
| `Delta` | `\Delta` |
| `Gamma` | `\Gamma` |
| `Lambda` | `\Lambda` |
| `Omega` | `\Omega` |
| `Phi` | `\Phi` |
| `Pi` | `\Pi` |
| `Psi` | `\Psi` |
| `Sigma` | `\Sigma` |
| `Theta` | `\Theta` |
| `Upsilon` | `\Upsilon` |
| `Xi` | `\Xi` |

## Your own shortcuts

`Cmd-Shift-K` opens a sheet: type a trigger, type what it should expand to, press Add.
The shortcut is written to a file and works in every document from that moment on,
including after a restart.

```
~/Library/Application Support/BetterLaTeX/shortcuts.conf
```

The file is plain text, one shortcut per line:

```
# lines starting with # are ignored
qed = blacksquare
hess = matrix [f_xx, f_xy; f_yx, f_yy]
grad f = nabla f
R = reals
```

| Detail | Behaviour |
|---|---|
| Right side | ordinary BetterLaTeX English, so `hess` above becomes a real matrix |
| Other shortcuts | usable inside a shortcut, up to three levels deep |
| Raw LaTeX | works too, because backslash commands pass through |
| Multi-word triggers | allowed: `grad f = nabla f` matches those two words together |
| Digits in triggers | allowed: `chi2 = chi^2` matches `chi2` before it matches `chi` |
| Precedence | your shortcuts win over the built-in tables, so you can redefine any word |
| Reload | saving the file updates open documents on the next keystroke; no restart |
| Editing by hand | Shortcuts menu, Edit Shortcuts File, opens it as a tab in the app |
| Deleting | the trash icon in the Add Shortcut sheet, or delete the line |

---

Counts: 110 phrases, 143 words, 44 prefix constructs, 20 big operators, 25 functions, 40 greek letters, 30 symbol sequences.
