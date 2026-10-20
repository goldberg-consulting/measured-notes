# Measured Notes

A small macOS notes app from measured.one. Press **⌘⇧T** from any app to capture a note.

- Markdown editing and preview.
- Tables with editable rows, columns, and colors.
- Checklists and subitems beside each note.
- Folders, products, and flows. A note can belong to more than one.
- Per-note summaries and tags using Apple’s on-device models.
- Reminders and email or Messages drafts.

## Install

Requires an Apple silicon Mac running macOS 26 or later.

```sh
brew install --cask eli-s-goldberg/tap/measured-notes
```

You can also download the app from [Releases](https://github.com/eli-s-goldberg/measured-notes/releases).

The initial release is ad-hoc signed, without Developer ID signing or notarization. macOS may block it from opening. Only open it if you trust this source; see [Apple’s instructions](https://support.apple.com/en-us/102445). Building from source is another option.

## Use

Press **⌘⇧T** to open quick capture. Use the menu bar icon to browse notes. Closing a window keeps the app running; quit from its menu to release the shortcut.

Right-click the editor to insert a table. Right-click the sidebar to create notes or collections. Edit checklists in the right panel; Markdown checkboxes in the note body remain part of the text.

Summaries and tags require Apple Intelligence to be enabled and its model to be available. Notes work without it. Reminders need notification permission. Sharing opens a draft for you to review and send. People attached to notes are labels, not shared access.

## Storage

Notes are saved locally in:

```text
~/Library/Application Support/one.measured.notes/notes.json
```

Back up that folder to keep a copy. There is no account, server, or cloud sync. The app does not upload notes to a model service.

## Build

Requires Xcode 26 or later, its command-line tools, and an Apple silicon Mac.

```sh
./test.sh
./build.sh
open "dist/Measured Notes.app"
```

`./release.sh` builds a versioned ZIP and checksum in `dist/`. The version is stored in `VERSION`. Release builds are ad-hoc signed until Developer ID signing and notarization are configured.
