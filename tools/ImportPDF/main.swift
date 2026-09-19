// Converts a PDF to BetterLaTeX English. Usage: importpdf <in.pdf> [out.bltx]
import CoreGraphics
import Foundation
import PDFKit

let url = URL(fileURLWithPath: CommandLine.arguments[1])

if url.pathExtension.lowercased() == "tex" {
    let tex = try! String(contentsOf: url, encoding: .utf8)
    let converted = TeXImport.convert(tex)
    FileHandle.standardError.write("math runs \(converted.mathRuns)\n".data(using: .utf8)!)
    if CommandLine.arguments.count > 2 {
        try! converted.source.write(toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8)
    } else {
        print(converted.source)
    }
    exit(0)
}

guard let doc = PDFDocument(url: url) else { exit(1) }
var pages: [PDFPageContent] = []
for i in 0..<doc.pageCount {
    guard let page = doc.page(at: i)?.pageRef else { continue }
    pages.append(PDFTextExtractor.read(page: page))
}
let result = PDFToEnglish.convert(pages, title: url.deletingPathExtension().lastPathComponent)
FileHandle.standardError.write("pages \(result.pages), math runs \(result.mathRuns), notes \(result.notes.count)\n".data(using: .utf8)!)
if CommandLine.arguments.count > 2 {
    try! result.source.write(toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8)
} else {
    print(result.source)
}
