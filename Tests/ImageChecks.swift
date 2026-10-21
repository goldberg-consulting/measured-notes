import AppKit
import Foundation

@main struct ImageChecks {
    @MainActor static func main() throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3200, pixelsHigh: 1600, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 128, bitmap.bytesPerRow * bitmap.pixelsHigh)
        let original = bitmap.representation(using: .png, properties: [:])!
        let imported = try ImageImport.decode(original, name: "Test.png")
        let normalized = NSBitmapImageRep(data: imported.data)!
        precondition(normalized.pixelsWide == 2400 && normalized.pixelsHigh == 1200)
        precondition(imported.width == 400 && imported.caption.isEmpty)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setData(original, forType: .png)
        let pasted = try ImageImport.read(pasteboard)
        precondition(pasted.count == 1)
        pasteboard.clearContents(); pasteboard.setString("ordinary text", forType: .string)
        let textImages = try ImageImport.read(pasteboard)
        precondition(textImages.isEmpty)
        do { _ = try ImageImport.decode(Data("not an image".utf8), name: "Bad"); preconditionFailure("Must reject invalid image") } catch {}
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.png")
        try original.write(to: source)
        let image = try ImageImport.read(source)
        try FileManager.default.removeItem(at: source)
        var note = Note(body: image.markdown, images: [image])
        note.images![0].caption = "Optional caption"; note.images![0].width = 180
        let decoded = try JSONDecoder().decode(Note.self, from: JSONEncoder().encode(note))
        precondition(decoded == note && NSImage(data: decoded.images![0].data) != nil)
        print("PASS: image validation, proportional normalization, clipboard, self-contained storage, caption/width persistence")
    }
}
