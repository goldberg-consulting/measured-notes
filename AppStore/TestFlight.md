# TestFlight preparation

## Beta description

Measured Notes is a Markdown notebook for notes, meetings, and checklists. Organize notes into folders, products, and flows. Add tables, images, documents, and related notes. Keep actions beside your writing on larger screens, or open them in a separate panel on your phone.

This beta includes private iCloud sync with the Mac companion. Notes and attachments stay available locally. Concurrent edits are preserved as conflict copies. Summaries and tags use Apple's on-device models when available.

## What to test

- Create and edit notes, tables, checklists, and nested actions.
- Add images and documents, then check captions, image sizing, and exports.
- Open the same library on Mac and iPhone using the same Apple Account with iCloud Drive enabled. Verify text, collections, and attachment contents arrive on both devices.
- Edit while offline, reconnect, and check that changes arrive. Edit the same note on both devices while offline and confirm both edits survive.
- Delete a note and verify the deletion reaches the other device. Edit an old offline copy before reconnecting and confirm that work survives as a conflict copy.
- Switch between narrow and wide layouts without losing your selected note or text.
- Report freezes, missing content, unexpected duplicates, or confusing controls. Include the app version, device, and steps. Only attach note contents you intend to share.

The status “changes queued with iCloud Drive” does not confirm delivery to another device. Verify arrival directly on the receiving device.

## Known limitations

- Real-device iCloud transfer and account switching still need validation.
- Mobile meeting recording/transcription, archive import, lock-screen capture, and a share extension are not included.
- Related notes show their source, but the mobile timeline does not yet draw the full Mac branch trace.
- Sync history and older attachment files are retained to support offline devices. Deleting a note does not immediately erase every retained attachment copy.

## Review notes

No separate Measured Notes account or developer-hosted login is required. Notes can be used locally. iCloud sync requires an Apple Account with iCloud Drive enabled. People attached to notes are labels and do not invite or grant access to another person.

Use Index → iCloud sync to disable app synchronization. Summaries require a supported device with Apple's on-device models available. Their absence does not prevent basic note editing.

## Still needed in App Store Connect

- App record created: `6826934510`, bundle `one.measured.notes.mobile`, under the user-confirmed Eli Goldberg team.
- Feedback email and privacy policy URL are saved in App Store Connect. Beta review contact details are still needed for external testing; do not commit private contact information here.
- Upload the signed package, wait for processing, and resolve any validation or export-compliance questions.
- Select internal testers. External testing may require Beta App Review.

Versions 0.1.0 (builds 1 and 2) uploaded successfully on October 25, 2026. Build 2 includes privacy and support links. Build 2 cleared processing and its encryption declaration, and is assigned to the internal group with manual build selection. App Store Connect confirmed the requested tester as Invited on October 25, 2026. Real-device installation and sync acceptance checks remain outstanding.
