import Foundation

enum MarkdownHeadings {
    static func underline(_ line: String) -> Int? {
        let value = line.trimmingCharacters(in: .whitespaces)
        if !value.isEmpty && value.allSatisfy({ $0 == "=" }) { return 1 }
        if !value.isEmpty && value.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }
    static func codeLine(_ lines: [String], at index: Int) -> Bool {
        var fence: (Character, Int)?
        for i in 0...index {
            let value = lines[i].trimmingCharacters(in: .whitespaces)
            let marker = value.first
            let count = value.prefix(while: { $0 == marker }).count
            if let active = fence {
                if marker == active.0, count >= active.1, value.dropFirst(count).trimmingCharacters(in: .whitespaces).isEmpty { fence = nil }
                if i == index { return true }
            } else if let marker, (marker == "`" || marker == "~"), count >= 3 {
                fence = (marker, count)
                if i == index { return true }
            } else if i == index { return lines[i].hasPrefix("    ") || lines[i].hasPrefix("\t") }
        }
        return false
    }
    static func heading(_ lines: [String], at index: Int) -> (level: Int, text: String)? {
        guard !codeLine(lines, at: index) else { return nil }
        let value = lines[index].trimmingCharacters(in: .whitespaces)
        let count = value.prefix(while: { $0 == "#" }).count
        if (1...6).contains(count), value.count == count || value.dropFirst(count).first?.isWhitespace == true {
            let title = String(value.dropFirst(count)).trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"\s+#+\s*$"#, with: "", options: .regularExpression)
            return (count, title)
        }
        if !value.isEmpty, index + 1 < lines.count, let level = underline(lines[index + 1]), !codeLine(lines, at: index + 1) { return (level, value) }
        return nil
    }
}
