import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

@MainActor enum ImageImport {
    static func read(_ pasteboard: NSPasteboard) throws -> [NoteImage] {
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        if !urls.isEmpty { return try urls.map { try read($0) } }
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            return [try decode(data, name: "Pasted image")]
        }
        return []
    }
    static func read(_ url: URL) throws -> NoteImage {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 20_000_000 else { throw error("Choose an image smaller than 20 MB.") }
        return try decode(Data(contentsOf: url), name: url.lastPathComponent)
    }
    static func decode(_ data: Data, name: String) throws -> NoteImage {
        guard data.count <= 20_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400
              ] as CFDictionary),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw error("Choose a supported image under 20 MB, such as PNG, JPEG, HEIC, or GIF.")
        }
        return NoteImage(name: name, data: png, width: min(400, Double(image.width)))
    }
    static func error(_ text: String) -> NSError {
        NSError(domain: "one.measured.notes.images", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

struct NoteImageCard: View {
    let image: NoteImage
    var change: (NoteImage) -> Void
    var remove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bitmap = NSImage(data: image.data) {
                Image(nsImage: bitmap).resizable().scaledToFit()
                    .frame(maxWidth: max(80, min(1200, image.width)), maxHeight: 360, alignment: .leading)
                    .accessibilityLabel(image.caption.isEmpty ? image.name : image.caption)
            }
            TextField("Add a caption…", text: Binding(get: { image.caption }, set: { var updated = image; updated.caption = $0; change(updated) }))
                .textFieldStyle(.plain).font(.caption)
            HStack {
                Text("Width").font(.caption)
                Slider(value: Binding(get: { max(80, min(1200, image.width)) }, set: { var updated = image; updated.width = $0; change(updated) }), in: 80...1200, step: 10)
                    .accessibilityLabel("Image display width")
                Text("\(Int(image.width)) pt").font(.caption).monospacedDigit()
                Button(action: remove) { Image(systemName: "trash") }.buttonStyle(.plain).help("Remove image from note")
            }.frame(maxWidth: 400)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.black.opacity(0.03))
    }
}
