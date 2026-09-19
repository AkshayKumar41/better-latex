// Draws the app icon: parchment tile, brass rule, a summation glyph.
import AppKit
import CoreGraphics
import CoreText
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./build/icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(_ size: Int) -> Data? {
    let s = CGFloat(size)
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = s * 0.215
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [CGColor(srgbRed: 0.145, green: 0.153, blue: 0.180, alpha: 1),
                  CGColor(srgbRed: 0.078, green: 0.082, blue: 0.098, alpha: 1)]
    if let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                             colors: colors as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    }
    // brass rule along the baseline, like a ruled sheet
    ctx.setFillColor(CGColor(srgbRed: 0.855, green: 0.678, blue: 0.318, alpha: 1))
    ctx.fill(CGRect(x: rect.minX, y: rect.minY + rect.height * 0.135, width: rect.width, height: max(s * 0.016, 1)))
    ctx.restoreGState()

    // glyph
    let fontSize = s * 0.56
    let font = CTFontCreateWithName("Times New Roman" as CFString, fontSize, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: CGColor(srgbRed: 0.965, green: 0.953, blue: 0.929, alpha: 1),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "\u{2211}", attributes: attrs))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textPosition = CGPoint(x: (s - bounds.width) / 2 - bounds.minX,
                               y: (s - bounds.height) / 2 - bounds.minY + s * 0.045)
    CTLineDraw(line, ctx)

    guard let image = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])
}

let plan: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in plan {
    guard let data = draw(size) else { continue }
    try? data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
print("icon sizes written to \(outDir)")
