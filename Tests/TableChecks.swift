import Foundation
@main struct TableChecks {
    static func main() throws {
        var t = MarkdownTable.blank(rows: 2, columns: 3)
        t.cells[1] = ["A | B", "C\\D", "**bold** & <value>\nnext"]
        t.style.theme = "Blue"; t.style.rows[1] = "Green"; t.style.cells["2:1"] = "Rose"
        let source = "# Heading\n\n" + t.storedMarkdown + "\n\nAfter"
        let parsed = MarkdownTable.parse(source)
        precondition(parsed.count == 1)
        precondition(parsed[0].cells == t.cells)
        precondition(parsed[0].style == t.style)
        precondition(parsed[0].replacing(in: source) == source)
        t.addRow(after: 0); precondition(t.style.rows[2] == "Green" && t.style.cells["3:1"] == "Rose")
        t.addColumn(after: 0); precondition(t.style.cells["3:2"] == "Rose")
        t.removeRow(1); t.removeColumn(0); precondition(t.style.cells["2:1"] == "Rose")
        precondition(MarkdownTable.parse("```\n| A | B |\n| --- | --- |\n| 1 | 2 |\n```").isEmpty)
        let pasted = MarkdownTable.parse("A | B\n:--- | ---:\na\\|b | value\n\nend")
        precondition(pasted.count == 1 && pasted[0].cells[1][0] == "a|b")
        precondition(MarkdownTable.parse(source + "\n\n" + t.storedMarkdown).count == 2)
        print("PASS: Markdown round-trip, colors, text escaping, table replacement, row/column color remapping, pasted tables, multiple tables, fenced code")
    }
}
