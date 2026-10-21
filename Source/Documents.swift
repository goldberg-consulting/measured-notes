import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NoteAttachments {
    var images: [NoteImage] = []
    var documents: [NoteDocument] = []
    var markdown: [String] = []
}

@MainActor enum DocumentImport {
    static let extensions: Set<String> = ["pdf", "txt", "text", "md", "markdown", "rtf", "doc", "docx", "odt", "xls", "xlsx", "ods", "csv", "tsv", "ppt", "pptx", "odp", "pages", "numbers", "key", "json", "yaml", "yml", "xml", "epub"]
    static func read(_ urls: [URL]) throws -> NoteAttachments {
        var result = NoteAttachments()
        var total = 0
        // Validate and load the entire drop before modifying the note.
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentTypeKey])
            guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else { throw error("Drop individual document or image files, rather than folders or aliases.") }
            let size = attributes.fileSize ?? 0
            total += size
            guard size <= 25_000_000, total <= 50_000_000 else { throw error("Choose documents under 25 MB each, with no more than 50 MB per drop.") }
            if attributes.contentType?.conforms(to: .image) == true {
                let image = try ImageImport.read(url)
                result.images.append(image); result.markdown.append(image.markdown)
            } else {
                guard extensions.contains(url.pathExtension.lowercased()) else { throw error("Unsupported document: \(url.lastPathComponent). Use a PDF, Office document, spreadsheet, presentation, or text file.") }
                let data = try Data(contentsOf: url)
                guard data.count <= 25_000_000 else { throw error("Choose a document under 25 MB.") }
                let document = NoteDocument(name: url.lastPathComponent, data: data)
                result.documents.append(document); result.markdown.append(document.markdown)
            }
        }
        return result
    }
    static func safeName(_ name: String) -> String {
        let name = (name as NSString).lastPathComponent.replacingOccurrences(of: ":", with: "-")
        return name.isEmpty || name == "." || name == ".." ? "Document" : name
    }
    static func error(_ message: String) -> NSError {
        NSError(domain: "one.measured.notes.documents", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

struct DocumentCard: View {
    let document: NoteDocument
    var remove: () -> Void
    @State private var confirmRemoval = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc")
            VStack(alignment: .leading, spacing: 3) {
                Text(document.name).font(.system(size: 12, weight: .medium)).lineLimit(2)
                Text(ByteCountFormatter.string(fromByteCount: Int64(document.data.count), countStyle: .file)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open") { open() }
            Button("Save…") { save() }
            Button { confirmRemoval = true } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("Remove document from note")
        }.controlSize(.small).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.black.opacity(0.035))
            .confirmationDialog("Remove this attached copy?", isPresented: $confirmRemoval) {
                Button("Remove", role: .destructive, action: remove)
                Button("Cancel", role: .cancel) {}
            } message: { Text("The original file is unchanged.") }
    }
    func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = DocumentImport.safeName(document.name)
        panel.allowedContentTypes = [UTType(filenameExtension: (document.name as NSString).pathExtension) ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try document.data.write(to: url, options: .atomic) }
        catch { NSAlert(error: error).runModal() }
    }
    func open() {
        do {
            let name = DocumentImport.safeName(document.name)
            guard DocumentImport.extensions.contains((name as NSString).pathExtension.lowercased()) else { throw DocumentImport.error("Save this document to inspect it with an application of your choice.") }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("measured-documents").appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(name)
            try document.data.write(to: url, options: .atomic)
            guard NSWorkspace.shared.open(url) else { throw DocumentImport.error("No application could open this file. Use Save to keep a copy.") }
        } catch { NSAlert(error: error).runModal() }
    }
}
