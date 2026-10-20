import Foundation

struct TableStyle: Codable, Equatable {
    var theme = "Monochrome"
    var rows: [Int: String] = [:]
    var cells: [String: String] = [:]
}

struct MarkdownTable: Identifiable, Equatable {
    var start: Int
    var end: Int
    var cells: [[String]]
    var style = TableStyle()
    var id: Int { start }
    var columns: Int { cells.first?.count ?? 0 }
    static func blank(rows: Int, columns: Int) -> MarkdownTable {
        MarkdownTable(start: -1, end: -1, cells: [(1...columns).map { "Column \($0)" }] + Array(repeating: Array(repeating: "", count: columns), count: rows))
    }
    var markdown: String {
        func escape(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\\", with: "&#92;").replacingOccurrences(of: "|", with: "&#124;").replacingOccurrences(of: "\n", with: "<br>")
        }
        var lines = cells.map { "| " + $0.map(escape).joined(separator: " | ") + " |" }
        lines.insert("| " + Array(repeating: "---", count: columns).joined(separator: " | ") + " |", at: 1)
        return lines.joined(separator: "\n")
    }
    var storedMarkdown: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(style)) ?? Data()
        return "<!-- measured-table:\(data.base64EncodedString()) -->\n" + markdown
    }
    mutating func addRow(after row: Int? = nil) {
        let target = min(cells.count, (row ?? (cells.count - 1)) + 1)
        remap(row: { $0 >= target ? $0 + 1 : $0 }, column: { $0 })
        cells.insert(Array(repeating: "", count: columns), at: target)
    }
    mutating func addColumn(after column: Int? = nil) {
        let target = min(columns, (column ?? (columns - 1)) + 1)
        remap(row: { $0 }, column: { $0 >= target ? $0 + 1 : $0 })
        for r in cells.indices { cells[r].insert(r == 0 ? "Column \(target + 1)" : "", at: target) }
    }
    mutating func removeRow(_ index: Int) {
        guard index > 0, cells.indices.contains(index), cells.count > 2 else { return }
        remap(row: { $0 == index ? nil : ($0 > index ? $0 - 1 : $0) }, column: { $0 })
        cells.remove(at: index)
    }
    mutating func removeColumn(_ index: Int) {
        guard index >= 0, index < columns, columns > 1 else { return }
        remap(row: { $0 }, column: { $0 == index ? nil : ($0 > index ? $0 - 1 : $0) })
        for r in cells.indices { cells[r].remove(at: index) }
    }
    private mutating func remap(row: (Int) -> Int?, column: (Int) -> Int?) {
        var rows: [Int: String] = [:]; var colors: [String: String] = [:]
        for (r, color) in style.rows { if let next = row(r) { rows[next] = color } }
        for (key, color) in style.cells {
            let parts = key.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2, let r = row(parts[0]), let c = column(parts[1]) { colors["\(r):\(c)"] = color }
        }
        style.rows = rows; style.cells = colors
    }
    func replacing(in body: String) -> String {
        var lines = body.components(separatedBy: "\n")
        if start >= 0, end <= lines.count { lines.replaceSubrange(start..<end, with: [storedMarkdown]) }
        else { if !body.isEmpty { lines.append("") }; lines.append(storedMarkdown); lines.append("") }
        return lines.joined(separator: "\n")
    }
    static func parse(_ body: String) -> [MarkdownTable] {
        let lines = body.components(separatedBy: "\n")
        var result: [MarkdownTable] = []; var i = 0; var fenced = false
        while i + 1 < lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") { fenced.toggle(); i += 1; continue }
            guard !fenced, let headers = split(lines[i]), let divider = split(lines[i + 1]), headers.count == divider.count,
                  divider.allSatisfy({ $0.range(of: "^:?-{3,}:?$", options: .regularExpression) != nil }) else { i += 1; continue }
            var table = MarkdownTable(start: i, end: i + 2, cells: [headers])
            if i > 0 {
                let metadata = lines[i - 1].trimmingCharacters(in: .whitespaces)
                if metadata.hasPrefix("<!-- measured-table:"), metadata.hasSuffix(" -->"),
                   let data = Data(base64Encoded: String(metadata.dropFirst(20).dropLast(4))), let style = try? JSONDecoder().decode(TableStyle.self, from: data) {
                    table.start = i - 1; table.style = style
                }
            }
            i += 2
            while i < lines.count, let row = split(lines[i]), row.count <= headers.count {
                table.cells.append(row + Array(repeating: "", count: headers.count - row.count)); i += 1
            }
            table.end = i
            result.append(table)
        }
        return result
    }
    private static func split(_ line: String) -> [String]? {
        var value = line.trimmingCharacters(in: .whitespaces)
        guard value.contains("|") else { return nil }
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") && !value.hasSuffix("\\|") { value.removeLast() }
        var fields: [String] = []; var current = ""; var escaped = false
        for c in value {
            if escaped { if c != "|" && c != "\\" { current.append("\\") }; current.append(c); escaped = false }
            else if c == "\\" { escaped = true }
            else if c == "|" { fields.append(current); current = "" }
            else { current.append(c) }
        }
        if escaped { current.append("\\") }; fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: "&#124;", with: "|").replacingOccurrences(of: "&#92;", with: "\\").replacingOccurrences(of: "&amp;", with: "&") }
    }
}
