// Turns positioned glyphs into structure: rows, scripts, fractions, big
// operators, delimiters. Everything here is geometry - what was drawn where and
// at what size - because that is all a PDF preserves of the author's intent.
import CoreGraphics
import Foundation

indirect enum MathNode {
    case atom(String)
    case sequence([MathNode])
    case script(base: MathNode, sup: MathNode?, sub: MathNode?)
    case fraction(MathNode, MathNode)
    case bigOp(String, sub: MathNode?, sup: MathNode?)
    case delimited(String, MathNode, String)
    case binom(MathNode, MathNode)
    case radical(MathNode)
}

enum Segment {
    case prose(String)
    case math(MathNode)
}

struct Row {
    var baseline: CGFloat
    var glyphs: [PDFGlyph]
    var size: CGFloat          // dominant size on the row
    var minX: CGFloat
    var maxX: CGFloat
    var isBold: Bool
    var isCentered: Bool
    var segments: [Segment] = []
}

enum PDFLayout {

    /// Prints the row-merging decisions; used while tuning the analyser.
    static var debug = false


    /// Glyph roles relative to their row's baseline.
    private enum Role { case base, superscript, `subscript` }

    static func rows(_ content: PDFPageContent) -> [Row] {
        guard !content.glyphs.isEmpty else { return [] }
        let body = dominantSize(content.glyphs)
        var buckets: [[PDFGlyph]] = []

        for glyph in content.glyphs.sorted(by: { $0.y > $1.y }) {
            // A superscript sits about half a size above the baseline, while the
            // next line down is more than a size away, so this tolerance keeps
            // scripts on their own row without swallowing the line below.
            if let index = buckets.indices.last,
               let reference = buckets[index].first,
               abs(reference.y - glyph.y) <= body * 0.62 {
                // A display operator's baseline can fall within a line's tolerance of
                // the prose above it. It starts its own line instead, or the equation
                // is absorbed into the sentence that introduces it.
                let hasProse = buckets[index].contains { !$0.family.isMath && $0.size >= body * 0.92 }
                let offBaseline = abs(reference.y - glyph.y) > body * 0.25
                if glyph.family == .mathExtended, hasProse, offBaseline {
                    buckets.append([glyph])
                } else {
                    buckets[index].append(glyph)
                }
            } else {
                buckets.append([glyph])
            }
        }

        // Stacked mathematics - a sum's limits, a binomial's two arguments - lands
        // in its own bucket because it sits off the baseline. Fold each one into the
        // line it belongs to. Repeated, because a limit may only become adjacent to
        // its operator once that operator's arguments have merged.
        var previousCount = buckets.count + 1
        var rounds = 0
        while buckets.count < previousCount, rounds < 4 {
            previousCount = buckets.count
            rounds += 1
            buckets = attachStacked(buckets, body: body)
        }

        let pageWidth = content.glyphs.map(\.right).max() ?? 612
        let leftEdge = content.glyphs.map(\.x).min() ?? 0

        return buckets.map { bucket in
            let sorted = bucket.sorted { $0.x < $1.x }
            // A display line can hold more 8pt limit glyphs than 10.9pt body
            // glyphs, so the line's size is the largest one that actually recurs.
            let size = lineSize(sorted)
            // The baseline is the one most glyphs sit on. A median would be dragged
            // off by a display operator, which is drawn well above its own line.
            let baseline = commonBaseline(sorted, size: size)
            let minX = sorted.map(\.x).min() ?? 0
            let maxX = sorted.map(\.right).max() ?? 0
            let boldShare = Double(sorted.filter { $0.family == .bold }.count) / Double(sorted.count)
            let leftGap = minX - leftEdge
            let rightGap = pageWidth - maxX
            let centered = leftGap > body * 2.5 && abs(leftGap - rightGap) < body * 2.2
            return Row(baseline: baseline, glyphs: sorted, size: size,
                       minX: minX, maxX: maxX,
                       isBold: boldShare > 0.6, isCentered: centered)
        }
    }

