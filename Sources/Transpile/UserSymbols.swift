// User-defined shortcuts. One plain text file, one entry per line:
//
//     qed = blacksquare
//     hess = matrix [f_xx, f_xy; f_yx, f_yy]
//     grad f = nabla f
//
// The right side is ordinary BetterLaTeX English, so a shortcut can be built out
// of other shortcuts, and raw LaTeX works too because backslashes pass through.
import Foundation

final class UserSymbols {
    static let shared = UserSymbols()

    /// Override for tests.
    static var pathOverride: String? = ProcessInfo.processInfo.environment["BLTX_SHORTCUTS"]

    private let lock = NSLock()
    private var table: [String: String] = [:]
    private var longestKey = 1
    private var stamp: Date?

    var url: URL {
        if let override = Self.pathOverride { return URL(fileURLWithPath: override) }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BetterLaTeX", isDirectory: true)
        return base.appendingPathComponent("shortcuts.conf")
    }

    var maxWords: Int {
        lock.lock(); defer { lock.unlock() }
        return longestKey
    }

    var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return table.isEmpty
    }

    /// Every shortcut, sorted, for display.
    var entries: [(String, String)] {
        lock.lock(); defer { lock.unlock() }
        return table.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    func lookup(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return table[key]
    }

    /// Cheap enough to call before every render: one stat, then parse only on change.
    func reloadIfChanged() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modified = attrs?[.modificationDate] as? Date
        if modified == stamp, !(stamp == nil && modified != nil) { return }
        stamp = modified
        load()
    }

    func load() {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            lock.lock(); table = [:]; longestKey = 1; lock.unlock()
            return
        }
        var parsed: [String: String] = [:]
        var longest = 1
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("//") { continue }
            guard let split = line.firstIndex(of: "=") else { continue }
            let key = line[line.startIndex..<split]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
                .split(separator: " ")
                .joined(separator: " ")
            let value = line[line.index(after: split)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { continue }
            parsed[key] = value
            longest = max(longest, key.split(separator: " ").count)
        }
        lock.lock()
        table = parsed
        longestKey = longest
        lock.unlock()
    }

    /// Appends a shortcut and reloads. Replaces an existing entry with the same trigger.
    @discardableResult
    func add(trigger: String, expansion: String) -> String? {
        let key = trigger.trimmingCharacters(in: .whitespaces).lowercased()
            .split(separator: " ").joined(separator: " ")
        let value = expansion.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return "The shortcut needs a trigger word." }
        guard !value.isEmpty else { return "The shortcut needs something to expand to." }
        guard !key.contains("=") else { return "A trigger cannot contain an equals sign." }

        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var lines = (try? String(contentsOf: url, encoding: .utf8))?.components(separatedBy: .newlines) ?? []
        if lines.isEmpty { lines = Self.header }
        var replaced = false
        for (i, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let split = line.firstIndex(of: "=") else { continue }
            let existing = line[line.startIndex..<split].trimmingCharacters(in: .whitespaces).lowercased()
                .split(separator: " ").joined(separator: " ")
            if existing == key {
                lines[i] = "\(key) = \(value)"
                replaced = true
                break
            }
        }
        if !replaced { lines.append("\(key) = \(value)") }
        do {
            try (lines.joined(separator: "\n") + (replaced ? "" : "\n")).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return "Could not write \(url.path): \(error.localizedDescription)"
        }
        stamp = nil
        reloadIfChanged()
        return nil
    }

    func remove(trigger: String) {
        let key = trigger.lowercased()
        guard var text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let kept = text.components(separatedBy: .newlines).filter { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let split = line.firstIndex(of: "=") else { return true }
            return line[line.startIndex..<split].trimmingCharacters(in: .whitespaces).lowercased() != key
        }
        text = kept.joined(separator: "\n")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        stamp = nil
        reloadIfChanged()
    }

    /// Creates the file with its explanation the first time it is needed.
    func createIfMissing() {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? Self.header.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        stamp = nil
        reloadIfChanged()
    }

    static let header = [
        "# BetterLaTeX shortcuts. One per line: trigger = what it expands to.",
        "# The right side is ordinary English, so shortcuts can use other shortcuts,",
        "# and raw LaTeX works too. Lines starting with # are ignored.",
        "# Saving this file updates every open document immediately.",
        "",
        "qed = blacksquare",
        "hess = matrix [f_xx, f_xy; f_yx, f_yy]",
        "expect = bold E",
        "",
    ]
}
