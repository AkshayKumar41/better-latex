// Pulls positioned glyphs and rules off a PDF page.
//
// Decoding goes through each font's embedded ToUnicode CMap, so this works for
// anything that ships one - pdfLaTeX, XeLaTeX, Word - rather than only for
// Computer Modern. Advances come from the font's Widths array, because accurate
// x positions are what make the layout analysis downstream possible.
import CoreGraphics
import Foundation

struct PDFGlyph {
    var text: String        // decoded, usually one character
    var font: String        // BaseFont with any subset prefix stripped
    var size: CGFloat       // effective point size, CTM included
    var x: CGFloat
    var y: CGFloat          // baseline
    var width: CGFloat

    var family: PDFFontFamily { PDFFontFamily(font) }
    var right: CGFloat { x + width }
}

/// What a font tells us about the glyphs drawn in it.
enum PDFFontFamily {
    case text          // CMR, CMBX, Times, anything upright and prose-like
    case bold
    case italic
    case mathItalic    // CMMI: variables and Greek
    case mathSymbol    // CMSY: relations and operators
    case mathExtended  // CMEX: big operators and delimiters
    case mono

    init(_ name: String) {
        let n = name.uppercased()
        if n.contains("CMMI") || n.contains("MATHITALIC") || n.contains("MATH-ITALIC") { self = .mathItalic }
        else if n.contains("CMSY") || n.contains("MSAM") || n.contains("MSBM") || n.contains("AMS") { self = .mathSymbol }
        else if n.contains("CMEX") || n.contains("SIZE1") || n.contains("SIZE2") || n.contains("SIZE3") || n.contains("SIZE4") { self = .mathExtended }
        else if n.contains("CMTT") || n.contains("MONO") || n.contains("COURIER") || n.contains("TYPEWRITER") { self = .mono }
        else if n.contains("CMBX") || n.contains("BOLD") { self = .bold }
        else if n.contains("CMTI") || n.contains("ITALIC") || n.contains("OBLIQUE") { self = .italic }
        else { self = .text }
    }

    var isMath: Bool {
        switch self {
        case .mathItalic, .mathSymbol, .mathExtended: return true
        default: return false
        }
    }
}

struct PDFRule {
    var rect: CGRect
    var isHorizontal: Bool { rect.width > rect.height }
}

struct PDFPageContent {
    var glyphs: [PDFGlyph] = []
    var rules: [PDFRule] = []
    var unsupportedFonts: Set<String> = []
    var height: CGFloat = 792
}

private final class FontInfo {
    var base = "?"
    var toUnicode: [Int: String] = [:]
    var widths: [Int: CGFloat] = [:]
    var defaultWidth: CGFloat = 500
    var twoByte = false
}

private final class ScanState {
    var fonts: [String: FontInfo] = [:]
    var font: FontInfo?
    var fontSize: CGFloat = 10
    var charSpacing: CGFloat = 0
    var wordSpacing: CGFloat = 0
    var horizontalScale: CGFloat = 1
    var rise: CGFloat = 0
    var leading: CGFloat = 0
    var tm = CGAffineTransform.identity
    var tlm = CGAffineTransform.identity
    var ctm = CGAffineTransform.identity
    var ctmStack: [CGAffineTransform] = []
    var path: [CGPoint] = []
    var pathRect: CGRect?
    var content = PDFPageContent()
}

enum PDFTextExtractor {

