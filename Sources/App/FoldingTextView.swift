// The editor's text view, with a gutter for fold arrows and a badge where text
// is folded away.
//
// The gutter is painted by the text view itself. A drawing subview inside this
// SwiftUI-hosted text view stopped the text drawing at all - the editor came up
// blank - so nothing here adds a view.
import AppKit

/// One arrow per fold, and one beside the current selection offering to fold it.
struct GutterPainter {

    static let width: CGFloat = 20

    /// Where each arrow sits and what it does. A nil region means "fold the
    /// current selection".
    private(set) var arrows: [(rect: NSRect, region: FoldRegion?)] = []

    mutating func draw(in rect: NSRect, textView: NSTextView, folds: FoldController?) {
        arrows = []
        guard let layoutManager = textView.layoutManager else { return }

        Palette.panelBG.setFill()
        NSRect(x: 0, y: rect.minY, width: Self.width, height: rect.height).fill()

        let ns = textView.string as NSString
        let inset = textView.textContainerInset.height

        /// Vertical centre of the line holding this character.
        func centre(ofLineEndingAt headerEnd: Int) -> CGFloat? {
            guard ns.length > 0 else { return nil }
            // the last character of the header line; for an empty line, the newline
            let probe = headerEnd > 0 && ns.character(at: headerEnd - 1) != 10 ? headerEnd - 1 : headerEnd
            let glyph = layoutManager.glyphIndexForCharacter(at: min(probe, ns.length - 1))
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            return line.minY + inset + line.height / 2
        }

        for region in folds?.regions ?? [] {
            guard let y = centre(ofLineEndingAt: region.headerEnd) else { continue }
            let box = NSRect(x: 3, y: y - 7, width: 14, height: 14)
            arrow(in: box, pointingRight: true, colour: Palette.brass)
            arrows.append((box, region))
        }

        let selection = textView.selectedRange()
        guard selection.length > 0,
              folds?.region(containing: selection.location) == nil,
              let candidate = FoldMath.region(forSelection: selection, in: ns),
              folds?.regions.contains(where: { $0.hidden == candidate.hidden }) != true,
              let y = centre(ofLineEndingAt: candidate.headerEnd) else { return }
        let box = NSRect(x: 3, y: y - 7, width: 14, height: 14)
        arrow(in: box, pointingRight: false, colour: Palette.muted)
        arrows.append((box, nil))
    }

    private func arrow(in rect: NSRect, pointingRight: Bool, colour: NSColor) {
        let path = NSBezierPath()
        let middle = NSPoint(x: rect.midX, y: rect.midY)
        let size: CGFloat = 4
        if pointingRight {
            path.move(to: NSPoint(x: middle.x - size / 2, y: middle.y - size))
            path.line(to: NSPoint(x: middle.x - size / 2, y: middle.y + size))
            path.line(to: NSPoint(x: middle.x + size, y: middle.y))
        } else {
            path.move(to: NSPoint(x: middle.x - size, y: middle.y - size / 2))
            path.line(to: NSPoint(x: middle.x + size, y: middle.y - size / 2))
            path.line(to: NSPoint(x: middle.x, y: middle.y + size))
        }
        path.close()
        colour.setFill()
        path.fill()
    }

    /// What a click hit, if it was on an arrow.
    func hit(_ point: NSPoint) -> (rect: NSRect, region: FoldRegion?)? {
        guard point.x < Self.width + 4 else { return nil }
        return arrows.first { $0.rect.insetBy(dx: -5, dy: -5).contains(point) }
    }
}

final class FoldingTextView: NSTextView {

    weak var folds: FoldController?
    var gutter = GutterPainter()
    var onUnfold: ((FoldRegion) -> Void)?
    /// Fold the current selection, from the gutter arrow.
    var onFoldSelection: (() -> Void)?

    private var badges: [(rect: NSRect, region: FoldRegion)] = []
    private static let badgeFont = NSFont.systemFont(ofSize: 9.5, weight: .semibold)

    // This is a plain-text editor, so the font panel and the Touch Bar's text
    // formatting controls (bold, italic, alignment) have nothing to show.
    //
    // They are also the single most expensive thing that happens when you type.
    // On every keystroke AppKit walks the document's attribute runs and asks
    // NSFontManager to convert each run's font to bold and to italic, building
    // CoreText font descriptors as it goes. The syntax highlighter creates a lot of
    // runs with different fonts, so the cost grew with the length of the document:
    // about 10 ms per character at 7 KB and 33 ms at 35 KB, measured.
    override func updateFontPanel() {}
    override func updateTextTouchBarItems() {}

    // Painted in drawBackground: in SwiftUI's layer-backed hosting the plain
    // draw(_:) override is bypassed.
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        // Always the whole visible strip. Painting only the dirty slice clips
        // arrows in half and leaves stale ones behind after a fold.
        gutter.draw(in: visibleRect.union(rect), textView: self, folds: folds)
        drawBadges()
    }

    /// Redraws the gutter after the selection or the folds change.
    func refreshGutter() {
        setNeedsDisplay(visibleRect)
    }

    private func drawBadges() {
        badges = []
        guard let folds, !folds.isEmpty, let layoutManager, let textContainer else { return }
        let ns = string as NSString
        for region in folds.regions {
            let probe = region.headerEnd > 0 && ns.character(at: region.headerEnd - 1) != 10
                ? region.headerEnd - 1 : region.headerEnd
            guard probe < ns.length else { continue }
            let glyph = layoutManager.glyphIndexForCharacter(at: probe)
            var box = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
            let label = "\u{22EF} \(region.lines) lines" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: Self.badgeFont,
                .foregroundColor: Palette.muted,
            ]
            let size = label.size(withAttributes: attributes)
            box.origin.x += box.width + textContainerInset.width + 8
            box.origin.y += textContainerInset.height + (box.height - size.height - 4) / 2
            box.size = NSSize(width: size.width + 12, height: size.height + 4)

            let path = NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4)
            Palette.brass.withAlphaComponent(0.14).setFill()
            path.fill()
            Palette.brass.withAlphaComponent(0.45).setStroke()
            path.lineWidth = 1
            path.stroke()
            label.draw(at: NSPoint(x: box.minX + 6, y: box.minY + 2), withAttributes: attributes)
            badges.append((box, region))
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let hit = gutter.hit(point) {
            if let region = hit.region { onUnfold?(region) } else { onFoldSelection?() }
            return
        }
        if let hit = badges.first(where: { $0.rect.contains(point) }) {
            onUnfold?(hit.region)
            return
        }
        super.mouseDown(with: event)
    }
}