    /// One pass of folding off-baseline groups into the line they belong to.
    private static func attachStacked(_ buckets: [[PDFGlyph]], body: CGFloat) -> [[PDFGlyph]] {
        struct Extent {
            var minX: CGFloat, maxX: CGFloat, y: CGFloat, isAttachment: Bool, hasBigOp: Bool
        }
        let extents: [Extent] = buckets.map { bucket in
            let minX = bucket.map(\.x).min() ?? 0
            let maxX = bucket.map(\.right).max() ?? 0
            let y = bucket.map(\.y).max() ?? 0
            let hasProse = bucket.contains { !$0.family.isMath && $0.size >= body * 0.92 && ($0.text.first?.isLetter ?? false) }
            let hasBigOp = bucket.contains { $0.family == .mathExtended || bigOperator($0.text) != nil }
            return Extent(minX: minX, maxX: maxX, y: y, isAttachment: !hasProse, hasBigOp: hasBigOp)
        }
        if debug {
            for (i, e) in extents.enumerated() {
                let text = buckets[i].map { strip($0.text) }.joined()
                print(String(format: "  bucket %2d y=%7.2f x=[%6.1f..%6.1f] attach=%@ bigop=%@ | %@",
                             i, e.y, e.minX, e.maxX, e.isAttachment ? "Y" : "n", e.hasBigOp ? "Y" : "n",
                             String(text.prefix(46)) as NSString))
            }
        }
        var hosts = Array(repeating: -1, count: buckets.count)
        for i in buckets.indices where extents[i].isAttachment {
            var best = -1
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for j in [i - 1, i + 1] where buckets.indices.contains(j) {
                let width = extents[j].maxX - extents[j].minX
                guard !extents[j].isAttachment || width > extents[i].maxX - extents[i].minX else { continue }
                guard extents[i].minX >= extents[j].minX - body * 0.9,
                      extents[i].maxX <= extents[j].maxX + body * 0.9 else { continue }
                // display-style limits sit further from their operator than a
                // subscript does, so a row carrying one reaches further
                let reach = extents[j].hasBigOp ? body * 1.9 : body * 1.05
                // closest baselines, because a bucket holding a big operator spans
                // several of them
                var distance = CGFloat.greatestFiniteMagnitude
                for a in buckets[i] {
                    for b in buckets[j] { distance = min(distance, abs(a.y - b.y)) }
                }
                if distance < bestDistance, distance < reach {
                    bestDistance = distance
                    best = j
                }
            }
            hosts[i] = best
            if debug { print("  bucket \(i) -> host \(best)") }
        }
        // a host that is itself attached passes its children along
        func root(_ index: Int) -> Int {
            var current = index
            var guardCount = 0
            while hosts[current] != -1, guardCount < 8 {
                current = hosts[current]
                guardCount += 1
            }
            return current
        }
        var merged: [[PDFGlyph]] = []
        for i in buckets.indices where hosts[i] == -1 {
            var glyphs = buckets[i]
            for j in buckets.indices where hosts[j] != -1 && root(j) == i {
                glyphs.append(contentsOf: buckets[j])
            }
            merged.append(glyphs.sorted { $0.x < $1.x })
        }
        return merged
    }

    /// The largest size appearing at least twice, else the largest present.
    static func lineSize(_ glyphs: [PDFGlyph]) -> CGFloat {
        var counts: [CGFloat: Int] = [:]
        for g in glyphs { counts[(g.size * 10).rounded() / 10, default: 0] += 1 }
        let repeated = counts.filter { $0.value >= 2 }.keys.max()
        return repeated ?? counts.keys.max() ?? 10
    }

    /// The y most full-size glyphs share, to 0.5pt.
    static func commonBaseline(_ glyphs: [PDFGlyph], size: CGFloat) -> CGFloat {
        let full = glyphs.filter { $0.size >= size * 0.92 }
        guard !full.isEmpty else { return glyphs.first?.y ?? 0 }
        var counts: [CGFloat: Int] = [:]
        for g in full { counts[(g.y * 2).rounded() / 2, default: 0] += 1 }
        let best = counts.max { a, b in a.value == b.value ? a.key < b.key : a.value < b.value }
        return best?.key ?? full[0].y
    }

    static func dominantSize(_ glyphs: [PDFGlyph]) -> CGFloat {
        var counts: [CGFloat: Int] = [:]
        for g in glyphs { counts[(g.size * 10).rounded() / 10, default: 0] += 1 }
        return counts.max { a, b in a.value == b.value ? a.key < b.key : a.value < b.value }?.key ?? 10
    }

    /// Splits a row into prose and math, building a node tree for each math run.
    static func analyse(row: Row, rules: [PDFRule], body: CGFloat) -> [Segment] {
        var segments: [Segment] = []
        var prose = ""
        var mathRun: [PDFGlyph] = []

        func flushProse() {
            let trimmed = prose.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { segments.append(.prose(trimmed)) }
            prose = ""
        }
        func flushMath() {
            guard !mathRun.isEmpty else { return }
            segments.append(.math(build(mathRun, row: row, rules: rules, body: body)))
            mathRun = []
        }

        var previous: PDFGlyph?
        for glyph in row.glyphs {
            let gap = previous.map { glyph.x - $0.right } ?? 0
            let mathish = isMathGlyph(glyph, row: row)
            if mathish {
                if !mathRun.isEmpty, gap > glyph.size * 0.9 {
                    // a wide gap ends the expression
                    flushMath()
                }
                if mathRun.isEmpty { flushProse() }
                mathRun.append(glyph)
            } else if !mathRun.isEmpty, gap < glyph.size * 0.42, glyphJoinsMath(glyph) {
                mathRun.append(glyph)
            } else {
                flushMath()
                if let previous, gap > previous.size * 0.22 { prose += " " }
                prose += glyph.text
            }
            previous = glyph
        }
        flushMath()
        flushProse()
        return segments
    }

