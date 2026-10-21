import SwiftUI

struct CollectionsSheet: View {
    @ObservedObject var store: NoteStore
    var noteID: UUID?
    var startingKind = "Folder"
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind = "Folder"
    @State private var query = ""
    @State private var renameID: UUID?
    @State private var renameText = ""
    @State private var deleteID: UUID?
    @State private var error = ""
    var note: Note? { store.notes.first { $0.id == noteID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(noteID == nil ? "Collections" : "Organize this note").font(.system(size: 25, design: .serif)); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
            Text(noteID == nil ? "Group your notes by folder, product, or flow." : "Choose as many as you need. One note can belong in several places.").font(.system(size: 12)).foregroundStyle(muted)
            TextField("Find a collection", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(["Folder", "Product", "Flow"], id: \.self) { category in
                        let items = store.collections.filter { $0.kind == category && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                        if !items.isEmpty {
                            Text(category.uppercased() + "S").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(muted)
                            ForEach(items) { collection in
                                HStack {
                                    if let noteID {
                                        Toggle(isOn: Binding(get: { (note?.collectionIDs ?? []).contains(collection.id) }, set: { store.assign(noteID, to: collection.id, included: $0) })) { Label(collection.name, systemImage: collection.icon) }.toggleStyle(.checkbox)
                                    } else { Label(collection.name, systemImage: collection.icon) }
                                    Spacer()
                                    Text("\(store.notes.filter { ($0.collectionIDs ?? []).contains(collection.id) }.count)").font(.caption).foregroundStyle(muted)
                                    Menu {
                                        Button("Rename…") { renameID = collection.id; renameText = collection.name; error = "" }
                                        Button("Delete collection…", role: .destructive) { deleteID = collection.id }
                                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22)
                                }.font(.system(size: 13)).padding(.vertical, 3)
                            }
                        }
                    }
                    if store.collections.isEmpty { Text("Create your first collection below.").foregroundStyle(muted).padding(.vertical, 24) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(minHeight: 160, maxHeight: .infinity)
            Divider()
            Text("NEW COLLECTION").font(.system(size: 9, weight: .semibold)).tracking(1.5)
            HStack {
                Picker("Type", selection: $kind) { ForEach(["Folder", "Product", "Flow"], id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(width: 105)
                TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                Button(noteID == nil ? "Create" : "Create & assign") {
                    if let collection = store.createCollection(name: name, kind: kind) {
                        if let noteID { store.assign(noteID, to: collection, included: true) }
                        name = ""; query = ""
                    }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 540, height: 480).background(ink).foregroundStyle(.black).tint(.black).preferredColorScheme(.light)
            .onAppear { kind = startingKind }
            .sheet(isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Rename collection").font(.title3)
                    TextField("Name", text: $renameText).textFieldStyle(.roundedBorder)
                    if !error.isEmpty { Text(error).font(.caption) }
                    HStack { Button("Cancel") { renameID = nil }; Spacer(); Button("Save") {
                        if let id = renameID, store.renameCollection(id, name: renameText) { renameID = nil } else { error = "Choose a nonempty name that isn’t already used for this type." }
                    }.keyboardShortcut(.defaultAction) }
                }.padding(24).frame(width: 360)
            }
            .alert("Delete this collection?", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
                Button("Cancel", role: .cancel) { deleteID = nil }
                Button("Delete collection", role: .destructive) { if let id = deleteID { store.removeCollection(id) }; deleteID = nil }
            } message: { Text("Its notes will stay in All notes and in their other collections.") }
    }
}

struct CollectionSidebar: View {
    @ObservedObject var store: NoteStore
    var manage: () -> Void
    var createCollection: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("COLLECTIONS").font(.system(size: 9, weight: .semibold)).tracking(1.8); Spacer(); Button(action: manage) { Image(systemName: "plus") }.buttonStyle(.plain).help("Create or manage collections") }.foregroundStyle(muted).contentShape(Rectangle()).contextMenu { NewItemsMenu(store: store, createCollection: createCollection); Divider(); Button("Manage collections…", action: manage) }
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    if store.collections.isEmpty { Button("Add a folder, product, or flow", action: manage).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(muted).padding(.vertical, 8) }
                    ForEach(["Folder", "Product", "Flow"], id: \.self) { kind in
                        let items = store.collections.filter { $0.kind == kind }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                        if !items.isEmpty { Text(kind.uppercased() + "S").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(muted).padding(.top, 8) }
                        ForEach(items) { collection in
                            Button { store.browseCollection(collection.id) } label: {
                                HStack(spacing: 8) { Image(systemName: collection.icon).frame(width: 14); Text(collection.name).lineLimit(1); Spacer(); Text("\(store.notes.filter { ($0.collectionIDs ?? []).contains(collection.id) }.count)").font(.system(size: 10)) }
                                    .font(.system(size: 11)).padding(.vertical, 8).padding(.horizontal, 6).foregroundStyle(.black).background(store.activeCollection?.id == collection.id ? Color.black.opacity(0.09) : .clear).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .background(GeometryReader { proxy in Color.clear.preference(key: SidebarRegions.self, value: [collection.id: proxy.frame(in: .named("collection-sidebar"))]) })
                                .contextMenu {
                                NewItemsMenu(store: store, collectionID: collection.id, createCollection: createCollection)
                                Divider()
                                Button("Manage collections…", action: manage)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(minHeight: 80, maxHeight: .infinity)
        }.padding(.top, 24)
    }
}

struct NewItemsMenu: View {
    @ObservedObject var store: NoteStore
    var collectionID: UUID?
    var createCollection: (String) -> Void
    var body: some View {
        Button(collectionID == nil ? "New note" : "New note here") { create("Note") }
        Button(collectionID == nil ? "New example" : "New example here") { create("Example") }
        Button(collectionID == nil ? "New meeting note" : "New meeting note here") { create("Meeting") }
        Divider()
        Button("New folder…") { createCollection("Folder") }
        Button("New product…") { createCollection("Product") }
        Button("New flow…") { createCollection("Flow") }
    }
    func create(_ kind: String) {
        if let collectionID { store.browseCollection(collectionID) }
        store.create(kind: kind)
    }
}
