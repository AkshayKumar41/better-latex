// Symbol tables for the English -> LaTeX math transpiler.
// All lookups are static dictionaries: one hash per token, no regex, no allocation churn.
import Foundation

enum Sym {

    // Multi-character operators, matched longest-first.
    static let operators: [(String, String)] = [
        ("<=>", "\\Leftrightarrow"), ("<->", "\\leftrightarrow"), ("|->", "\\mapsto"),
        ("...", "\\dots"), (">=", "\\ge"), ("<=", "\\le"), ("->", "\\to"),
        ("=>", "\\Rightarrow"), ("!=", "\\ne"), ("==", "\\equiv"), ("~=", "\\approx"),
        ("+-", "\\pm"), ("-+", "\\mp"), ("<<", "\\ll"), (">>", "\\gg"),
        (":=", "\\mathrel{:=}"), ("*", "\\cdot"), ("~", "\\sim"), ("%", "\\%"),
        ("+", "+"), ("-", "-"), ("=", "="), ("<", "<"), (">", ">"), (":", ":"),
        (",", ","), (";", ";"), ("&", "&"), (".", "."), ("@", "\\circ"),
    ]

    static let greekLower: Set<String> = [
        "alpha", "beta", "gamma", "delta", "epsilon", "varepsilon", "zeta", "eta",
        "theta", "vartheta", "iota", "kappa", "lambda", "mu", "nu", "xi", "pi",
        "varpi", "rho", "varrho", "sigma", "varsigma", "tau", "upsilon", "phi",
        "varphi", "chi", "psi", "omega",
    ]

    static let greekUpper: Set<String> = [
        "Gamma", "Delta", "Theta", "Lambda", "Xi", "Pi", "Sigma", "Upsilon",
        "Phi", "Psi", "Omega",
    ]

    // Operator names that LaTeX sets upright: sin x, not s*i*n*x.
    static let functions: Set<String> = [
        "sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan",
        "sinh", "cosh", "tanh", "coth", "log", "ln", "lg", "exp", "det", "dim",
        "ker", "deg", "gcd", "hom", "arg", "Pr",
    ]

    // Big operators: they take from/to/over/as limits and an `of` body.
    static let bigOps: [String: String] = [
        "sum": "\\sum", "product": "\\prod", "prod": "\\prod",
        "integral": "\\int", "int": "\\int",
        "limit": "\\lim", "lim": "\\lim",
        "max": "\\max", "maximum": "\\max", "min": "\\min", "minimum": "\\min",
        "sup": "\\sup", "supremum": "\\sup", "inf": "\\inf", "infimum": "\\inf",
        "argmax": "\\operatorname*{arg\\,max}", "argmin": "\\operatorname*{arg\\,min}",
        "coproduct": "\\coprod", "liminf": "\\liminf", "limsup": "\\limsup",
    ]

