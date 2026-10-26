import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MobileNoteEditor: View {
    @ObservedObject var store: NoteStore
    let id: UUID
    @EnvironmentObject var recorder: MobileMeetingRecorder
    @State private var meetings = false
    @State private var connect = false
    @State private var preview = false
    @State private var inspector = false
    @State private var table: MarkdownTable?
    @State private var share = false
    @State private var organize = false
    @State private var importFiles = false
    @State private var photo: PhotosPickerItem?
    @State private var addPerson = false
    @State private var remind = false
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var error = ""
    var note: Note { store.notes.first { $0.id == id } ?? Note() }
    func text(_ key: WritableKeyPath<Note, String>) -> Binding<String> {
        Binding(get: { note[keyPath: key] }, set: { value in store.update(id) { $0[keyPath: key] = value } })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Untitled note", text: text(\.title), axis: .vertical).font(.system(.title, design: .serif)).padding(.horizontal)
            if !note.summary.isEmpty {
                DisclosureGroup("Summary") { Text(note.summary).font(.callout).frame(maxWidth: .infinity, alignment: .leading) }.padding(.horizontal)
            }
            if let origin = store.notes.first(where: { $0.id == note.originID }) {
                Button { store.openNote(origin.id) } label: { Label("From: " + origin.displayTitle, systemImage: "arrow.turn.up.left").lineLimit(1) }.font(.caption).padding(.horizontal)
            }
            let related = store.notes.filter { $0.originID == id }
            if !related.isEmpty {
                Menu("Related notes (\(related.count))") { ForEach(related) { child in Button(child.displayTitle) { store.openNote(child.id) } } }.font(.caption).padding(.horizontal)
            }
            if note.kind == "Meeting" || !(note.recordings ?? []).isEmpty || recorder.noteID == id {
                Button { meetings = true } label: { Label(recorder.noteID == id ? recorder.phase : "Meeting recordings", systemImage: recorder.noteID == id ? "record.circle" : "mic") }.padding(.horizontal)
            }
            if preview { MobilePreview(note: note, edit: { table = $0 }).padding(.horizontal) }
            else { MobileMarkdownInput(text: text(\.body), importMedia: importMedia, reportError: { error = $0 }).padding(.horizontal, 12) }
        }.padding(.top, 8)
            .navigationTitle(note.kind).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem { Button(preview ? "Edit Markdown" : "Preview", systemImage: preview ? "pencil" : "eye") { preview.toggle() } }
                ToolbarItem { Button("Actions and attachments", systemImage: "checklist") { inspector.toggle() } }
                ToolbarItem { Menu {
                    Button("Record meeting", systemImage: "mic") { meetings = true }
                    Button("Create related note", systemImage: "arrow.triangle.branch") { store.createRelated(to: id) }
                    Button("New table", systemImage: "tablecells") { table = .blank(rows: 3, columns: 3) }
                    ForEach(Array(MarkdownTable.parse(note.body).enumerated()), id: \.element.id) { index, value in Button("Edit table \(index + 1)") { table = value } }
                    Button("Attach files", systemImage: "paperclip") { importFiles = true }
                    PhotosPicker(selection: $photo, matching: .any(of: [.images, .videos])) { Label("Add photo or video", systemImage: "photo") }
                    Button("Assign collections", systemImage: "folder") { organize = true }
                    Button("Add person", systemImage: "person.badge.plus") { addPerson = true }
                    Button("Set reminder", systemImage: "bell") { remind = true }
                    if note.reminder != nil { Button("Cancel reminder") { store.cancelReminder(id) } }
                    Button(note.pinned ? "Unpin" : "Pin", systemImage: "pin") { store.update(id) { $0.pinned.toggle() } }
                    Button("Share", systemImage: "square.and.arrow.up") { share = true }
                } label: { Label("Note options", systemImage: "ellipsis.circle") } }
            }
            .inspector(isPresented: $inspector) {
                MobileInspector(store: store, id: id)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Actions and attachments").font(.headline)
                                Spacer()
                                Button("Done") { inspector = false }
                                    .fontWeight(.semibold)
                                    .accessibilityHint("Return to the note")
                            }.padding()
                            Divider()
                        }.background(.background)
                    }
                    .inspectorColumnWidth(min: 220, ideal: 280, max: 360)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $meetings) { MobileMeetings(store: store, id: id) }
            .sheet(item: $table) { value in MobileTableEditor(table: value) { result in store.update(id) { $0.body = result.replacing(in: $0.body) } } }
            .sheet(isPresented: $share) { MobileShare(items: [note.displayTitle + "\n\n" + note.exportMarkdown]) }
            .sheet(isPresented: $organize) {
                NavigationStack { List {
                    ForEach(store.collections) { collection in
                        Toggle(collection.name, isOn: Binding(get: { (note.collectionIDs ?? []).contains(collection.id) }, set: { store.assign(id, to: collection.id, included: $0) }))
                    }
                    if store.collections.isEmpty { Text("Create collections in the Index.") }
                }.navigationTitle("Collections").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { organize = false } } } }
            }
            .sheet(isPresented: $remind) {
                NavigationStack { Form { DatePicker("Remind me", selection: $reminderDate, in: Date()...) }.navigationTitle("Reminder").toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { remind = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await store.remind(id, at: reminderDate); remind = false } } }
                } }
            }
            .onChange(of: note.body) { before, after in
                if after.hasSuffix("@"), !before.hasSuffix("@") { connect = true }
            }
            .confirmationDialog("Connect", isPresented: $connect, titleVisibility: .visible) {
                Button("Share by email or Messages") { removeAt(); share = true }
                Button("Add person") { removeAt(); addPerson = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $addPerson) { MobilePeopleEditor(store: store, id: id) }
            .alert("Could not attach file", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) { Button("OK") { error = "" } } message: { Text(error) }
            .fileImporter(isPresented: $importFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                do { for url in try result.get() { try attach(url) } } catch { self.error = error.localizedDescription }
            }
            .onChange(of: photo) { _, item in
                Task {
                    guard let item else { return }
                    do {
                        let transfer = try await item.loadTransferable(type: MobilePickedMedia.self)
                        if let transfer {
                            let markdown = try importMedia(transfer.data, transfer.name, transfer.type)
                            store.update(id) { $0.body += "\n" + markdown + "\n" }
                        }
                    } catch { self.error = error.localizedDescription }
                    photo = nil
                }
            }
    }
    func removeAt() { if note.body.hasSuffix("@") { store.update(id) { $0.body.removeLast() } } }
    func importMedia(_ data: Data, _ name: String, _ type: UTType) throws -> String {
        guard store.notes.contains(where: { $0.id == id }) else { throw CocoaError(.fileNoSuchFile) }
        guard data.count <= MobileMediaTransfer.limit else { throw CocoaError(.fileReadTooLarge) }
        if type.conforms(to: .image) { return try addImage(data, name: name) }
        let attachment = NoteDocument(name: name, data: data)
        store.update(id) { $0.documents = ($0.documents ?? []) + [attachment] }
        return attachment.markdown
    }
    func addImage(_ data: Data, name: String) throws -> String {
        guard data.count <= 30 * 1024 * 1024, let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
        let scale = min(1, 2400 / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: format).pngData { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        let attachment = NoteImage(name: name, data: normalized)
        store.update(id) { $0.images = ($0.images ?? []) + [attachment] }
        return attachment.markdown
    }
    func attach(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentTypeKey])
        guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= MobileMediaTransfer.limit else { throw CocoaError(.fileReadTooLarge) }
        let data = try Data(contentsOf: url)
        let markdown = try importMedia(data, url.lastPathComponent, values.contentType ?? .data)
        store.update(id) { $0.body += "\n" + markdown + "\n" }
    }
}

