import SwiftUI
import AppKit

let tableColors = ["Monochrome", "Gold", "Blue", "Green", "Rose", "Purple", "Slate"]
func tableColor(_ name: String) -> Color {
    switch name { case "Gold": return Color(red: 0.65, green: 0.49, blue: 0.18); case "Blue": return .cyan; case "Green": return .green; case "Rose": return .pink; case "Purple": return .purple; case "Slate": return .gray; default: return accent }
}
func inlineMarkdown(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
}

struct TableComposer: View {
    @Environment(\.dismiss) private var dismiss
    @State var table: MarkdownTable
    var commit: (MarkdownTable) -> Void
    @State private var selectedRow = 0
    @State private var selectedColumn = 0
    @State private var confirmRemoval = false
    @State private var removalRow: Int?
    @State private var removalColumn: Int?
    @FocusState private var focus: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Image(systemName: "tablecells").foregroundStyle(accent); Text(table.start < 0 ? "Create a table" : "Edit table").font(.system(size: 24, design: .serif)); Spacer(); Text("\(table.cells.count - 1) rows × \(table.columns) columns").foregroundStyle(muted).font(.caption) }
            HStack(spacing: 12) {
                Button { table.addRow(); select(table.cells.count - 1, 0) } label: { Label("Row", systemImage: "plus") }.keyboardShortcut("r", modifiers: [.command, .shift])
                Button { table.addColumn(); select(0, table.columns - 1) } label: { Label("Column", systemImage: "plus") }
                Button { requestRemoval(row: selectedRow == 0 ? table.cells.count - 1 : selectedRow) } label: { Label("Row", systemImage: "minus") }
                    .disabled(table.cells.count <= 2).help("Remove the selected row; when a header is selected, remove the last row")
                Button { requestRemoval(column: selectedColumn) } label: { Label("Column", systemImage: "minus") }
                    .disabled(table.columns <= 1).help("Remove the selected column")
                Menu("Selected cell") {
                    Button("Insert row below") { table.addRow(after: selectedRow); select(selectedRow + 1, selectedColumn) }
                    Button("Insert column after") { table.addColumn(after: selectedColumn); select(selectedRow, selectedColumn + 1) }
                    Divider()
                    Button("Delete row…", role: .destructive) { requestRemoval(row: selectedRow) }.disabled(selectedRow == 0 || table.cells.count <= 2)
                    Button("Delete column…", role: .destructive) { requestRemoval(column: selectedColumn) }.disabled(table.columns <= 1)
                }.fixedSize()
                Spacer()
                Menu { ForEach(tableColors, id: \.self) { color in Button(color) { table.style.theme = color } } } label: { Label("Table color", systemImage: "paintpalette").foregroundStyle(tableColor(table.style.theme)) }.fixedSize()
            }.controlSize(.small)
            HStack(spacing: 8) {
                Text("Color:").foregroundStyle(muted)
                Menu("Row \(selectedRow == 0 ? "header" : String(selectedRow))") { colorOptions { table.style.rows[selectedRow] = $0 } }.fixedSize()
                Menu("Cell") { colorOptions { table.style.cells["\(selectedRow):\(selectedColumn)"] = $0 } }.fixedSize()
                Spacer(); Text("Minimum: 1 row + header, 1 column").foregroundStyle(muted)
            }.font(.caption)
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 1) {
                    ForEach(table.cells.indices, id: \.self) { r in
                        HStack(spacing: 1) {
                            ForEach(0..<table.columns, id: \.self) { c in
                                TextField(r == 0 ? "Heading" : "", text: Binding(get: { table.cells[r][c] }, set: { table.cells[r][c] = $0 }), axis: .vertical)
                                    .textFieldStyle(.plain).font(.system(size: 13, weight: r == 0 ? .semibold : .regular))
                                    .padding(12).frame(width: 155, alignment: .leading).frame(minHeight: 46)
                                    .background(tableColor(table.style.cells["\(r):\(c)"] ?? table.style.rows[r] ?? table.style.theme).opacity(r == 0 ? 0.3 : 0.13))
                                    .overlay(Rectangle().stroke(selectedRow == r && selectedColumn == c ? accent : Color.black.opacity(0.08), lineWidth: 1))
                                    .focused($focus, equals: "\(r):\(c)")
                                    .accessibilityLabel("Row \(r == 0 ? "header" : String(r)), column \(c + 1)")
                            }
                        }
                    }
                }.padding(2)
            }.background(ink, in: RoundedRectangle(cornerRadius: 0))
            HStack { Text("Markdown content · colors kept in this app").font(.caption).foregroundStyle(muted); Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Save table") { commit(table); dismiss() }.keyboardShortcut(.defaultAction).tint(accent) }
        }.padding(24).frame(width: 740, height: 500).background(ink).foregroundStyle(.black).tint(.black).preferredColorScheme(.light)
            .onAppear { if table.cells.count == 1 { table.addRow() }; select(0, 0) }
            .onChange(of: focus) { _, value in
                if let parts = value?.split(separator: ":").compactMap({ Int($0) }), parts.count == 2 { selectedRow = parts[0]; selectedColumn = parts[1] }
            }
            .confirmationDialog(removalRow.map { "Remove row \($0)?" } ?? "Remove column \((removalColumn ?? 0) + 1)?", isPresented: $confirmRemoval) {
                Button("Remove", role: .destructive) { applyRemoval() }
                Button("Cancel", role: .cancel) { removalRow = nil; removalColumn = nil }
            } message: { Text("This contains text. Changes are applied only when you save the table.") }
    }
    func requestRemoval(row: Int? = nil, column: Int? = nil) {
        removalRow = row; removalColumn = column
        let hasText: Bool
        if let row { hasText = table.cells[row].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        else if let column { hasText = table.cells.contains { !$0[column].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        else { return }
        if hasText { confirmRemoval = true } else { applyRemoval() }
    }
    func applyRemoval() {
        if let row = removalRow { table.removeRow(row) }
        if let column = removalColumn { table.removeColumn(column) }
        select(min(selectedRow, table.cells.count - 1), min(selectedColumn, table.columns - 1))
        removalRow = nil; removalColumn = nil
    }
    func select(_ r: Int, _ c: Int) { selectedRow = r; selectedColumn = c; focus = "\(r):\(c)" }
    @ViewBuilder func colorOptions(_ set: @escaping (String?) -> Void) -> some View {
        Button("Use table color") { set(nil) }
        ForEach(tableColors, id: \.self) { color in Button(color) { set(color) } }
    }
}

struct TablePreview: View {
    let table: MarkdownTable
    var edit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Label("\(table.cells.count - 1) rows · \(table.columns) columns", systemImage: "tablecells").font(.caption).foregroundStyle(muted); Spacer(); Button("Edit table", action: edit).font(.caption).foregroundStyle(accent) }
            ScrollView(.horizontal) {
                VStack(spacing: 1) {
                    ForEach(table.cells.indices, id: \.self) { r in
                        HStack(spacing: 1) {
                            ForEach(0..<table.columns, id: \.self) { c in
                                Text(inlineMarkdown(table.cells[r][c].isEmpty ? " " : table.cells[r][c])).font(.system(size: 13, weight: r == 0 ? .semibold : .regular)).textSelection(.enabled)
                                    .padding(12).frame(width: 155, alignment: .leading).frame(minHeight: 42, maxHeight: .infinity, alignment: .topLeading)
                                    .background(tableColor(table.style.cells["\(r):\(c)"] ?? table.style.rows[r] ?? table.style.theme).opacity(r == 0 ? 0.3 : 0.13))
                            }
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                }.background(Color.black.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 0))
            }
        }.padding(.vertical, 8)
    }
}