    // Phrases: matched greedily over up to 5 words before any single-word lookup.
    // Value kinds: plain LaTeX, or a "@marker" the parser interprets structurally.
    static let phrases: [String: String] = [
        "for all": "\\forall", "for every": "\\forall", "for each": "\\forall",
        "there exists": "\\exists", "there exist": "\\exists", "there is": "\\exists",
        "there exists a unique": "\\exists!", "there is no": "\\nexists",
        "does not exist": "\\nexists",
        "not in": "\\notin", "is not in": "\\notin", "not an element of": "\\notin",
        "is in": "\\in", "element of": "\\in", "an element of": "\\in",
        "belongs to": "\\in", "lies in": "\\in",
        "such that": "\\mid", "given that": "\\mid", "conditioned on": "\\mid",
        "if and only if": "\\iff", "implies that": "\\implies",
        "maps to": "\\mapsto", "goes to": "\\to", "tends to": "\\to",
        "approaches": "\\to", "converges to": "\\to",
        "less than": "<", "greater than": ">",
        "less than or equal to": "\\le", "greater than or equal to": "\\ge",
        "at most": "\\le", "at least": "\\ge", "no more than": "\\le",
        "not equal to": "\\ne", "is equal to": "=", "equal to": "=", "equals": "=",
        "plus or minus": "\\pm", "minus or plus": "\\mp",
        "dot product": "\\cdot", "cross product": "\\times",
        "proportional to": "\\propto", "congruent to": "\\cong",
        "similar to": "\\sim", "perpendicular to": "\\perp", "parallel to": "\\parallel",
        "subset of": "\\subset", "is a subset of": "\\subset",
        "is an element of": "\\in", "is a member of": "\\in",
        "is at most": "\\le", "is at least": "\\ge",
        "is less than": "<", "is greater than": ">",
        "is less than or equal to": "\\le", "is greater than or equal to": "\\ge",
        "is not equal to": "\\ne", "is congruent to": "\\cong",
        "is similar to": "\\sim", "is proportional to": "\\propto",
        "is perpendicular to": "\\perp", "is parallel to": "\\parallel",
        "is defined as": "\\mathrel{:=}", "is defined to be": "\\mathrel{:=}",
        "proper subset of": "\\subsetneq", "not a subset of": "\\not\\subset",
        "superset of": "\\supset", "union with": "\\cup",
        "intersected with": "\\cap", "intersection with": "\\cap",
        "empty set": "\\varnothing", "the empty set": "\\varnothing",
        "real numbers": "\\mathbb{R}", "the reals": "\\mathbb{R}",
        "natural numbers": "\\mathbb{N}", "the naturals": "\\mathbb{N}",
        "whole numbers": "\\mathbb{Z}", "the integers": "\\mathbb{Z}",
        "rational numbers": "\\mathbb{Q}", "complex numbers": "\\mathbb{C}",
        "identity matrix": "I", "big o": "O", "big oh": "O",
        "modulo": "\\bmod", "mod": "\\bmod",
        "n choose k": "@choose_nk",
        // structural markers
        "divided by": "@over", "over": "@over", "out of": "@over",
        "square root of": "@sqrt", "the square root of": "@sqrt", "sqrt of": "@sqrt",
        "cube root of": "@cbrt", "absolute value of": "@abs",
        "with respect to": "@wrt", "derivative of": "@deriv",
        "second derivative of": "@deriv2", "partial derivative of": "@pderiv",
        "double integral": "@iint", "triple integral": "@iiint",
        "contour integral": "@oint", "line integral": "@oint",
        "big union": "@bigcup", "big intersection": "@bigcap",
        "bracket matrix": "@bmatrix", "brace matrix": "@Bmatrix",
        "det matrix": "@vmatrix", "determinant of the matrix": "@vmatrix",
        "n factorial": "@fact_n",
    ]

