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
brew install --cask goldberg-consulting/tap/measured-notes
```

You can also download the app from [Releases](https://github.com/goldberg-consulting/measured-notes/releases).

Releases from 0.1.1 onward are signed with Developer ID and notarized by Apple.

## Use

Press **⌘⇧T** to open quick capture. Use the menu bar icon to browse notes. Closing a window keeps the app running; quit from its menu to release the shortcut.

Right-click the editor to insert a table. Right-click the sidebar to create notes or collections. Edit checklists in the right panel; Markdown checkboxes in the note body remain part of the text.

Summaries and tags require Apple Intelligence to be enabled and its model to be available. Notes work without it. Reminders need notification permission. Sharing opens a draft for you to review and send. People attached to notes are labels, not shared access.

## Storage

Notes are saved locally in:

```text
~/Library/Application Support/one.measured.notes/notes.json
```

Use **File → Show notes storage in Finder** to find it.

Use **File → Export all notes as SQLite…** or **Export all notes as JSON…** to save a portable snapshot. Exports include all notes, checklists and subitems, collection assignments, tags, people, summaries, and reminders. Exporting does not change the app’s storage. SQLite exports are snapshots; editing them does not update the app, and there is no import command yet.

The SQLite file has `notes`, `actions`, `collections`, `note_collections`, `tags`, and `people` tables. Dates use UTC ISO 8601 strings; `position` preserves list order. `PRAGMA user_version` is the schema version (currently 1). The `archive` table also holds a complete JSON copy for lossless conversion. Table color metadata remains in the Markdown body.

Back up the storage folder to keep a copy. There is no account, server, or cloud sync. The app does not upload notes to a model service.

## Build

Requires Xcode 26 or later, its command-line tools, and an Apple silicon Mac.

```sh
./test.sh
./build.sh
open "dist/Measured Notes.app"
```

The version is stored in `VERSION`. Local builds are ad-hoc signed. To create a public release, set a Developer ID Application identity and a saved notarization Keychain profile:

```sh
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="your-notary-profile" ./release.sh
```

The release script runs tests, signs with the hardened runtime, submits to Apple, staples the notarization ticket, and checks Gatekeeper acceptance. It then writes the ZIP and checksum to `dist/`. Credentials stay in Keychain.
