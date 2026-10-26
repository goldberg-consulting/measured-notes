import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MobilePeopleEditor: View {
    @ObservedObject var store: NoteStore
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var names: [String] { store.notes.first { $0.id == id }?.people ?? [] }
    var body: some View {
        NavigationStack {
            Form {
                Section("Add a person") {
                    TextField("Name or email", text: $name).textContentType(.name).onSubmit(add)
                    Button("Add", action: add).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("People on this note") {
                    ForEach(names, id: \.self) { Text($0) }
                        .onDelete { offsets in
                            let removed = offsets.map { names[$0] }
                            store.update(id) { $0.people.removeAll { removed.contains($0) } }
                        }
                    if names.isEmpty { Text("No people added yet.").foregroundStyle(.secondary) }
                }
                Text("People are labels on this note. Adding someone does not send an invitation.").font(.caption).foregroundStyle(.secondary)
            }.navigationTitle("People").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func add() {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        store.update(id) { if !$0.people.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) { $0.people.append(value) } }
        name = ""
    }
}

struct MobilePickedMedia: Transferable {
    let data: Data
    let name: String
    let type: UTType
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { try load($0.file, fallback: .movie) }
        FileRepresentation(importedContentType: .image) { try load($0.file, fallback: .image) }
    }
    private static func load(_ url: URL, fallback: UTType) throws -> Self {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        guard (values.fileSize ?? Int.max) <= MobileMediaTransfer.limit else { throw CocoaError(.fileReadTooLarge) }
        let data = try Data(contentsOf: url)
        guard data.count <= MobileMediaTransfer.limit else { throw CocoaError(.fileReadTooLarge) }
        let type = values.contentType ?? fallback
        return Self(data: data, name: MobileMediaTransfer.name(url.lastPathComponent, type: type), type: type)
    }
}