    // Single words that stand for one symbol.
    static let words: [String: String] = [
        "infinity": "\\infty", "infty": "\\infty",
        "in": "\\in", "notin": "\\notin", "ni": "\\ni",
        "union": "\\cup", "cup": "\\cup", "intersect": "\\cap",
        "intersection": "\\cap", "cap": "\\cap",
        "subset": "\\subset", "subseteq": "\\subseteq", "superset": "\\supset",
        "supseteq": "\\supseteq", "setminus": "\\setminus", "without": "\\setminus",
        "emptyset": "\\varnothing", "nothing": "\\varnothing",
        "forall": "\\forall", "exists": "\\exists", "nexists": "\\nexists",
        "implies": "\\implies", "iff": "\\iff", "not": "\\neg", "neg": "\\neg",
        "and": "\\land", "or": "\\lor", "xor": "\\oplus",
        "therefore": "\\therefore", "because": "\\because",
        "times": "\\times", "cdot": "\\cdot", "dot": "\\cdot", "div": "\\div",
        "pm": "\\pm", "mp": "\\mp",
        "approx": "\\approx", "approximately": "\\approx", "equiv": "\\equiv",
        "propto": "\\propto", "sim": "\\sim", "cong": "\\cong", "simeq": "\\simeq",
        "leq": "\\le", "geq": "\\ge", "neq": "\\ne", "le": "\\le", "ge": "\\ge",
        "ne": "\\ne", "lt": "<", "gt": ">", "ll": "\\ll", "gg": "\\gg",
        "perp": "\\perp", "parallel": "\\parallel", "angle": "\\angle",
        "triangle": "\\triangle", "square": "\\square",
        "nabla": "\\nabla", "grad": "\\nabla", "partial": "\\partial",
        "laplacian": "\\nabla^{2}", "del": "\\partial",
        "reals": "\\mathbb{R}", "naturals": "\\mathbb{N}", "integers": "\\mathbb{Z}",
        "rationals": "\\mathbb{Q}", "complexes": "\\mathbb{C}", "primes": "\\mathbb{P}",
        "aleph": "\\aleph", "hbar": "\\hbar", "ell": "\\ell", "wp": "\\wp",
        "degrees": "^{\\circ}", "percent": "\\%", "prime": "'",
        "dots": "\\dots", "ldots": "\\dots", "cdots": "\\cdots",
        "vdots": "\\vdots", "ddots": "\\ddots",
        "to": "\\to", "gets": "\\gets", "mapsto": "\\mapsto",
        "uparrow": "\\uparrow", "downarrow": "\\downarrow",
        "leftarrow": "\\leftarrow", "rightarrow": "\\rightarrow",
        "longrightarrow": "\\longrightarrow", "hookrightarrow": "\\hookrightarrow",
        "given": "\\mid", "st": "\\mid", "mid": "\\mid",
        "circ": "\\circ", "compose": "\\circ", "composed": "\\circ",
        "oplus": "\\oplus", "otimes": "\\otimes", "odot": "\\odot",
        "star": "\\star", "ast": "\\ast", "bullet": "\\bullet",
        "blacksquare": "\\blacksquare", "top": "\\top", "bot": "\\bot", "vdash": "\\vdash", "models": "\\models",
        "quad": "\\quad", "qquad": "\\qquad", "space": "\\;",
        "dx": "\\,dx", "dy": "\\,dy", "dz": "\\,dz", "dt": "\\,dt",
        "ds": "\\,ds", "dr": "\\,dr", "du": "\\,du", "dv": "\\,dv",
        "dtheta": "\\,d\\theta", "dA": "\\,dA", "dV": "\\,dV",
        "the": "@skip", "an": "@skip", "is": "=", "are": "=", "be": "=",
        "of": "@of", "as": "@as", "from": "@from", "at": "@at",
        "choose": "@choose", "where": "@where",
        "if": "@if", "otherwise": "@otherwise", "else": "@otherwise",
        "squared": "@sq", "cubed": "@cube", "inverse": "@inv",
        "transpose": "@transpose", "complement": "@complement",
        "factorial": "@fact", "conjugate": "@conj", "adjoint": "@dagger",
    ]

    // Prefix constructs: `sqrt of x`, `vec v`, `abs(x)`, `matrix [1,2; 3,4]`.
    static let prefixOps: [String: String] = [
        "sqrt": "@sqrt", "root": "@root",
        "vec": "@vec", "vector": "@vec", "hat": "@hat", "unit": "@hat",
        "bar": "@bar", "mean": "@bar", "average": "@bar", "avg": "@bar",
        "tilde": "@tilde", "overline": "@overline", "underline": "@underline",
        "bold": "@bold", "boldface": "@bold", "script": "@cal", "cal": "@cal",
        "frak": "@frak", "fraktur": "@frak", "blackboard": "@bb", "bb": "@bb",
        "abs": "@abs", "magnitude": "@abs", "norm": "@norm", "length": "@norm",
        "floor": "@floor", "ceil": "@ceil", "ceiling": "@ceil",
        "round": "@round", "set": "@set", "inner": "@inner", "ip": "@inner",
        "matrix": "@pmatrix", "pmatrix": "@pmatrix", "bmatrix": "@bmatrix",
        "vmatrix": "@vmatrix", "determinant": "@vmatrix", "cases": "@cases",
        "binom": "@binom", "binomial": "@binom",
        "overbrace": "@overbrace", "underbrace": "@underbrace",
        "boxed": "@boxed", "cancel": "@cancel",
    ]

    // Words whose argument is literal text, captured by the lexer before parsing.
    static let literalArg: Set<String> = [
        "text", "word", "words", "textbf", "textit", "mathrm", "mathbf",
        "operatorname", "label", "ref", "cite", "url",
    ]

    static let literalArgCommand: [String: String] = [
        "text": "\\text", "word": "\\text", "words": "\\text",
        "textbf": "\\textbf", "textit": "\\textit", "mathrm": "\\mathrm",
        "mathbf": "\\mathbf", "operatorname": "\\operatorname",
        "label": "\\label", "ref": "\\ref", "cite": "\\cite", "url": "\\url",
    ]

    static let maxPhraseWords = 5

    /// Greek name -> command, or nil.
    static func greek(_ w: String) -> String? {
        if greekLower.contains(w) { return "\\" + w }
        if greekUpper.contains(w) { return "\\" + w }
        return nil
    }
}