    private static func isMathGlyph(_ glyph: PDFGlyph, row: Row) -> Bool {
        if glyph.family.isMath { return true }
        if glyph.size < row.size * 0.88, abs(glyph.y - row.baseline) > glyph.size * 0.12 { return true }
        return false
    }

    /// Digits, operators and single letters glued to a math run belong to it.
    private static func glyphJoinsMath(_ glyph: PDFGlyph) -> Bool {
        guard let scalar = glyph.text.unicodeScalars.first, glyph.text.count == 1 else { return false }
        if CharacterSet.decimalDigits.contains(scalar) { return true }
        return "+-=<>()[]/|!.,^_*".unicodeScalars.contains(scalar)
    }

    // MARK: building a math tree

    private static func build(_ glyphs: [PDFGlyph], row: Row, rules: [PDFRule], body: CGFloat) -> MathNode {
        let sorted = glyphs.sorted { $0.x < $1.x }
        var consumed = Set<Int>()
        var nodes: [MathNode] = []
        var index = 0

        // Big operators claim their limits before anything is emitted, because a
        // limit can be drawn to the left of the operator it belongs to.
        var operators: [Int: MathNode] = [:]
        for (i, glyph) in sorted.enumerated() {
            guard let name = bigOperator(glyph.text) else { continue }
            var above: [PDFGlyph] = []
            var below: [PDFGlyph] = []
            for (j, g) in sorted.enumerated() where j != i && !consumed.contains(j) {
                // A limit is set smaller than the operator and sits under or over
                // it; an argument beside it is full size and stays outside.
                let small = g.size < glyph.size * 0.9
                let slack = glyph.size * (small ? 0.9 : 0.35)
                guard g.x >= glyph.x - slack, g.right <= glyph.right + slack,
                      abs(g.y - glyph.y) > glyph.size * 0.3 else { continue }
                consumed.insert(j)
                if g.y > glyph.y { above.append(g) } else { below.append(g) }
            }
            let sub = below.isEmpty ? nil : build(below, row: subRow(below), rules: [], body: body)
            let sup = above.isEmpty ? nil : build(above, row: subRow(above), rules: [], body: body)
            operators[i] = .bigOp(name, sub: sub, sup: sup)
        }

        while index < sorted.count {
            if consumed.contains(index) { index += 1; continue }
            let glyph = sorted[index]

            // 1. a fraction bar drawn across this run
            if let rule = fractionRule(for: glyph, in: rules, row: row, body: body) {
                let span = rule.rect
                var above: [PDFGlyph] = []
                var below: [PDFGlyph] = []
                var touched: Set<Int> = []
                for (j, g) in sorted.enumerated() where !consumed.contains(j) {
                    guard g.x >= span.minX - 1, g.right <= span.maxX + 1 else { continue }
                    touched.insert(j)
                    if g.y > span.midY { above.append(g) } else { below.append(g) }
                }
                if !above.isEmpty, !below.isEmpty {
                    nodes.append(.fraction(build(above, row: subRow(above), rules: [], body: body),
                                           build(below, row: subRow(below), rules: [], body: body)))
                    consumed.formUnion(touched)
                    index += 1
                    continue
                }
            }

            // 2. a big operator, with the limits claimed above
            if let node = operators[index] {
                nodes.append(node)
                index += 1
                continue
            }

            // 3. a big delimiter: two stacked groups inside it is a binomial
            if glyph.family == .mathExtended, let open = openDelimiter(glyph.text) {
                let close = closing(open)
                if let closeIndex = (index + 1..<sorted.count).first(where: {
                    !consumed.contains($0) && sorted[$0].family == .mathExtended
                        && openDelimiter(sorted[$0].text) == nil
                        && strip(sorted[$0].text) == close
                }) {
                    let innerIndices = ((index + 1)..<closeIndex).filter { !consumed.contains($0) }
                    let inner = innerIndices.map { sorted[$0] }
                    if !inner.isEmpty {
                        let ys = inner.map(\.y)
                        let spread = (ys.max() ?? 0) - (ys.min() ?? 0)
                        if spread > glyph.size * 0.3, open == "(" {
                            let mid = ((ys.max() ?? 0) + (ys.min() ?? 0)) / 2
                            let upper = inner.filter { $0.y > mid }
                            let lower = inner.filter { $0.y <= mid }
                            nodes.append(.binom(build(upper, row: subRow(upper), rules: [], body: body),
                                                build(lower, row: subRow(lower), rules: [], body: body)))
                        } else {
                            nodes.append(.delimited(open, build(inner, row: subRow(inner), rules: [], body: body), close))
                        }
                    }
                    consumed.formUnion(innerIndices)
                    consumed.insert(closeIndex)
                    index += 1
                    continue
                }
            }

            // 4. scripts hanging off the previous atom
            if roleOf(glyph, row: row) != .base, var last = nodes.popLast() {
                var supGlyphs: [PDFGlyph] = []
                var subGlyphs: [PDFGlyph] = []
                var j = index
                while j < sorted.count {
                    if consumed.contains(j) { j += 1; continue }
                    let candidate = sorted[j]
                    // a delimiter or operator starts new structure, never a script
                    if candidate.family == .mathExtended || operators[j] != nil { break }
                    let role = roleOf(candidate, row: row)
                    if role == .base { break }
                    if role == .superscript { supGlyphs.append(candidate) } else { subGlyphs.append(candidate) }
                    j += 1
                }
                let sup: MathNode? = supGlyphs.isEmpty ? nil : build(supGlyphs, row: subRow(supGlyphs), rules: [], body: body)
                let sub: MathNode? = subGlyphs.isEmpty ? nil : build(subGlyphs, row: subRow(subGlyphs), rules: [], body: body)
                last = .script(base: last, sup: sup, sub: sub)
                nodes.append(last)
                index = j
                continue
            }

            nodes.append(.atom(strip(glyph.text)))
            index += 1
        }
        return nodes.count == 1 ? nodes[0] : .sequence(nodes)
    }