struct MarkdownPreview: View {
    let source: String
    var images: [NoteImage] = []
    var changeImage: (NoteImage) -> Void = { _ in }
    var removeImage: (UUID) -> Void = { _ in }
    var editTable: (MarkdownTable) -> Void
    struct Block: Identifiable {
        var id: Int
        var text: String = ""
        var kind = "text"
        var table: MarkdownTable?
    }
    var blocks: [Block] {
        let lines = source.components(separatedBy: "\n")
        let tables = Dictionary(uniqueKeysWithValues: MarkdownTable.parse(source).map { ($0.start, $0) })
        var blocks: [Block] = []; var i = 0
        while i < lines.count {
            if let table = tables[i] { blocks.append(Block(id: i, table: table)); i = table.end; continue }
            let line = lines[i]
            if line.hasPrefix("```") {
                let start = i; i += 1; var code: [String] = []
                while i < lines.count && !lines[i].hasPrefix("```") { code.append(lines[i]); i += 1 }
                blocks.append(Block(id: start, text: code.joined(separator: "\n"), kind: "code")); i += 1; continue
            }
            blocks.append(Block(id: i, text: line)); i += 1
        }
        return blocks
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 9) {
                if source.isEmpty { Text("Your Markdown preview will appear here.").foregroundStyle(muted) }
                ForEach(blocks) { block in
                    if let table = block.table { TablePreview(table: table) { editTable(table) } }
                    else if block.kind == "code" { Text(block.text).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 0)) }
                    else if let image = images.first(where: { $0.markdown == block.text.trimmingCharacters(in: .whitespaces) }) {
                        NoteImageCard(image: image, change: changeImage) { removeImage(image.id) }
                    }
                    else { lineView(block.text) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
        }
    }
    @ViewBuilder func lineView(_ line: String) -> some View {
        if line.isEmpty { Color.clear.frame(height: 7) }
        else if line == "---" || line == "***" { Divider() }
        else if line.hasPrefix("# ") { Text(inlineMarkdown(String(line.dropFirst(2)))).font(.system(size: 25, weight: .semibold, design: .serif)).textSelection(.enabled) }
        else if line.hasPrefix("## ") { Text(inlineMarkdown(String(line.dropFirst(3)))).font(.system(size: 20, weight: .semibold)).textSelection(.enabled) }
        else if line.hasPrefix("### ") { Text(inlineMarkdown(String(line.dropFirst(4)))).font(.system(size: 16, weight: .semibold)).textSelection(.enabled) }
        else if line.hasPrefix("> ") { HStack { Rectangle().fill(accent).frame(width: 2); Text(inlineMarkdown(String(line.dropFirst(2)))).foregroundStyle(muted).textSelection(.enabled); Spacer() }.padding(.vertical, 6) }
        else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") { Label { Text(inlineMarkdown(String(line.dropFirst(6)))).strikethrough(line.hasPrefix("- [x]")) } icon: { Image(systemName: line.hasPrefix("- [x]") ? "checkmark.circle.fill" : "circle").foregroundStyle(accent) } }
        else if line.hasPrefix("- ") || line.hasPrefix("* ") { HStack(alignment: .top) { Text("•").foregroundStyle(accent); Text(inlineMarkdown(String(line.dropFirst(2)))).textSelection(.enabled) } }
        else { Text(inlineMarkdown(line)).font(.system(size: 14)).textSelection(.enabled) }
    }
}
