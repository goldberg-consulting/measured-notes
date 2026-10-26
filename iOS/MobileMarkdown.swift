import SwiftUI
import QuickLook
import UniformTypeIdentifiers

private let colors = ["Monochrome", "Gold", "Blue", "Green", "Rose", "Purple", "Slate"]
private func tableTint(_ name: String) -> Color {
    switch name { case "Gold": return .orange; case "Blue": return .blue; case "Green": return .green; case "Rose": return .pink; case "Purple": return .purple; case "Slate": return .gray; default: return .black }
}
struct MobileTableEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var table: MarkdownTable
    var save: (MarkdownTable) -> Void
    @FocusState private var cell: String?
    @State private var removal: String?
    var selection: (Int, Int) { let parts = (cell ?? "0:0").split(separator: ":").compactMap { Int($0) }; return parts.count == 2 ? (min(parts[0], table.cells.count - 1), min(parts[1], table.columns - 1)) : (0, 0) }
    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 1) {
                    ForEach(table.cells.indices, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<table.columns, id: \.self) { column in
                                TextField(row == 0 ? "Heading" : "Value", text: Binding(get: { table.cells[row][column] }, set: { table.cells[row][column] = $0 }), axis: .vertical)
                                    .padding(12).frame(width: 160, alignment: .leading).frame(minHeight: 50)
                                    .background(tableTint(table.style.cells["\(row):\(column)"] ?? table.style.rows[row] ?? table.style.theme).opacity(row == 0 ? 0.2 : 0.08))
                                    .focused($cell, equals: "\(row):\(column)")
                                    .accessibilityLabel("Row \(row), column \(column + 1)")
                            }
                        }
                    }
                }.padding()
            }.navigationTitle("Table").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save(table); dismiss() } }
                    ToolbarItem(placement: .bottomBar) { Menu {
                        Button("Add row below") { table.addRow(after: selection.0) }
                        Button("Add column after") { table.addColumn(after: selection.1) }
                        Button("Remove selected row", role: .destructive) { removal = "row" }.disabled(selection.0 == 0 || table.cells.count <= 2)
                        Button("Remove selected column", role: .destructive) { removal = "column" }.disabled(table.columns <= 1)
                    } label: { Label("Rows and columns", systemImage: "tablecells") } }
                    ToolbarItem(placement: .bottomBar) { Menu {
                        Menu("Table") { ForEach(colors, id: \.self) { color in Button(color) { table.style.theme = color } } }
                        Menu("Selected row") { Button("Reset") { table.style.rows[selection.0] = nil }; ForEach(colors, id: \.self) { color in Button(color) { table.style.rows[selection.0] = color } } }
                        Menu("Selected cell") { Button("Reset") { table.style.cells["\(selection.0):\(selection.1)"] = nil }; ForEach(colors, id: \.self) { color in Button(color) { table.style.cells["\(selection.0):\(selection.1)"] = color } } }
                    } label: { Label("Color", systemImage: "paintpalette") } }
                }
                .confirmationDialog("Remove this \(removal ?? "item") and its contents?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } })) {
                    Button("Remove", role: .destructive) { let selected = selection; if removal == "row" { table.removeRow(selected.0) } else { table.removeColumn(selected.1) }; cell = nil; removal = nil }
                }
                .onAppear { if table.cells.count == 1 { table.addRow() } }
        }
    }
}
struct MobilePreview: View {
    var note: Note
    var edit: (MarkdownTable) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let lines = note.body.components(separatedBy: "\n")
                let tables = MarkdownTable.parse(note.body)
                ForEach(lines.indices, id: \.self) { index in
                    if let table = tables.first(where: { $0.start == index }) {
                        VStack(alignment: .leading) {
                            Button("Edit table", systemImage: "tablecells") { edit(table) }.font(.caption)
                            ScrollView(.horizontal) { VStack(spacing: 1) {
                                ForEach(table.cells.indices, id: \.self) { row in HStack(spacing: 1) {
                                    ForEach(0..<table.columns, id: \.self) { column in
                                        Text(table.cells[row][column]).padding(10).frame(width: 150, alignment: .leading).frame(minHeight: 44)
                                            .background(tableTint(table.style.cells["\(row):\(column)"] ?? table.style.rows[row] ?? table.style.theme).opacity(row == 0 ? 0.2 : 0.08))
                                    }
                                } }
                            } }
                        }
                    } else if tables.contains(where: { index >= $0.start && index < $0.end }) {
                        EmptyView()
                    } else if let image = note.images?.first(where: { $0.markdown == lines[index].trimmingCharacters(in: .whitespaces) }), let rendered = UIImage(data: image.data) {
                        VStack(alignment: .leading) { Image(uiImage: rendered).resizable().scaledToFit().frame(maxWidth: image.width); if !image.caption.isEmpty { Text(image.caption).font(.caption).foregroundStyle(.secondary) } }
                    } else if let document = note.documents?.first(where: { $0.markdown == lines[index].trimmingCharacters(in: .whitespaces) }) {
                        MobileDocumentPreview(document: document)
                    } else {
                        MobileMarkdownLine(lines: lines, index: index)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// SwiftUI Text renders inline Markdown, but block headings need explicit typography.
struct MobileMarkdownLine: View {
    let lines: [String]
    let index: Int
    private var fenced: Bool { MarkdownHeadings.codeLine(lines, at: index) }
    private var line: String { lines[index] }
    private var heading: (Int, String)? { MarkdownHeadings.heading(lines, at: index) }
    var body: some View {
        if fenced { Text(line).font(.body.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
        else if index > 0, !lines[index - 1].trimmingCharacters(in: .whitespaces).isEmpty, MarkdownHeadings.underline(line) != nil && MarkdownHeadings.heading(lines, at: index - 1) != nil { EmptyView() }
        else if let (level, title) = heading {
            Text(inline(title)).font(font(level)).fontWeight(.semibold).accessibilityAddTraits(.isHeader)
                .padding(.top, level <= 2 ? 10 : 4).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        } else {
            Text(inline(line)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func inline(_ value: String) -> AttributedString {
        var rendered = (try? AttributedString(markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(value)
        let plain = String(rendered.characters)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
                guard let url = match.url, ["http", "https", "mailto"].contains(url.scheme ?? ""),
                      let range = Range(match.range, in: plain),
                      let lower = AttributedString.Index(range.lowerBound, within: rendered),
                      let upper = AttributedString.Index(range.upperBound, within: rendered),
                      rendered[lower..<upper].link == nil else { continue }
                rendered[lower..<upper].link = url
            }
        }
        return rendered
    }
    private func font(_ level: Int) -> Font {
        switch level { case 1: return .largeTitle; case 2: return .title; case 3: return .title2; case 4: return .title3; case 5: return .headline; default: return .subheadline }
    }
}

struct MobileDocumentPreview: View {
    let document: NoteDocument
    @State private var previewURL: URL?
    @State private var error = ""
    private var video: Bool {
        guard let type = UTType(filenameExtension: (document.name as NSString).pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }
    var body: some View {
        Button {
            do {
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appendingPathComponent((document.name as NSString).lastPathComponent)
                try document.data.write(to: url, options: .atomic)
                previewURL = url
            } catch { self.error = error.localizedDescription }
        } label: {
            Label(video ? "Play " + document.name : document.name, systemImage: video ? "play.rectangle" : "doc")
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { old, new in
            if new == nil, let old { try? FileManager.default.removeItem(at: old.deletingLastPathComponent()) }
        }
        .alert("Could not open attachment", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) {
            Button("OK") { error = "" }
        } message: { Text(error) }
    }
}
