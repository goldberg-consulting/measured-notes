import SwiftUI
import AppKit
import UniformTypeIdentifiers

let accent = Color.black
let ink = Color.white
let panel = Color(white: 0.97)
let muted = Color(white: 0.38)

struct Brand: View {
    var small = false
    var body: some View {
        HStack(spacing: 10) {
            StripeMark().stroke(accent, lineWidth: 1.4).frame(width: small ? 25 : 33, height: small ? 25 : 33)
            VStack(alignment: .leading, spacing: 2) {
                Text("measured.one").font(.system(size: small ? 14 : 16, weight: .semibold, design: .default)).tracking(0.5)
                if !small { Text("NOTES / ACTIONS / IDEAS").font(.system(size: 8, weight: .medium)).tracking(1.8).foregroundStyle(muted) }
            }
        }
    }
}
struct Pill: View {
    var text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .regular, design: .monospaced)).foregroundStyle(muted).padding(.vertical, 4) }
}
struct StripeMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for step in 0..<5 {
            let inset = CGFloat(step) * rect.width / 11
            path.addRect(rect.insetBy(dx: inset, dy: inset))
        }
        return path
    }
}
struct LibraryView: View {
    @AppStorage("iCloudSyncEnabled") private var syncEnabled = true
    @ObservedObject var store: NoteStore
    var capture: () -> Void
    @State private var deleteTarget: UUID?
    @State private var showCollectionSheet = false
    @State private var newCollectionKind = "Folder"
    @State private var organizeNoteID: UUID?
    @State private var listRegions: [String: CGRect] = [:]
    @State private var sidebarRegions: [UUID: CGRect] = [:]
    var listPassThroughRegions: [CGRect] {
        let viewport = listRegions["viewport"] ?? .null
        return listRegions.compactMap { key, rect in
            if key == "search" { return rect }
            return key.hasPrefix("row:") ? rect.intersection(viewport) : nil
        }
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Brand().padding(.top, 34).padding(.bottom, 24)
                Button(action: capture) { HStack { Image(systemName: "bolt.fill"); Text("Quick capture"); Spacer(); Text("⌘⇧T").font(.system(size: 11)) }.padding(12).background(accent, in: RoundedRectangle(cornerRadius: 0)).foregroundStyle(ink) }.buttonStyle(.plain)
                Toggle("iCloud sync", isOn: $syncEnabled).font(.system(size: 11)).padding(.top, 10)
                Text(store.syncStatus).font(.system(size: 9)).foregroundStyle(muted).lineLimit(3)
                Text(store.shortcutStatus).font(.system(size: 9)).foregroundStyle(muted).padding(.top, 9)
                Text("INDEX").font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(muted).padding(.top, 35).padding(.bottom, 14)
                ForEach([("All notes", "square.stack"), ("Pinned", "pin"), ("To-dos", "checkmark.circle"), ("Meetings", "person.2"), ("Reminders", "bell")], id: \.0) { title, icon in
                    Button { store.filter = title; if !store.filtered.contains(where: { $0.id == store.selected }) { store.selected = store.filtered.first?.id } } label: {
                        HStack(spacing: 12) { Image(systemName: icon).frame(width: 18); Text(title); Spacer(); if title == "All notes" { Text("\(store.notes.count)").font(.system(size: 11)) } }
                            .font(.system(size: 12, weight: store.filter == title ? .semibold : .regular)).padding(.vertical, 11).padding(.horizontal, 10).foregroundStyle(store.filter == title ? accent : muted).background(store.filter == title ? accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 0)).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                CollectionSidebar(store: store, manage: { organizeNoteID = nil; showCollectionSheet = true }, createCollection: { kind in newCollectionKind = kind; organizeNoteID = nil; showCollectionSheet = true })
                Rectangle().fill(accent.opacity(0.15)).frame(height: 1)
                Text("MEASURED / ONE").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(accent.opacity(0.8)).padding(.top, 20)
                Text("Private by nature.\nStored on your Mac.").font(.system(size: 11)).lineSpacing(4).foregroundStyle(muted).padding(.top, 9).padding(.bottom, 24)
            }.padding(.horizontal, 20).frame(width: 225).background(ink)
                .coordinateSpace(name: "collection-sidebar")
                .onPreferenceChange(SidebarRegions.self) { sidebarRegions = $0 }
                .overlay {
                    SidebarContextMenu(regions: sidebarRegions, createNote: { kind, collection in
                        if let collection { store.browseCollection(collection) }
                        store.create(kind: kind)
                    }, createCollection: { kind in
                        newCollectionKind = kind; organizeNoteID = nil; showCollectionSheet = true
                    }, manage: { organizeNoteID = nil; showCollectionSheet = true })
                }
            Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack { Text(store.filterTitle).font(.system(size: 19, weight: .medium, design: .serif)); Spacer(); Menu { Button("Note") { store.create() }; Button("Example") { store.create(kind: "Example") }; Button("Checklist") { store.create(kind: "To-do") }; Button("Meeting") { store.create(kind: "Meeting") } } label: { Image(systemName: "square.and.pencil").foregroundStyle(accent) }.menuStyle(.borderlessButton).frame(width: 28) }.padding(20)
                        HStack { Image(systemName: "magnifyingglass"); TextField("Search your thoughts", text: $store.search).textFieldStyle(.plain) }.font(.system(size: 11)).foregroundStyle(muted).padding(10).background(ink.opacity(0.6), in: RoundedRectangle(cornerRadius: 0)).padding(.horizontal, 16).padding(.bottom, 14)
                            .background(GeometryReader { geometry in Color.clear.preference(key: NoteListRegions.self, value: ["search": geometry.frame(in: .named("note-list"))]) })
                        if store.filter == "All notes" {
                            NoteBranchList(store: store, organize: { organizeNoteID = $0; showCollectionSheet = true }, delete: { deleteTarget = $0 })
                        } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(store.filtered) { note in
                                    Button { store.selected = note.id } label: {
                                        VStack(alignment: .leading, spacing: 9) {
                                            HStack { Text(note.kind.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(1.5).foregroundStyle(accent); Spacer(); if note.pinned { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(accent) }; Text(note.updated, format: .dateTime.month(.abbreviated).day()).font(.system(size: 9)).foregroundStyle(muted) }
                                            Text(note.displayTitle).font(.system(size: 15, weight: .medium)).foregroundStyle(.black).lineLimit(2)
                                            Text(note.excerpt.isEmpty ? "A thought waiting to happen…" : note.excerpt).font(.system(size: 11)).foregroundStyle(muted).lineSpacing(3).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                            HStack { ForEach(Array(note.tags.prefix(2)), id: \.self) { Pill(text: "#" + $0) }; Spacer(); if note.openTasks > 0 { Label("\(note.openTasks)", systemImage: "checkmark.circle").font(.system(size: 10)).foregroundStyle(muted) } }
                                        }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(store.selected == note.id ? accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 0)).overlay(RoundedRectangle(cornerRadius: 0).stroke(store.selected == note.id ? accent : .clear))
                                    }.buttonStyle(.plain).contextMenu { Button("Create related note") { store.createRelated(to: note.id) }; creationMenu; Divider(); Button("Assign collections…") { organizeNoteID = note.id; showCollectionSheet = true }; Button(note.pinned ? "Unpin" : "Pin") { store.update(note.id) { $0.pinned.toggle() } }; Button("Delete note", role: .destructive) { deleteTarget = note.id } }
                                        .background(GeometryReader { geometry in Color.clear.preference(key: NoteListRegions.self, value: ["row:" + note.id.uuidString: geometry.frame(in: .named("note-list"))]) })
                                }
                                if store.filtered.isEmpty { Text("No notes here yet.").foregroundStyle(muted).padding(25) }
                            }.padding(.horizontal, 10)
                        }.background(GeometryReader { geometry in Color.clear.preference(key: NoteListRegions.self, value: ["viewport": geometry.frame(in: .named("note-list"))]) })
                        }
                        Text("\(store.filtered.count) thoughts, safely kept").font(.system(size: 10)).foregroundStyle(muted).padding(18)
                    }.frame(width: 285).background(panel)
                        .coordinateSpace(name: "note-list")
                        .onPreferenceChange(NoteListRegions.self) { listRegions = $0 }
                        .overlay {
                            SidebarContextMenu(regions: [:], passThroughRegions: listPassThroughRegions, createNote: { kind, _ in store.create(kind: kind) }, createCollection: { kind in
                                newCollectionKind = kind; organizeNoteID = nil; showCollectionSheet = true
                            }, manage: { organizeNoteID = nil; showCollectionSheet = true })
                        }
                    Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1)
                    if let id = store.selected, store.selectedNote != nil { NoteEditor(store: store, id: id).id(id) }
                    else { VStack(spacing: 15) { Image(systemName: "bolt.shield").font(.system(size: 44)).foregroundStyle(accent); Text("Leave a little lightning here.").font(.system(size: 23, design: .serif)); Button("Create a note") { store.create() } }.frame(maxWidth: .infinity, maxHeight: .infinity) }
                }
            }
        }.background(ink).foregroundStyle(.black).tint(.black).preferredColorScheme(.light).frame(minWidth: 1180, minHeight: 680)
            .sheet(isPresented: $showCollectionSheet) { CollectionsSheet(store: store, noteID: organizeNoteID, startingKind: newCollectionKind) }
            .alert("Delete this note?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) { Button("Cancel", role: .cancel) { deleteTarget = nil }; Button("Delete", role: .destructive) { if let id = deleteTarget { store.delete(id) }; deleteTarget = nil } } message: { Text("This removes the note and its reminder from this Mac.") }
    }
    var creationMenu: some View {
        NewItemsMenu(store: store) { kind in
            newCollectionKind = kind; organizeNoteID = nil; showCollectionSheet = true
        }
    }

}

