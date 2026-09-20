// Folding: spans of a document that you chose to collapse.
//
// There is no automatic detection. You select lines and fold them; nothing is
// scanned or guessed. Folded text is never removed - the file on disk, the
// transpiler and the preview all see every character, and only the drawing of
// it changes.
import AppKit
import Foundation

struct FoldRegion: Equatable {
    /// The characters that are not drawn: every line after the first, including
    /// their newlines. The first line and its own newline stay visible, so the
    /// text that follows a fold always starts on a fresh line.
    var hidden: NSRange
    /// The newline ending the visible first line, which is where the badge sits.
    var headerEnd: Int
    /// How many lines disappear, for the badge.
    var lines: Int

    func contains(_ index: Int) -> Bool {
        index >= hidden.location && index < NSMaxRange(hidden)
    }
}

enum FoldMath {

    /// Grows a selection to whole lines: the first line stays visible, everything
    /// through the end of the last selected line is hidden. Nil when nothing
    /// would be hidden, so a selection inside one line does not fold.
    static func region(forSelection selection: NSRange, in text: NSString) -> FoldRegion? {
        guard text.length > 0 else { return nil }
        let start = min(selection.location, text.length - 1)
        let endIndex = min(max(NSMaxRange(selection) - 1, selection.location), text.length - 1)

        let firstLine = text.lineRange(for: NSRange(location: start, length: 0))
        let lastLine = text.lineRange(for: NSRange(location: endIndex, length: 0))
        let headerEnd = max(NSMaxRange(firstLine) - 1, firstLine.location)
        let end = min(NSMaxRange(lastLine), text.length)
        guard end > headerEnd + 1 else { return nil }

        let hidden = NSRange(location: headerEnd + 1, length: end - headerEnd - 1)
        return FoldRegion(hidden: hidden, headerEnd: headerEnd, lines: hiddenLines(in: hidden, of: text))
    }

    /// Each hidden line ends in a newline, except a last line that runs to the
    /// end of the file, which is counted as well.
    private static func hiddenLines(in range: NSRange, of text: NSString) -> Int {
        var count = 0
        var index = range.location
        while index < NSMaxRange(range) {
            if text.character(at: index) == 10 { count += 1 }
            index += 1
        }
        if range.length > 0, text.character(at: NSMaxRange(range) - 1) != 10 { count += 1 }
        return max(count, 1)
    }
}

/// Holds one document's folds and keeps them honest as the text changes.
/// The list is always sorted and never overlaps, because `isHidden` is called for
/// every glyph during layout and relies on that to binary-search.
final class FoldController {
    private(set) var regions: [FoldRegion] = []

    var isEmpty: Bool { regions.isEmpty }

    func isHidden(_ characterIndex: Int) -> Bool {
        var low = 0
        var high = regions.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let region = regions[mid]
            if characterIndex < region.hidden.location {
                high = mid - 1
            } else if characterIndex >= NSMaxRange(region.hidden) {
                low = mid + 1
            } else {
                return true
            }
        }
        return false
    }

    /// The fold hiding this character, if any. A caret at the end of a folded
    /// header - where folding leaves it - is outside, so it does not reopen it.
    func region(containing index: Int) -> FoldRegion? {
        regions.first { $0.contains(index) }
    }

    /// The fold whose visible first line holds this character.
    func region(headerAt index: Int, in text: NSString) -> FoldRegion? {
        guard text.length > 0 else { return nil }
        let line = text.lineRange(for: NSRange(location: min(index, text.length - 1), length: 0))
        return regions.first { $0.headerEnd >= line.location && $0.headerEnd <= NSMaxRange(line) }
    }

    /// Adds a fold. One that swallows existing folds replaces them; one that only
    /// partly overlaps a fold is refused, since the result would be ambiguous.
    func add(_ region: FoldRegion) {
        guard !regions.contains(where: { $0.hidden == region.hidden }) else { return }
        regions.removeAll { NSIntersectionRange(region.hidden, $0.hidden) == $0.hidden }
        guard !regions.contains(where: { NSIntersectionRange($0.hidden, region.hidden).length > 0 }),
              !regions.contains(where: { $0.contains(region.headerEnd) }) else { return }
        regions.append(region)
        regions.sort { $0.hidden.location < $1.hidden.location }
    }

    func remove(_ region: FoldRegion) {
        regions.removeAll { $0.hidden == region.hidden }
    }

    func removeAll() { regions.removeAll() }

    /// Called with the range that was replaced and the change in length. A fold
    /// entirely after the edit is untouched; one entirely before it shifts with
    /// the text; and one the edit reaches into - the hidden lines or the newline
    /// that ends the header - is released rather than left pointing at the wrong
    /// characters.
    func adjust(replaced range: NSRange, delta: Int, textLength: Int) {
        var kept: [FoldRegion] = []
        for var region in regions {
            let reaches = range.location < NSMaxRange(region.hidden) && NSMaxRange(range) > region.headerEnd
            if reaches { continue }
            if NSMaxRange(range) <= region.headerEnd {
                region.hidden.location += delta
                region.headerEnd += delta
            }
            if region.hidden.location >= 0, NSMaxRange(region.hidden) <= textLength {
                kept.append(region)
            }
        }
        regions = kept
    }
}
