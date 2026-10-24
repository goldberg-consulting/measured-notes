# Measured Notes

A small macOS notes app from measured.one. Press **⌘⇧T** from any app to capture a note.

- Markdown editing and preview.
- A chronological branch trace in All notes. Create related notes or meetings from the branch button or a note’s right-click menu.
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

Related notes stay separate and inherit their source’s collections. Use **From** to return to the source and **Related** to browse its follow-ups. All notes can run oldest or newest first; editing and pinning do not change timeline order. Older notes use their last saved edit date as their initial timeline date. Deleting a source keeps its related notes and removes their link to it.

## Storage

Notes are saved locally in:

```text
~/Library/Application Support/one.measured.notes/notes.json
```

Use **File → Show notes storage in Finder** to find it.

Use **File → Export all notes as SQLite…** or **Export all notes as JSON…** to save a portable snapshot. Exports include all notes, checklists and subitems, collection assignments, tags, people, summaries, and reminders. Exporting does not change the app’s storage. SQLite exports are snapshots; editing them does not update the app, and there is no import command yet.

The SQLite file has `notes`, `actions`, `collections`, `note_collections`, `tags`, `people`, `images`, `recordings`, `transcript_segments`, and `documents` tables. Dates use UTC ISO 8601 strings; `position` preserves archive order. `notes.created_at` records timeline order and `notes.origin_id` links related notes to their source. `PRAGMA user_version` is the schema version (currently 5). The `archive` table also holds a complete JSON copy for lossless conversion. Table color metadata remains in the Markdown body.

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

## Images

Drop image files into the Markdown editor, paste an image from the clipboard, or use the image button beside Table. Images appear inline in Preview and in the Attachments section beneath Actions. Adjust the width slider to resize proportionally, and type an optional caption below the image.

Images are copied into the note archive, so moving or deleting the original file does not break them. JSON exports include image bytes; SQLite exports include PNG blobs in the `images` table, along with captions and display widths. Markdown image references are local to this app; copying Markdown alone does not include image files.

Imports accept images up to 20 MB and store a PNG copy up to 2400 pixels on its longest side. Animated images use their first frame. Keep originals separately if you need full-resolution or animated source files.

## Meetings

Choose **File → New meeting note**, then **Start meeting…**. Select a spoken language, choose whether to include your microphone, and pick a window in Apple’s content-sharing picker. Recording begins after selection. Use **Stop recording** in the note or **Stop meeting recording** in the menu bar menu.

The app saves the selected window as an MP4 with application audio and the optional microphone. Window selection limits the video; audio comes from the selected application and can include its other windows. Headphones help avoid microphone echo. Video is limited to 1920 × 1080 at 30 fps.

After recording stops, Apple Speech transcribes on-device. A language model may need to download first. Transcription does not require Apple Intelligence to be enabled, but the note summary does. If transcription fails or is cancelled, the video stays available for retry.

Expand **Recordings** to play or save a video, open its transcript, or retry transcription. Transcript text and speaker labels can be edited. Automatic speaker diarization is not included. The running summary uses the note and transcript, subject to its existing 7,000-character limit.

Videos are stored under `~/Library/Application Support/one.measured.notes/Recordings/`. Back up the whole storage folder to retain them. JSON and SQLite exports contain transcripts and recording metadata, but not video bytes; use **Save video…** for a portable MP4. Deleting a note does not erase its recording files.

macOS may request microphone and capture permission. The app shows a recording timer and macOS displays its capture indicator. Quitting is blocked while capture or transcription is active; stop recording or cancel transcription first.

## Documents

Drop PDFs, Office documents, spreadsheets, presentations, or text files into the editor or Preview. You can also use the paperclip button. Each file is stored as an attached copy and appears as a document card with Open, Save, and Remove controls. Moving or deleting the original file does not affect the attachment. Opening creates a temporary copy; edits in another app do not update the attachment.

Documents are attached as files; their text is not inserted into the note or automatically summarized. SQLite exports include their original bytes in the `documents` table, and JSON exports include them as base64. Markdown references alone do not include the attached files. Files must be under 25 MB each and each drop under 50 MB. Folders and document packages are not supported.

Right-click the note-list header or empty space to create a note, example, checklist, or meeting note. Note rows retain their own menus. New notes inherit the selected collection.

## Compact attachment panel

Attachments share the right column with Actions; they no longer shorten the Markdown editor. The attachment list has its own bounded scroll area and can be collapsed. Use a document’s menu to open, save, or remove it. Click an image row to edit its size or caption.

Images and document bytes are embedded in `notes.json`, not linked to the original files. The Markdown references identify attachment placement within a note. SQLite exports store the bytes in the `images` and `documents` tables.

The `@` action menu supports Up/Down (or Tab/Shift-Tab) to select, Return to activate, and Escape to dismiss. The selected action is highlighted.

The app icon uses the measured.one “m.” artwork from [measured.one](https://measured.one/favicon.png). The source image is kept in `Resources/AppIcon.png`; the build generates the macOS icon sizes.