struct NoteEditor: View {
    @ObservedObject var store: NoteStore
    let id: UUID
    var compact = false
    @State private var showActions = false
    @State private var actionSourceWindow: NSWindow?
    @State private var showCollections = false
    @State private var preview = false
    @State private var editingTable: MarkdownTable?
    @State private var showTablePicker = false
    @State private var tableInsertion: NSRange?
    @State private var insertionSource = ""
    @State private var tableRows = 3
    @State private var tableColumns = 3
    @State private var showPerson = false
    @State private var person = ""
    @State private var showReminder = false
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @FocusState private var focused: Bool
    @FocusState private var focusedAction: UUID?
    var note: Note { store.notes.first { $0.id == id } ?? Note() }
    func changeImage(_ image: NoteImage) {
        store.update(id) { note in
            if let index = note.images?.firstIndex(where: { $0.id == image.id }) { note.images?[index] = image }
        }
    }
    func removeImage(_ imageID: UUID) {
        store.update(id) { note in
            if let image = note.images?.first(where: { $0.id == imageID }) {
                note.body = note.body.replacingOccurrences(of: image.markdown, with: "")
            }
            note.images?.removeAll { $0.id == imageID }
        }
    }
    func importImages(_ pasteboard: NSPasteboard) -> String? {
        do {
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            if !urls.isEmpty { return try addFiles(urls) }
            return addImages(try ImageImport.read(pasteboard))
        }
        catch { NSAlert(error: error).runModal(); return nil }
    }
    func addFiles(_ urls: [URL]) throws -> String? {
        let imported = try DocumentImport.read(urls)
        guard !imported.markdown.isEmpty else { return nil }
        store.update(id) {
            $0.images = ($0.images ?? []) + imported.images
            $0.documents = ($0.documents ?? []) + imported.documents
        }
        return imported.markdown.joined(separator: "\n")
    }
    func chooseDocuments() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = DocumentImport.extensions.compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK else { return }
        do { if let markdown = try addFiles(panel.urls) { store.update(id) { $0.body += "\n" + markdown + "\n" } } }
        catch { NSAlert(error: error).runModal() }
    }
    func removeDocument(_ documentID: UUID) {
        store.update(id) { note in
            if let document = note.documents?.first(where: { $0.id == documentID }) { note.body = note.body.replacingOccurrences(of: document.markdown, with: "") }
            note.documents?.removeAll { $0.id == documentID }
        }
    }
    func addImages(_ images: [NoteImage]) -> String? {
        guard !images.isEmpty else { return nil }
        store.update(id) { $0.images = ($0.images ?? []) + images }
        return images.map(\.markdown).joined(separator: "\n")
    }
    func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        do {
            if let markdown = addImages(try panel.urls.map { try ImageImport.read($0) }) {
                store.update(id) { $0.body += "\n" + markdown + "\n" }
            }
        } catch { NSAlert(error: error).runModal() }
    }
    func textBinding(_ key: WritableKeyPath<Note, String>) -> Binding<String> { Binding(get: { note[keyPath: key] }, set: { value in store.update(id) { $0[keyPath: key] = value } }) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 15) {
                Menu { ForEach(["Note", "To-do", "Meeting", "Example"], id: \.self) { kind in Button(kind) { store.update(id) { $0.kind = kind } } } } label: { Label(note.kind, systemImage: note.kind == "Meeting" ? "person.2" : "doc.text").font(.system(size: 11)).foregroundStyle(muted) }.menuStyle(.borderlessButton).frame(width: 100)
                Spacer()
                Menu { Button("Related note") { store.createRelated(to: id) }; Button("Related meeting") { store.createRelated(to: id, kind: "Meeting") } } label: { Image(systemName: "arrow.triangle.branch") }.menuStyle(.borderlessButton).frame(width: 22).help("Create a separate note linked to this one")
                Button { showCollections = true } label: { Label("Organize", systemImage: "folder") }.help("Assign folders, products, and flows")
                Button { store.update(id) { $0.pinned.toggle() } } label: { Image(systemName: note.pinned ? "pin.fill" : "pin") }.help("Pin note")
                Button { showReminder = true } label: { Image(systemName: "bell.badge") }.help("Set a reminder")
                Button { if showActions { showActions = false } else { openActions() } } label: { Image(systemName: "at") }.help("Share or add a person")
            }.buttonStyle(.plain).foregroundStyle(accent).padding(.bottom, 12)
            if note.kind == "Meeting" { MeetingControls(store: store, noteID: id).padding(.bottom, 12) }
            TextField("Untitled spark", text: textBinding(\.title), axis: .vertical).font(.system(size: compact ? 25 : 29, weight: .medium, design: .serif)).textFieldStyle(.plain).padding(.bottom, 10)
            HStack { Text(note.updated, format: .dateTime.month(.wide).day().hour().minute()); Text("·"); Text("\(note.body.split { $0.isWhitespace || $0.isNewline }.count) words") }.font(.system(size: 10)).foregroundStyle(muted).padding(.bottom, 10)
            NoteRelations(store: store, note: note)
            if !store.collections(for: note).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.collections(for: note)) { collection in
                            Button { showCollections = true } label: { Label(collection.kind + ": " + collection.name, systemImage: collection.icon).font(.system(size: 10, design: .monospaced)) }.buttonStyle(.plain).foregroundStyle(muted)
                        }
                    }
                }.padding(.bottom, 12)
            }
            if !note.exportMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("RUNNING SUMMARY").font(.system(size: 9, weight: .semibold)).tracking(1.5)
                        Spacer()
                        Text(store.summaryStatus[id] ?? "This note only").font(.system(size: 9)).foregroundStyle(muted)
                    }
                    if !note.summary.isEmpty { Text(note.summary).font(.system(size: 13)).lineSpacing(4).fixedSize(horizontal: false, vertical: true) }
                    else { Text("A summary of this note and its actions will appear here.").font(.system(size: 12)).foregroundStyle(muted) }
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(panel).padding(.bottom, 10)
            }
            if !note.people.isEmpty || note.reminder != nil {
                HStack { ForEach(note.people, id: \.self) { name in Menu { Button("Remove person") { store.update(id) { $0.people.removeAll { $0 == name } } } } label: { Pill(text: "@" + name) }.menuStyle(.borderlessButton).fixedSize() }; if let date = note.reminder { Menu { Button("Cancel reminder") { store.cancelReminder(id) } } label: { Label(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "bell").font(.system(size: 10)).foregroundStyle(accent) }.menuStyle(.borderlessButton) } }.padding(.bottom, 12)
            }
            HStack(spacing: 12) {
                Picker("Editor mode", selection: $preview) { Text("Markdown").tag(false); Text("Preview").tag(true) }.pickerStyle(.segmented).labelsHidden().frame(width: 180)
                Spacer()
                Button { chooseDocuments() } label: { Image(systemName: "paperclip") }.buttonStyle(.plain).help("Attach documents")
                Button { chooseImages() } label: { Image(systemName: "photo.badge.plus") }.buttonStyle(.plain).help("Add images")
                Menu {
                    Button("New table…") { tableInsertion = nil; showTablePicker = true }
                    ForEach(Array(MarkdownTable.parse(note.body).enumerated()), id: \.element.id) { index, table in
                        Button("Edit table \(index + 1)") { editingTable = table }
                    }
                } label: { Label("Table", systemImage: "tablecells").foregroundStyle(accent) }.menuStyle(.borderlessButton).frame(width: 80)
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(note.exportMarkdown, forType: .string); store.status = "Markdown copied" } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("Copy Markdown, including table colors")
            }.padding(.bottom, 12)
            HStack(alignment: .top, spacing: 14) {
                Group {
            if preview {
                MarkdownPreview(source: note.body, documents: note.documents ?? [], removeDocument: removeDocument, images: note.images ?? [], changeImage: changeImage, removeImage: removeImage) { editingTable = $0 }.frame(maxHeight: .infinity)
                    .dropDestination(for: URL.self) { urls, _ in
                        do {
                            guard let markdown = try addFiles(urls) else { return false }
                            store.update(id) { $0.body += "\n" + markdown + "\n" }
                            return true
                        } catch { NSAlert(error: error).runModal(); return false }
                    }
            } else {
                VStack(spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if note.body.isEmpty { Text("Let the thought land.\n\nWrite Markdown. Type /table on a new line for a table.").font(.system(size: 14)).foregroundStyle(muted.opacity(0.65)).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                    MarkdownEditor(text: textBinding(\.body), focus: focused, importImages: importImages) { range in
                        tableInsertion = range; insertionSource = note.body; showTablePicker = true
                    }
                }
                }
            }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ACTIONS  ·  \(note.openTasks) OPEN").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(accent)
                        Spacer()
                        Button { addAction() } label: { Label("Add action", systemImage: "plus") }.buttonStyle(.plain).font(.system(size: 10)).help("Add an action")
                    }
                    if note.tasks.isEmpty { Text("Add an action to this note.").font(.system(size: 12)).foregroundStyle(muted).padding(.vertical, 8) }
                    ScrollView { VStack(alignment: .leading, spacing: 12) {
                        ForEach(note.tasks) { task in
                            HStack(spacing: 9) {
                                Button { changeAction(task.id) { $0.completed.toggle() } } label: { Image(systemName: task.completed ? "checkmark.circle.fill" : "circle").foregroundStyle(accent) }
                                    .buttonStyle(.plain).help(task.completed ? "Mark incomplete" : "Complete action")
                                    .accessibilityLabel(task.completed ? "Mark action incomplete" : "Complete action")
                                TextField(task.parentID == nil ? "New action" : "New sub-item", text: Binding(get: {
                                    note.tasks.first { $0.id == task.id }?.text ?? ""
                                }, set: { text in changeAction(task.id) { $0.text = text } }), axis: .vertical)
                                    .textFieldStyle(.plain).strikethrough(task.completed).foregroundStyle(task.completed ? muted : accent)
                                    .accessibilityLabel(task.parentID == nil ? "Action text" : "Sub-item text")
                                    .focused($focusedAction, equals: task.id)
                                Menu {
                                    Button(task.parentID == nil ? "Add sub-item" : "Add sibling sub-item") { addSubitem(to: task.id) }
                                    if task.parentID != nil { Button("Make top-level action") { store.update(id) { $0.promoteAction(task.id) } } }
                                } label: { Image(systemName: "ellipsis").foregroundStyle(muted) }.menuStyle(.borderlessButton).frame(width: 18).help("Action options")
                                Button { store.update(id) { $0.removeAction(task.id) } } label: { Image(systemName: "minus.circle").foregroundStyle(muted) }
                                    .buttonStyle(.plain).help("Remove action").accessibilityLabel("Remove action")
                            }.font(.system(size: 12)).padding(.leading, task.parentID == nil ? 0 : 18)
                                .contextMenu {
                                    Button(task.parentID == nil ? "Add sub-item" : "Add sibling sub-item") { addSubitem(to: task.id) }
                                    if task.parentID != nil { Button("Make top-level action") { store.update(id) { $0.promoteAction(task.id) } } }
                                }
                        }
                    } }.frame(maxHeight: .infinity)
                    if !(note.documents ?? []).isEmpty || !(note.images ?? []).isEmpty {
                        Divider()
                        AttachmentSidebar(images: note.images ?? [], documents: note.documents ?? [], changeImage: changeImage, removeImage: removeImage, removeDocument: removeDocument)
                    }
                }.padding(.top, 6).frame(width: 220, alignment: .topLeading).frame(maxHeight: .infinity)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack { ForEach(Array(note.tags.prefix(compact ? 2 : 4)), id: \.self) { Pill(text: "#" + $0) }; Spacer(); Button { addAction() } label: { Label("Add action", systemImage: "checklist").font(.system(size: 10)) }.buttonStyle(.plain).foregroundStyle(accent) }.padding(.vertical, 12)
            HStack { Circle().fill(store.status.hasPrefix("Saved") ? Color.black : accent).frame(width: 4, height: 4); Text(store.status).lineLimit(2); Text(store.syncStatus).lineLimit(2); Spacer(); Text("@ to connect") }.font(.system(size: 9)).foregroundStyle(muted)
        }.padding(compact ? 16 : 20).frame(maxWidth: .infinity, maxHeight: .infinity).background(ink).foregroundStyle(.black).tint(.black).preferredColorScheme(.light)
            .onAppear { if compact { focused = true } }
            .onChange(of: note.body) { old, new in
                if new.count > old.count && new.hasSuffix("@") { openActions() }
                if new != old && (new == "/table" || new.hasSuffix("\n/table")) { tableInsertion = nil; showTablePicker = true }
            }
            .sheet(isPresented: $showCollections) { CollectionsSheet(store: store, noteID: id) }
            .sheet(isPresented: $showTablePicker) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A table, without the pipes.").font(.system(size: 24, design: .serif))
                    Stepper("Rows: \(tableRows)", value: $tableRows, in: 1...50)
                    Stepper("Columns: \(tableColumns)", value: $tableColumns, in: 1...12)
                    Text("Includes a header row. Add more rows and columns as you go.").font(.caption).foregroundStyle(muted)
                    HStack { Button("Cancel") { showTablePicker = false }; Spacer(); Button("Create table") {
                        showTablePicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { editingTable = .blank(rows: tableRows, columns: tableColumns) }
                    }.keyboardShortcut(.defaultAction) }
                }.padding(24).frame(width: 390).preferredColorScheme(.light)
            }
            .sheet(item: $editingTable) { table in
                TableComposer(table: table) { changed in
                    store.update(id) { note in
                        if changed.start < 0 && (note.body == "/table" || note.body.hasSuffix("\n/table")) { note.body = String(note.body.dropLast(6)) }
                        if changed.start < 0, let range = tableInsertion, note.body == insertionSource {
                            let source = note.body as NSString
                            let position = min(range.location, source.length)
                            // Insert at the caret; preserve selected text instead of replacing it.
                            note.body = source.replacingCharacters(in: NSRange(location: position, length: 0), with: "\n\n" + changed.storedMarkdown + "\n\n")
                        } else { note.body = changed.replacing(in: note.body) }
                    }
                    tableInsertion = nil
                    preview = true
                }
            }
            .popover(isPresented: $showActions) {
                ConnectMenu(sourceWindow: actionSourceWindow, select: { index in
                    switch index {
                    case 0: share(.composeEmail)
                    case 1: share(.composeMessage)
                    default: showActions = false; showPerson = true
                    }
                }, dismiss: { showActions = false })
            }
            .sheet(isPresented: $showPerson) {
                VStack(alignment: .leading, spacing: 18) { Text("Who’s part of this thought?").font(.title3); TextField("Name, email, or phone", text: $person).textFieldStyle(.roundedBorder); Text("People are local note labels. This does not invite or notify them.").font(.caption).foregroundStyle(muted); HStack { Button("Cancel") { showPerson = false }; Spacer(); Button("Add person") { let name = person.trimmingCharacters(in: .whitespacesAndNewlines); if !name.isEmpty { store.update(id) { if !$0.people.contains(name) { $0.people.append(name) }; if $0.body.hasSuffix("@") { $0.body.removeLast() } }; person = ""; showPerson = false } }.disabled(person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).keyboardShortcut(.defaultAction) } }.padding(24).frame(width: 360)
            }
            .sheet(isPresented: $showReminder) {
                VStack(alignment: .leading, spacing: 20) { Text("Bring this thought back.").font(.title2); DatePicker("Remind me", selection: $reminderDate, in: Date()...); Text("A notification on this Mac, at the time you choose.").font(.caption).foregroundStyle(muted); HStack { Button("Cancel") { showReminder = false }; Spacer(); Button("Set reminder") { Task { await store.remind(id, at: reminderDate) }; showReminder = false }.keyboardShortcut(.defaultAction) } }.padding(24).frame(width: 400)
            }
    }
    func addAction() {
        let task = NoteAction()
        store.update(id) { if $0.actions == nil { $0.actions = [] }; $0.actions?.append(task) }
        focusedAction = task.id
    }
    func addSubitem(to actionID: UUID) {
        var child: UUID?
        store.update(id) { child = $0.addSubitem(to: actionID) }
        focusedAction = child
    }
    func changeAction(_ actionID: UUID, _ change: (inout NoteAction) -> Void) {
        store.update(id) { note in
            guard let index = note.actions?.firstIndex(where: { $0.id == actionID }) else { return }
            change(&note.actions![index])
        }
    }
    func openActions() { actionSourceWindow = NSApp.keyWindow; showActions = true }
    func share(_ name: NSSharingService.Name) {
        showActions = false
        if note.body.hasSuffix("@") { store.update(id) { $0.body.removeLast() } }
        guard let service = NSSharingService(named: name) else { store.status = "Sharing service unavailable on this Mac"; return }
        let content = note.displayTitle + "\n\n" + note.exportMarkdown
        guard service.canPerform(withItems: [content]) else { store.status = "Set up Mail or Messages to share this note"; return }
        service.subject = note.displayTitle
        service.perform(withItems: [content])
    }
}

