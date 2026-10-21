import SwiftUI

struct NoteBranchList: View {
    @ObservedObject var store: NoteStore
    var organize: (UUID) -> Void
    var delete: (UUID) -> Void
    @AppStorage("timelineNewestFirst") private var newestFirst = true
    private let rowHeight: CGFloat = 112
    private var notes: [Note] { newestFirst ? Array(store.timeline.reversed()) : store.timeline }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("TIMELINE", systemImage: "arrow.triangle.branch").font(.system(size: 9, weight: .semibold))
                Spacer()
                Button { newestFirst.toggle() } label: {
                    Label(newestFirst ? "Newest first" : "Oldest first", systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 10)).padding(.vertical, 6).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.bottom, 6)
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        BranchTrace(notes: notes, rowHeight: rowHeight).frame(width: 52, height: CGFloat(notes.count) * rowHeight).allowsHitTesting(false)
                        LazyVStack(spacing: 0) {
                            ForEach(notes) { note in
                                Button { store.selected = note.id } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack {
                                            Text(note.timelineDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            Spacer()
                                            if note.pinned { Image(systemName: "pin.fill") }
                                        }.font(.system(size: 9)).foregroundStyle(muted)
                                        Text(note.displayTitle).font(.system(size: 14, weight: .medium)).lineLimit(1)
                                        Text(note.excerpt.isEmpty ? note.kind : note.excerpt).font(.system(size: 11)).foregroundStyle(muted).lineLimit(1)
                                        if let origin = store.notes.first(where: { $0.id == note.originID }) {
                                            Text("↳ " + origin.displayTitle).font(.system(size: 10)).foregroundStyle(muted).lineLimit(1)
                                        } else {
                                            Text(note.kind).font(.system(size: 10)).foregroundStyle(muted)
                                        }
                                    }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: rowHeight - 4)
                                        .background(store.selected == note.id ? Color.black.opacity(0.08) : .clear)
                                        .overlay(Rectangle().stroke(store.selected == note.id ? Color.black : .clear))
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).padding(.leading, 52).padding(.trailing, 8).frame(height: rowHeight).id(note.id)
                                    .accessibilityLabel(note.displayTitle + (note.originID == nil ? "" : ", related note"))
                                    .contextMenu {
                                        Button("Create related note") { store.createRelated(to: note.id) }
                                        Button("Create related meeting") { store.createRelated(to: note.id, kind: "Meeting") }
                                        Divider()
                                        Button("Assign collections…") { organize(note.id) }
                                        Button(note.pinned ? "Unpin" : "Pin") { store.update(note.id) { $0.pinned.toggle() } }
                                        Button("Delete note", role: .destructive) { delete(note.id) }
                                    }
                                    .background(GeometryReader { geometry in Color.clear.preference(key: NoteListRegions.self, value: ["row:" + note.id.uuidString: geometry.frame(in: .named("note-list"))]) })
                            }
                        }
                    }
                    if notes.isEmpty { Text("No notes here yet.").foregroundStyle(muted).padding(25) }
                }.background(GeometryReader { geometry in Color.clear.preference(key: NoteListRegions.self, value: ["viewport": geometry.frame(in: .named("note-list"))]) })
                    .onChange(of: store.selected) { _, id in if let id { proxy.scrollTo(id, anchor: .center) } }
                    .onAppear { if let id = store.selected { proxy.scrollTo(id, anchor: .center) } }
            }
        }
    }
}

// Each connection gets a lane for its visible interval. Unrelated notes have no connecting line.
struct BranchTrace: View {
    var notes: [Note]
    var rowHeight: CGFloat
    var body: some View {
        Canvas { context, size in
            let positions = Dictionary(uniqueKeysWithValues: notes.enumerated().map { ($0.element.id, $0.offset) })
            let edges = notes.enumerated().compactMap { index, note -> (Int, Int)? in
                guard let origin = note.originID, let parent = positions[origin] else { return nil }
                return (min(index, parent), max(index, parent))
            }.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
            var ends: [Int] = []
            var routed: [(Int, Int, Int)] = []
            for (start, end) in edges {
                let lane = ends.firstIndex(where: { $0 < start }) ?? ends.count
                if lane == ends.count { ends.append(end) } else { ends[lane] = end }
                routed.append((start, end, lane))
            }
            let nodeX: CGFloat = 12
            for (start, end, lane) in routed {
                let x = nodeX + 10 + CGFloat(lane + 1) * 24 / CGFloat(max(1, ends.count))
                let y1 = CGFloat(start) * rowHeight + 22
                let y2 = CGFloat(end) * rowHeight + 22
                var path = Path()
                path.move(to: CGPoint(x: nodeX, y: y1))
                path.addQuadCurve(to: CGPoint(x: x, y: y1 + 12), control: CGPoint(x: x, y: y1))
                path.addLine(to: CGPoint(x: x, y: y2 - 12))
                path.addQuadCurve(to: CGPoint(x: nodeX, y: y2), control: CGPoint(x: x, y: y2))
                context.stroke(path, with: .color(.black.opacity(0.55)), lineWidth: 1)
            }
            for (index, note) in notes.enumerated() {
                let rect = CGRect(x: nodeX - 3, y: CGFloat(index) * rowHeight + 19, width: 6, height: 6)
                let node = note.originID == nil ? Path(rect) : Path(ellipseIn: rect)
                context.fill(node, with: .color(.black))
            }
        }.accessibilityHidden(true)
    }
}

struct NoteRelations: View {
    @ObservedObject var store: NoteStore
    var note: Note
    private var children: [Note] { store.notes.filter { $0.originID == note.id }.sorted { $0.timelineDate < $1.timelineDate } }
    var body: some View {
        if note.originID != nil || !children.isEmpty {
            HStack(spacing: 12) {
                if let origin = store.notes.first(where: { $0.id == note.originID }) {
                    Button { store.openNote(origin.id) } label: { Label("From: " + origin.displayTitle, systemImage: "arrow.turn.up.left").lineLimit(1) }.help("Open source note")
                }
                if !children.isEmpty {
                    Menu {
                        ForEach(children) { child in Button(child.displayTitle) { store.openNote(child.id) } }
                    } label: { Label("Related (\(children.count))", systemImage: "arrow.triangle.branch") }.menuStyle(.borderlessButton).fixedSize()
                }
            }.font(.system(size: 11)).buttonStyle(.plain).padding(.bottom, 10)
        }
    }
}
