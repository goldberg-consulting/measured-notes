import Foundation
import AppKit

@main struct DocumentChecks {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("Report [final].txt")
        let content = Data("Hello, résumé.\nKeep the original bytes.\u{0}".utf8)
        try content.write(to: file)
        let imported = try DocumentImport.read([file])
        precondition(imported.documents.count == 1 && imported.images.isEmpty)
        precondition(imported.documents[0].data == content)
        precondition(imported.markdown[0].contains("Report \\[final\\].txt"))
        try FileManager.default.removeItem(at: file)
        let note = Note(body: imported.markdown.joined(separator: "\n"), documents: imported.documents)
        let decoded = try JSONDecoder().decode(Note.self, from: JSONEncoder().encode(note))
        precondition(decoded == note && decoded.documents![0].data == content)
        let old = Note()
        let decodedOld = try JSONDecoder().decode(Note.self, from: JSONEncoder().encode(old))
        precondition(decodedOld.documents == nil)
        let unsupported = directory.appendingPathComponent("run.sh")
        try Data("echo no".utf8).write(to: unsupported)
        do { _ = try DocumentImport.read([unsupported]); preconditionFailure("Reject executable types") } catch {}
        do { _ = try DocumentImport.read([directory]); preconditionFailure("Reject directories") } catch {}
        let oversized = directory.appendingPathComponent("large.pdf")
        _ = FileManager.default.createFile(atPath: oversized.path, contents: nil)
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: 25_000_001); try handle.close()
        do { _ = try DocumentImport.read([oversized]); preconditionFailure("Reject oversized files") } catch {}
        let text = directory.appendingPathComponent("empty.txt")
        try Data().write(to: text)
        let empty = try DocumentImport.read([text])
        precondition(empty.documents[0].data.isEmpty)
        let imageURL = directory.appendingPathComponent("image.png")
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 0, bitmap.bytesPerRow * bitmap.pixelsHigh)
        try bitmap.representation(using: .png, properties: [:])!.write(to: imageURL)
        let mixed = try DocumentImport.read([text, imageURL])
        precondition(mixed.documents.count == 1 && mixed.images.count == 1)
        precondition(mixed.markdown == [mixed.documents[0].markdown, mixed.images[0].markdown])
        precondition(DocumentImport.safeName("../../report.pdf") == "report.pdf")
        print("PASS: document bytes, persistence, Markdown escaping, empty files, mixed image/document drops, limits, unsupported types, safe names")
    }
}