    /// A synthetic row for a nested group, so scripts inside it are measured
    /// against their own baseline rather than the line's.
    private static func subRow(_ glyphs: [PDFGlyph]) -> Row {
        let size = lineSize(glyphs)
        let baseline = commonBaseline(glyphs, size: size)
        return Row(baseline: baseline, glyphs: glyphs, size: size,
                   minX: glyphs.map(\.x).min() ?? 0, maxX: glyphs.map(\.right).max() ?? 0,
                   isBold: false, isCentered: false)
    }

    private static func roleOf(_ glyph: PDFGlyph, row: Row) -> Role {
        let delta = glyph.y - row.baseline
        let smaller = glyph.size < row.size * 0.92
        // A full-size relation or operator sits on the maths axis, which in a row
        // of stacked fractions is not the row's own baseline. It is never a script.
        if !smaller, let first = PDFLayout.strip(glyph.text).unicodeScalars.first,
           !CharacterSet.alphanumerics.contains(first) {
            return .base
        }
        if smaller, delta > glyph.size * 0.18 { return .superscript }
        if smaller, delta < -glyph.size * 0.12 { return .subscript }
        if delta > row.size * 0.3 { return .superscript }
        if delta < -row.size * 0.25 { return .subscript }
        return .base
    }

    private static func fractionRule(for glyph: PDFGlyph, in rules: [PDFRule], row: Row, body: CGFloat) -> PDFRule? {
        rules.first { rule in
            let r = rule.rect
            return r.height < 1.6 && r.width > 3 && r.width < 400
                && r.minX <= glyph.x + 1 && r.maxX >= glyph.x - 1
                && abs(r.midY - row.baseline) < body * 1.4
        }
    }

    /// Variation selectors mark extensible delimiter pieces; the base character
    /// is the part that carries meaning.
    static func strip(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { !($0.value >= 0xFE00 && $0.value <= 0xFE0F) }))
    }

    private static func openDelimiter(_ text: String) -> String? {
        let base = strip(text)
        return ["(", "[", "{"].contains(base) ? base : nil
    }

    private static func closing(_ open: String) -> String {
        switch open {
        case "(": return ")"
        case "[": return "]"
        default: return "}"
        }
    }

    private static func bigOperator(_ text: String) -> String? {
        let text = strip(text)
        switch text {
        case "\u{2211}": return "sum"
        case "\u{220F}": return "product"
        case "\u{222B}": return "integral"
        case "\u{222C}": return "double integral"
        case "\u{222D}": return "triple integral"
        case "\u{222E}": return "contour integral"
        case "\u{22C3}": return "big union"
        case "\u{22C2}": return "big intersection"
        default: return nil
        }
    }
}