struct CaptureView: View {
    @ObservedObject var store: NoteStore
    var id: UUID
    var dismiss: () -> Void
    var browse: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack { Brand(small: true); Spacer(); Text("QUICK CAPTURE").font(.system(size: 8, weight: .semibold)).tracking(1.5).foregroundStyle(accent); Button(action: dismiss) { Image(systemName: "xmark").foregroundStyle(muted) }.buttonStyle(.plain).keyboardShortcut(.escape, modifiers: []) }.padding(.horizontal, 24).padding(.vertical, 18)
            Rectangle().fill(accent.opacity(0.15)).frame(height: 1)
            NoteEditor(store: store, id: id, compact: true).id(id)
            HStack { Button(action: browse) { Label("Open sanctuary", systemImage: "sidebar.left") }.buttonStyle(.plain).foregroundStyle(muted); Spacer(); Button(action: dismiss) { Text("Keep this thought  ↵").font(.system(size: 12, weight: .semibold)).padding(.horizontal, 16).padding(.vertical, 10).background(accent, in: RoundedRectangle(cornerRadius: 0)).foregroundStyle(ink) }.buttonStyle(.plain).keyboardShortcut(.return, modifiers: .command) }.font(.system(size: 11)).padding(.horizontal, 24).padding(.bottom, 10)
        }.background(ink).foregroundStyle(.black).tint(.black).preferredColorScheme(.light)
    }
}
