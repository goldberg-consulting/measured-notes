import SwiftUI
import AppKit

struct ConnectMenu: View {
    var sourceWindow: NSWindow?
    var select: (Int) -> Void
    var dismiss: () -> Void
    @State private var selected = 0
    private let choices = [
        ("Draft an email", "envelope", "Open your mail composer"),
        ("Draft a text", "message", "Open Messages to choose a recipient"),
        ("Add a person", "person.badge.plus", "Keep someone attached to this note")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONNECT THIS THOUGHT").font(.system(size: 9, weight: .semibold)).tracking(1.4).padding(.bottom, 8)
            ForEach(choices.indices, id: \.self) { index in
                let choice = choices[index]
                Button { select(index) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: choice.1).font(.system(size: 17)).frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(choice.0).font(.system(size: 12, weight: .medium))
                            Text(choice.2).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected == index ? Color.black.opacity(0.09) : .clear)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .onHover { if $0 { selected = index } }
                    .accessibilityAddTraits(selected == index ? .isSelected : [])
            }
            Text("↑ ↓ choose · Return select · Esc close").font(.system(size: 9)).foregroundStyle(.secondary).padding(.top, 5)
        }.padding(14).frame(width: 290).background(Color(white: 0.97))
            .background(ConnectKeyboardHandler(sourceWindow: sourceWindow) { command in
                switch command {
                case .next: selected = (selected + 1) % choices.count
                case .previous: selected = (selected + choices.count - 1) % choices.count
                case .activate: select(selected)
                case .dismiss: dismiss()
                }
            })
    }
}

enum ConnectKeyCommand {
    case next, previous, activate, dismiss
    static func command(for keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Self? {
        guard modifiers.intersection([.command, .control, .option]).isEmpty else { return nil }
        switch keyCode {
        case 125: return .next
        case 126: return .previous
        case 36, 76: return .activate
        case 53: return .dismiss
        case 48: return modifiers.contains(.shift) ? .previous : .next
        default: return nil
        }
    }
}

// The Markdown NSTextView normally owns keyboard input. Give the popover a
// responder and intercept its navigation keys before window-level shortcuts
// (notably quick capture's Escape) can handle them.
final class ConnectKeyboardView: NSView {
    var handle: ((ConnectKeyCommand) -> Void)?
    weak var sourceWindow: NSWindow?
    private var monitor: Any?
    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard let window else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, (event.window === window || event.window === self.sourceWindow),
                  let command = ConnectKeyCommand.command(for: event.keyCode, modifiers: event.modifierFlags) else { return event }
            self.handle?(command)
            return nil
        }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window else { return }
            window.makeFirstResponder(self)
        }
    }
    func stopMonitoring() { if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil } }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
}

struct ConnectKeyboardHandler: NSViewRepresentable {
    var sourceWindow: NSWindow?
    var handle: (ConnectKeyCommand) -> Void
    func makeNSView(context: Context) -> ConnectKeyboardView {
        let view = ConnectKeyboardView(); view.handle = handle; view.sourceWindow = sourceWindow; return view
    }
    func updateNSView(_ view: ConnectKeyboardView, context: Context) { view.handle = handle; view.sourceWindow = sourceWindow }
    static func dismantleNSView(_ view: ConnectKeyboardView, coordinator: ()) { view.stopMonitoring() }
}
