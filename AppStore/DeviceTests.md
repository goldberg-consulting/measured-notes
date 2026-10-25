# Device acceptance checks

Use a disposable test library and keep a JSON/SQLite export before testing. Record the app build, OS versions, devices, and result for each check. Filesystem fixture tests do not count as passing these checks.

Current status: all checks below await real devices.

1. **Same account:** On Mac and iPhone signed into the same Apple Account, create a note on each device. Verify both arrive, then edit and delete from each device.
2. **Different accounts:** On a separate test device signed into another Apple Account, confirm that the first account's notes never appear.
3. **Attachments:** Transfer an image, document, and completed Mac recording. Compare exported attachment bytes with the originals, including after restarting both apps.
4. **Offline work:** Disconnect one device, edit notes and collections, then reconnect. Verify those changes reach the other device.
5. **Conflicting edits:** Edit the same note offline on both devices. Reconnect and verify both versions survive with stable conflict copies. Edit and delete a conflict copy, restart, and confirm the choice persists.
6. **Delete versus edit:** Delete a note on one device while editing an offline copy on the other. Reconnect and confirm the edited copy survives separately without restoring the deleted original.
7. **Unavailable iCloud:** Disable iCloud Drive for the test account/device. Verify local editing and export work, with an accurate sync status. Restore it and verify recovery.
8. **Account change:** Switch the test device to another Apple Account. Verify sync pauses and does not upload the old library into the new account. Do not use a personal production library for this check.
9. **Sync setting:** Turn app sync off during a download. Confirm local edits remain usable and no incoming library is applied after the setting changes. Already queued iCloud Drive transfers may finish.
10. **Meetings:** Record on Mac while the other device edits a different note. Confirm incoming changes wait until the meeting finishes and the resulting recording transfers intact.
11. **Navigation:** Edit a note, open actions, resize/rotate/fold, and return. Verify text, selection, and navigation remain usable. Test on actual Duo hardware before claiming fold support.
12. **Capture and export:** Open `measurednotes://capture`, accept the system confirmation, and verify a new editable note appears. Export JSON and SQLite, then inspect their note and attachment contents.

Record failures before inviting additional testers. Do not mark a check passed based only on an archive, signing success, or a simulator layout.
