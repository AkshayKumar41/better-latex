// Deliberate palette: scholarly brass + slate teal on warm paper greys.
// Chrome colors follow the system appearance; the preview page stays paper.
import AppKit
import SwiftUI

enum Palette {
    static func dyn(_ light: NSColor, _ dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    static let editorBG = dyn(NSColor(srgbRed: 0.992, green: 0.988, blue: 0.980, alpha: 1),
                              NSColor(srgbRed: 0.086, green: 0.090, blue: 0.102, alpha: 1))
    static let panelBG = dyn(NSColor(srgbRed: 0.957, green: 0.949, blue: 0.937, alpha: 1),
                             NSColor(srgbRed: 0.071, green: 0.075, blue: 0.086, alpha: 1))
    static let surround = dyn(NSColor(srgbRed: 0.914, green: 0.902, blue: 0.882, alpha: 1),
                              NSColor(srgbRed: 0.063, green: 0.067, blue: 0.078, alpha: 1))
    static let ink = dyn(NSColor(srgbRed: 0.106, green: 0.106, blue: 0.118, alpha: 1),
                         NSColor(srgbRed: 0.909, green: 0.898, blue: 0.878, alpha: 1))
    static let muted = dyn(NSColor(srgbRed: 0.435, green: 0.427, blue: 0.408, alpha: 1),
                           NSColor(srgbRed: 0.545, green: 0.537, blue: 0.518, alpha: 1))
    static let brass = dyn(NSColor(srgbRed: 0.580, green: 0.408, blue: 0.075, alpha: 1),
                           NSColor(srgbRed: 0.855, green: 0.678, blue: 0.318, alpha: 1))
    static let teal = dyn(NSColor(srgbRed: 0.078, green: 0.376, blue: 0.384, alpha: 1),
                          NSColor(srgbRed: 0.435, green: 0.733, blue: 0.690, alpha: 1))
    static let mathBG = dyn(NSColor(srgbRed: 0.078, green: 0.376, blue: 0.384, alpha: 0.055),
                            NSColor(srgbRed: 0.435, green: 0.733, blue: 0.690, alpha: 0.085))
    static let border = dyn(NSColor(srgbRed: 0.851, green: 0.835, blue: 0.808, alpha: 1),
                            NSColor(srgbRed: 0.180, green: 0.188, blue: 0.204, alpha: 1))
    static let selection = dyn(NSColor(srgbRed: 0.580, green: 0.408, blue: 0.075, alpha: 0.20),
                               NSColor(srgbRed: 0.855, green: 0.678, blue: 0.318, alpha: 0.26))

    static var inkC: Color { Color(nsColor: ink) }
    static var mutedC: Color { Color(nsColor: muted) }
    static var brassC: Color { Color(nsColor: brass) }
    static var tealC: Color { Color(nsColor: teal) }
    static var panelC: Color { Color(nsColor: panelBG) }
    static var editorC: Color { Color(nsColor: editorBG) }
    static var surroundC: Color { Color(nsColor: surround) }
    static var borderC: Color { Color(nsColor: border) }
}
