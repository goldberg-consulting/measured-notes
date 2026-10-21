import SwiftUI

struct AttachmentSidebar: View {
    let images: [NoteImage]
    let documents: [NoteDocument]
    var changeImage: (NoteImage) -> Void
    var removeImage: (UUID) -> Void
    var removeDocument: (UUID) -> Void
    @State private var expanded = true
    @State private var selectedImage: UUID?
    @State private var showImage = false
    var count: Int { images.count + documents.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { expanded.toggle() } label: {
                HStack {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    Text("ATTACHMENTS · \(count)").tracking(1)
                    Spacer()
                }.font(.system(size: 9, weight: .semibold)).contentShape(Rectangle())
            }.buttonStyle(.plain).help(expanded ? "Collapse attachments" : "Expand attachments")
            if expanded {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(documents) { document in
                            DocumentCard(document: document, compact: true) { removeDocument(document.id) }
                        }
                        ForEach(images) { image in
                            Button { selectedImage = image.id; showImage = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo").frame(width: 16)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(image.name).lineLimit(1)
                                        Text(image.caption.isEmpty ? "Image · resize or caption" : image.caption).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "slider.horizontal.3").font(.caption)
                                }.font(.system(size: 11)).padding(6).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).background(Color.black.opacity(0.025)).help(image.name)
                        }
                    }
                }
            }
        }.frame(height: expanded ? min(190, CGFloat(count) * 44 + 26) : 20, alignment: .top)
            .sheet(isPresented: $showImage) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Image").font(.title3); Spacer(); Button("Done") { showImage = false } }
                    if let image = images.first(where: { $0.id == selectedImage }) {
                        NoteImageCard(image: image, change: changeImage) { removeImage(image.id); showImage = false }
                    }
                }.padding(20).frame(width: 520)
            }
    }
}