struct MobileInspector: View {
    @ObservedObject var store: NoteStore
    let id: UUID
    @State private var shareURL: URL?
    @State private var people = false
    @State private var error = ""
    var note: Note { store.notes.first { $0.id == id } ?? Note() }
    var body: some View {
        List {
            Section("Actions · \(note.openTasks) open") {
                ForEach(note.tasks) { action in
                    HStack {
                        Button { change(action.id) { $0.completed.toggle() } } label: { Image(systemName: action.completed ? "checkmark.circle.fill" : "circle").frame(minWidth: 32, minHeight: 44) }.buttonStyle(.borderless)
                        TextField("Action", text: Binding(get: { note.tasks.first { $0.id == action.id }?.text ?? "" }, set: { value in change(action.id) { $0.text = value } }), axis: .vertical).strikethrough(action.completed)
                    }.padding(.leading, action.parentID == nil ? 0 : 16)
                        .contextMenu {
                            Button("Add subitem") { store.update(id) { $0.addSubitem(to: action.id) } }
                            if action.parentID != nil { Button("Make top-level") { store.update(id) { $0.promoteAction(action.id) } } }
                            Button("Remove", role: .destructive) { store.update(id) { $0.removeAction(action.id) } }
                        }
                }
                Button("Add action", systemImage: "plus") { store.update(id) { $0.actions = ($0.actions ?? []) + [NoteAction()] } }
            }
            Section("Images") {
                ForEach(note.images ?? []) { image in
                    DisclosureGroup(image.name) {
                        if let uiImage = UIImage(data: image.data) { Image(uiImage: uiImage).resizable().scaledToFit().frame(maxWidth: image.width) }
                        TextField("Caption", text: Binding(get: { note.images?.first { $0.id == image.id }?.caption ?? "" }, set: { value in imageChange(image.id) { $0.caption = value } }))
                        Slider(value: Binding(get: { note.images?.first { $0.id == image.id }?.width ?? 400 }, set: { value in imageChange(image.id) { $0.width = value } }), in: 100...1000).accessibilityLabel("Image width")
                        Button("Remove image", role: .destructive) { store.update(id) { $0.images?.removeAll { $0.id == image.id }; $0.body = $0.body.replacingOccurrences(of: image.markdown, with: "") } }
                    }
                }
            }
            Section("Documents") {
                ForEach(note.documents ?? []) { document in
                    Button(document.name, systemImage: "doc") {
                        do {
                            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            let url = folder.appendingPathComponent((document.name as NSString).lastPathComponent)
                            try document.data.write(to: url, options: .atomic); shareURL = url
                        } catch { self.error = error.localizedDescription }
                    }.contextMenu { Button("Remove", role: .destructive) { store.update(id) { $0.documents?.removeAll { $0.id == document.id }; $0.body = $0.body.replacingOccurrences(of: document.markdown, with: "") } } }
                }
            }
            Section { Button("Manage people", systemImage: "person.badge.plus") { people = true }; ForEach(note.people, id: \.self) { person in Text(person).contextMenu { Button("Remove") { store.update(id) { $0.people.removeAll { $0 == person } } } } } }
            if !note.tags.isEmpty { Section("Tags") { Text(note.tags.map { "#" + $0 }.joined(separator: " ")) } }
            if let reminder = note.reminder { Section("Reminder") { Text(reminder, format: .dateTime) } }
        }.listStyle(.insetGrouped)
            .sheet(isPresented: $people) { MobilePeopleEditor(store: store, id: id) }
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { MobileShare(items: [shareURL]) } }
            .alert("Could not open document", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) { Button("OK") { error = "" } } message: { Text(error) }
    }
    func change(_ actionID: UUID, _ body: (inout NoteAction) -> Void) { store.update(id) { note in if let i = note.actions?.firstIndex(where: { $0.id == actionID }) { body(&note.actions![i]) } } }
    func imageChange(_ imageID: UUID, _ body: (inout NoteImage) -> Void) { store.update(id) { note in if let i = note.images?.firstIndex(where: { $0.id == imageID }) { body(&note.images![i]) } } }
}