    static func read(page: CGPDFPage) -> PDFPageContent {
        let state = ScanState()
        state.content.height = page.getBoxRect(.mediaBox).height
        var resources: CGPDFDictionaryRef?
        if let dict = page.dictionary {
            CGPDFDictionaryGetDictionary(dict, "Resources", &resources)
        }
        if let resources { loadFonts(resources, into: state) }
        let stream = CGPDFContentStreamCreateWithPage(page)
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(state).toOpaque())
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
        CGPDFContentStreamRelease(stream)
        state.content.glyphs.sort { $0.y == $1.y ? $0.x < $1.x : $0.y > $1.y }
        return state.content
    }

    // MARK: fonts

    private static func loadFonts(_ resources: CGPDFDictionaryRef, into state: ScanState) {
        var fonts: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "Font", &fonts), let fonts else { return }
        CGPDFDictionaryApplyFunction(fonts, { key, value, info in
            let state = Unmanaged<ScanState>.fromOpaque(info!).takeUnretainedValue()
            var dict: CGPDFDictionaryRef?
            guard CGPDFObjectGetValue(value, .dictionary, &dict), let dict else { return }
            let font = FontInfo()

            var base: UnsafePointer<Int8>?
            if CGPDFDictionaryGetName(dict, "BaseFont", &base), let base {
                var name = String(cString: base)
                if let plus = name.firstIndex(of: "+"), name.distance(from: name.startIndex, to: plus) == 6 {
                    name = String(name[name.index(after: plus)...])
                }
                font.base = name
            }

            var subtype: UnsafePointer<Int8>?
            if CGPDFDictionaryGetName(dict, "Subtype", &subtype), let subtype {
                font.twoByte = String(cString: subtype) == "Type0"
            }

            var toUnicode: CGPDFStreamRef?
            if CGPDFDictionaryGetStream(dict, "ToUnicode", &toUnicode), let toUnicode {
                var format = CGPDFDataFormat.raw
                if let data = CGPDFStreamCopyData(toUnicode, &format) as Data? {
                    font.toUnicode = PDFTextExtractor.parseCMap(data)
                }
            }
            if font.toUnicode.isEmpty {
                state.content.unsupportedFonts.insert(font.base)
            }

            var first: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(dict, "FirstChar", &first)
            var widths: CGPDFArrayRef?
            if CGPDFDictionaryGetArray(dict, "Widths", &widths), let widths {
                for i in 0..<CGPDFArrayGetCount(widths) {
                    var value: CGPDFReal = 0
                    if CGPDFArrayGetNumber(widths, i, &value) {
                        font.widths[Int(first) + i] = CGFloat(value)
                    }
                }
            }
            state.fonts[String(cString: key)] = font
        }, Unmanaged.passUnretained(state).toOpaque())
    }

    /// Reads `beginbfchar`/`beginbfrange` sections. Enough of the CMap format for
    /// the maps that real producers emit.
    static func parseCMap(_ data: Data) -> [Int: String] {
        guard let text = String(data: data, encoding: .isoLatin1) else { return [:] }
        var map: [Int: String] = [:]

        func hexValue(_ token: String) -> Int? { Int(token, radix: 16) }

        func decodeTarget(_ token: String) -> String? {
            var out = ""
            var i = token.startIndex
            while token.distance(from: i, to: token.endIndex) >= 4 {
                let j = token.index(i, offsetBy: 4)
                guard let v = UInt32(token[i..<j], radix: 16) else { return nil }
                // surrogate pair
                if v >= 0xD800, v <= 0xDBFF, token.distance(from: j, to: token.endIndex) >= 4 {
                    let k = token.index(j, offsetBy: 4)
                    if let low = UInt32(token[j..<k], radix: 16), low >= 0xDC00, low <= 0xDFFF {
                        let combined = 0x10000 + ((v - 0xD800) << 10) + (low - 0xDC00)
                        if let scalar = Unicode.Scalar(combined) { out.unicodeScalars.append(scalar) }
                        i = k
                        continue
                    }
                }
                if let scalar = Unicode.Scalar(v) { out.unicodeScalars.append(scalar) }
                i = j
            }
            return out.isEmpty ? nil : out
        }

        func tokens(_ section: String) -> [String] {
            var out: [String] = []
            var current = ""
            var inHex = false
            for ch in section {
                if ch == "<" { inHex = true; current = ""; continue }
                if ch == ">" { inHex = false; out.append(current); current = ""; continue }
                if inHex, !ch.isWhitespace { current.append(ch) }
            }
            return out
        }

        for block in text.components(separatedBy: "beginbfchar").dropFirst() {
            let section = block.components(separatedBy: "endbfchar")[0]
            let items = tokens(section)
            var i = 0
            while i + 1 < items.count {
                if let code = hexValue(items[i]), let target = decodeTarget(items[i + 1]) {
                    map[code] = target
                }
                i += 2
            }
        }
        for block in text.components(separatedBy: "beginbfrange").dropFirst() {
            let section = block.components(separatedBy: "endbfrange")[0]
            let items = tokens(section)
            var i = 0
            while i + 2 < items.count {
                if let lo = hexValue(items[i]), let hi = hexValue(items[i + 1]),
                   let start = decodeTarget(items[i + 2]),
                   let scalar = start.unicodeScalars.first, hi >= lo, hi - lo < 4096 {
                    for offset in 0...(hi - lo) {
                        if let mapped = Unicode.Scalar(scalar.value + UInt32(offset)) {
                            map[lo + offset] = String(mapped)
                        }
                    }
                }
                i += 3
            }
        }
        return map
    }

    // MARK: operators

    private static let table: CGPDFOperatorTableRef = {
        let table = CGPDFOperatorTableCreate()!
        func set(_ op: String, _ callback: @escaping CGPDFOperatorCallback) {
            CGPDFOperatorTableSetCallback(table, op, callback)
        }

        set("BT") { _, info in
            let s = state(info)
            s.tm = .identity
            s.tlm = .identity
        }
        set("Tf") { scanner, info in
            let s = state(info)
            s.fontSize = popNumber(scanner)
            var name: UnsafePointer<Int8>?
            if CGPDFScannerPopName(scanner, &name), let name {
                s.font = s.fonts[String(cString: name)]
            }
        }
        set("Td") { scanner, info in
            let s = state(info)
            let ty = popNumber(scanner), tx = popNumber(scanner)
            s.tlm = CGAffineTransform(translationX: tx, y: ty).concatenating(s.tlm)
            s.tm = s.tlm
        }
        set("TD") { scanner, info in
            let s = state(info)
            let ty = popNumber(scanner), tx = popNumber(scanner)
            s.leading = -ty
            s.tlm = CGAffineTransform(translationX: tx, y: ty).concatenating(s.tlm)
            s.tm = s.tlm
        }
        set("Tm") { scanner, info in
            let s = state(info)
            let f = popNumber(scanner), e = popNumber(scanner), d = popNumber(scanner)
            let c = popNumber(scanner), b = popNumber(scanner), a = popNumber(scanner)
            s.tlm = CGAffineTransform(a: a, b: b, c: c, d: d, tx: e, ty: f)
            s.tm = s.tlm
        }
        set("T*") { _, info in
            let s = state(info)
            s.tlm = CGAffineTransform(translationX: 0, y: -s.leading).concatenating(s.tlm)
            s.tm = s.tlm
        }
        set("TL") { scanner, info in state(info).leading = popNumber(scanner) }
        set("Tc") { scanner, info in state(info).charSpacing = popNumber(scanner) }
        set("Tw") { scanner, info in state(info).wordSpacing = popNumber(scanner) }
        set("Tz") { scanner, info in state(info).horizontalScale = popNumber(scanner) / 100 }
        set("Ts") { scanner, info in state(info).rise = popNumber(scanner) }
        set("Tj") { scanner, info in
            let s = state(info)
            var string: CGPDFStringRef?
            if CGPDFScannerPopString(scanner, &string), let string { draw(s, string) }
        }
        set("'") { scanner, info in
            let s = state(info)
            s.tlm = CGAffineTransform(translationX: 0, y: -s.leading).concatenating(s.tlm)
            s.tm = s.tlm
            var string: CGPDFStringRef?
            if CGPDFScannerPopString(scanner, &string), let string { draw(s, string) }
        }
        set("TJ") { scanner, info in
            let s = state(info)
            var array: CGPDFArrayRef?
            guard CGPDFScannerPopArray(scanner, &array), let array else { return }
            for i in 0..<CGPDFArrayGetCount(array) {
                var object: CGPDFObjectRef?
                CGPDFArrayGetObject(array, i, &object)
                guard let object else { continue }
                var string: CGPDFStringRef?
                if CGPDFObjectGetValue(object, .string, &string), let string {
                    draw(s, string)
                } else {
                    var real: CGPDFReal = 0
                    var integer: CGPDFInteger = 0
                    let adjust: CGFloat
                    if CGPDFObjectGetValue(object, .real, &real) { adjust = CGFloat(real) }
                    else if CGPDFObjectGetValue(object, .integer, &integer) { adjust = CGFloat(integer) }
                    else { continue }
                    let shift = -adjust / 1000 * s.fontSize * s.horizontalScale
                    s.tm = CGAffineTransform(translationX: shift, y: 0).concatenating(s.tm)
                }
            }
        }
        set("cm") { scanner, info in
            let s = state(info)
            let f = popNumber(scanner), e = popNumber(scanner), d = popNumber(scanner)
            let c = popNumber(scanner), b = popNumber(scanner), a = popNumber(scanner)
            s.ctm = CGAffineTransform(a: a, b: b, c: c, d: d, tx: e, ty: f).concatenating(s.ctm)
        }
        set("q") { _, info in
            let s = state(info)
            s.ctmStack.append(s.ctm)
        }
        set("Q") { _, info in
            let s = state(info)
            if let last = s.ctmStack.popLast() { s.ctm = last }
        }
        // rules: both the `re` rectangle form and thin stroked lines
        set("re") { scanner, info in
            let s = state(info)
            let h = popNumber(scanner), w = popNumber(scanner)
            let y = popNumber(scanner), x = popNumber(scanner)
            s.pathRect = CGRect(x: x, y: y, width: w, height: h).applying(s.ctm)
        }
        set("m") { scanner, info in
            let s = state(info)
            let y = popNumber(scanner), x = popNumber(scanner)
            s.path = [CGPoint(x: x, y: y).applying(s.ctm)]
        }
        set("l") { scanner, info in
            let s = state(info)
            let y = popNumber(scanner), x = popNumber(scanner)
            s.path.append(CGPoint(x: x, y: y).applying(s.ctm))
        }
        for op in ["f", "F", "f*", "B", "B*", "b", "b*"] {
            set(op) { _, info in
                let s = state(info)
                if let rect = s.pathRect { s.content.rules.append(PDFRule(rect: rect)) }
                s.pathRect = nil
                s.path = []
            }
        }
        for op in ["S", "s"] {
            set(op) { _, info in
                let s = state(info)
                if s.path.count >= 2 {
                    let xs = s.path.map(\.x), ys = s.path.map(\.y)
                    let rect = CGRect(x: xs.min()!, y: ys.min()!,
                                      width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
                    if rect.width > 2 || rect.height > 2 {
                        s.content.rules.append(PDFRule(rect: rect))
                    }
                }
                s.path = []
                s.pathRect = nil
            }
        }
        set("n") { _, info in
            let s = state(info)
            s.path = []
            s.pathRect = nil
        }
        return table
    }()

    private static func state(_ info: UnsafeMutableRawPointer?) -> ScanState {
        Unmanaged<ScanState>.fromOpaque(info!).takeUnretainedValue()
    }

    private static func popNumber(_ scanner: CGPDFScannerRef) -> CGFloat {
        var value: CGPDFReal = 0
        return CGPDFScannerPopNumber(scanner, &value) ? CGFloat(value) : 0
    }

    private static func draw(_ s: ScanState, _ string: CGPDFStringRef) {
        guard let bytes = CGPDFStringGetBytePtr(string) else { return }
        let length = CGPDFStringGetLength(string)
        let font = s.font
        let step = (font?.twoByte ?? false) ? 2 : 1
        var i = 0
        while i + step <= length {
            let code = step == 2 ? Int(bytes[i]) << 8 | Int(bytes[i + 1]) : Int(bytes[i])
            let advanceUnits = font?.widths[code] ?? font?.defaultWidth ?? 500
            let text = font?.toUnicode[code] ?? fallback(code)
            let transform = s.tm.concatenating(s.ctm)
            let size = s.fontSize * sqrt(abs(transform.a * transform.d - transform.b * transform.c))
            let width = advanceUnits / 1000 * size * s.horizontalScale
            if !text.isEmpty, text != " " {
                s.content.glyphs.append(PDFGlyph(
                    text: text,
                    font: font?.base ?? "?",
                    size: size,
                    x: transform.tx,
                    y: transform.ty + s.rise,
                    width: width))
            }
            var advance = advanceUnits / 1000 * s.fontSize + s.charSpacing
            if code == 32, step == 1 { advance += s.wordSpacing }
            s.tm = CGAffineTransform(translationX: advance * s.horizontalScale, y: 0).concatenating(s.tm)
            i += step
        }
    }

    /// No CMap: assume the byte is Latin-1, which is right for plain ASCII text.
    private static func fallback(_ code: Int) -> String {
        guard code >= 32, code < 127, let scalar = Unicode.Scalar(UInt32(code)) else { return "" }
        return String(scalar)
    }
}
