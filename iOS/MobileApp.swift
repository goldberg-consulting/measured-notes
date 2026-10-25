import SwiftUI
import UIKit

@main struct MeasuredNotesMobileApp: App {
    @StateObject private var store = NoteStore()
    var body: some Scene {
        WindowGroup {
            MobileLibrary(store: store)
                .tint(.primary)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    if url.scheme == "measurednotes", url.host == "capture" { store.create() }
                }
        }
    }
}

struct MobileLibrary: View {
    @ObservedObject var store: NoteStore
    @State private var visibility: NavigationSplitViewVisibility = .all
    @State private var preferred: NavigationSplitViewColumn = .content
    @State private var collectionName = ""
    @State private var collectionKind = "Folder"
    @State private var addCollection = false
    @State private var newestFirst = true
    @State private var deleteID: UUID?
    @State private var exportURL: URL?
    @State private var error = ""
    var timeline: [Note] { newestFirst ? Array(store.timeline.reversed()) : store.timeline }
    var body: some View {
        NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: $preferred) {
            List {
                Section("measured.one") {
                    ForEach(["All notes", "Pinned", "To-dos", "Meetings", "Reminders"], id: \.self) { filter in
                        Button {
                            store.filter = filter; store.search = ""; preferred = .content
                        } label: {
                            HStack { Text(filter); Spacer(); if store.filter == filter { Image(systemName: "checkmark") } }
                                .frame(maxWidth: .infinity, minHeight: 30).contentShape(Rectangle())
                        }.foregroundStyle(.primary)
                    }
                }
                Section("Collections") {
                    ForEach(store.collections) { collection in
                        Button {
                            store.browseCollection(collection.id); preferred = .content
                        } label: {
                            Label(collection.name, systemImage: collection.icon).frame(maxWidth: .infinity, minHeight: 30, alignment: .leading).contentShape(Rectangle())
                        }
                    }
                    Button("Add collection", systemImage: "folder.badge.plus") { addCollection = true }
                }
                Section {
                    Button("Export SQLite", systemImage: "externaldrive") { export(sqlite: true) }
                    Button("Export JSON", systemImage: "square.and.arrow.up") { export(sqlite: false) }
                    Text(store.status).font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Index")
                .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 240)
                .toolbar { ToolbarItem { Button("Quick capture", systemImage: "square.and.pencil") { create() } } }
                .contextMenu { Button("New note") { create() }; Button("New collection") { addCollection = true } }
        } content: {
            List(selection: Binding(get: { store.selected }, set: { store.selected = $0; preferred = .detail })) {
                ForEach(timeline) { note in
                    NavigationLink(value: note.id) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: note.originID == nil ? "circle.fill" : "arrow.triangle.branch")
                                .font(.caption).frame(width: 18).padding(.top, 4)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(note.timelineDate, format: .dateTime.month(.abbreviated).day()); Spacer(); if note.pinned { Image(systemName: "pin.fill") } }.font(.caption2).foregroundStyle(.secondary)
                                Text(note.displayTitle).font(.headline).lineLimit(2)
                                Text(note.excerpt).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                if let origin = store.notes.first(where: { $0.id == note.originID }) {
                                    Text("↳ " + origin.displayTitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                if note.openTasks > 0 { Text("\(note.openTasks) open actions").font(.caption2) }
                            }
                        }.padding(.vertical, 5)
                    }.contextMenu {
                        Button("Create related note") { store.createRelated(to: note.id); preferred = .detail }
                        Button("Create related meeting") { store.createRelated(to: note.id, kind: "Meeting"); preferred = .detail }
                        Button(note.pinned ? "Unpin" : "Pin") { store.update(note.id) { $0.pinned.toggle() } }
                        Button("Delete", role: .destructive) { deleteID = note.id }
                    }
                }
            }.navigationTitle(store.filterTitle)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                .searchable(text: $store.search)
                .toolbar {
                    ToolbarItem { Button("Reverse timeline", systemImage: newestFirst ? "arrow.down" : "arrow.up") { newestFirst.toggle() } }
                    ToolbarItem { Menu {
                        Button("Note") { create() }; Button("Meeting") { create("Meeting") }; Button("Checklist") { create("To-do") }
                    } label: { Label("New note", systemImage: "square.and.pencil") } }
                }
                .overlay { if timeline.isEmpty { ContentUnavailableView("No notes", systemImage: "doc.text", description: Text("Create a note or change your search.")) } }
        } detail: {
            if let id = store.selected, store.selectedNote != nil {
                MobileNoteEditor(store: store, id: id).id(id)
            } else {
                ContentUnavailableView { Label("Your notes", systemImage: "square.and.pencil") } description: { Text("Choose a note or capture a thought.") } actions: { Button("New note") { create() } }
            }
        }.navigationSplitViewStyle(.balanced)
            .sheet(isPresented: $addCollection) {
                NavigationStack { Form {
                    TextField("Name", text: $collectionName)
                    Picker("Kind", selection: $collectionKind) { ForEach(["Folder", "Product", "Flow"], id: \.self) { Text($0) } }
                }.navigationTitle("New collection").toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { addCollection = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Create") { if store.createCollection(name: collectionName, kind: collectionKind) != nil { collectionName = ""; addCollection = false } }.disabled(collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                } }
            }
            .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { exportURL = nil } })) { if let exportURL { MobileShare(items: [exportURL]) } }
            .alert("Delete note?", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
                Button("Delete", role: .destructive) { if let deleteID { store.delete(deleteID) }; deleteID = nil }
                Button("Cancel", role: .cancel) { deleteID = nil }
            } message: { Text("Related notes will be kept.") }
            .alert("Export failed", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) { Button("OK") { error = "" } } message: { Text(error) }
    }
    func create(_ kind: String = "Note") { store.create(kind: kind); preferred = .detail }
    func export(sqlite: Bool) {
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(sqlite ? "Measured Notes.sqlite" : "Measured Notes.json")
            let archive = NotesArchive(notes: store.notes, collections: store.collections)
            if sqlite { try NotesExport.sqlite(archive, to: url) } else { try NotesExport.json(archive, to: url) }
            exportURL = url
        } catch { self.error = error.localizedDescription }
    }
}

struct MobileShare: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
