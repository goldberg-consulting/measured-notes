import AppKit
@main struct ConnectMenuChecks {
    static func main() {
        precondition(ConnectKeyCommand.command(for: 125, modifiers: []) == .next)
        precondition(ConnectKeyCommand.command(for: 126, modifiers: []) == .previous)
        precondition(ConnectKeyCommand.command(for: 36, modifiers: []) == .activate)
        precondition(ConnectKeyCommand.command(for: 76, modifiers: []) == .activate)
        precondition(ConnectKeyCommand.command(for: 53, modifiers: []) == .dismiss)
        precondition(ConnectKeyCommand.command(for: 48, modifiers: []) == .next)
        precondition(ConnectKeyCommand.command(for: 48, modifiers: .shift) == .previous)
        // Keep editor and quick-capture shortcuts separate from menu navigation.
        precondition(ConnectKeyCommand.command(for: 36, modifiers: .command) == nil)
        precondition(ConnectKeyCommand.command(for: 125, modifiers: .option) == nil)
        precondition(ConnectKeyCommand.command(for: 0, modifiers: []) == nil)
        print("PASS: menu navigation, Return/keypad Enter, Escape, Tab, modified shortcut isolation")
    }
}
