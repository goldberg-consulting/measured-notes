# Measured Notes for iOS

Development companion for iPhone and iPad, built with the iOS 27 SDK for adaptive layouts on iPhone Duo. Requires iOS 26 or later.

## Layout

The same navigation hierarchy adapts to available space: Index → note timeline → Markdown editor. The outer display and narrow app windows use stacked navigation. Expanded windows use a native three-column `NavigationSplitView`. Actions and attachments live in a dismissible inspector, which becomes a sheet in compact layouts. Standard toolbars, sheets, and safe areas let iOS position controls for Duo.

The note store sits above the navigation hierarchy so resizing does not recreate it. The editor identity changes only when the selected note changes.

References: [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/), [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/).

## Included

- Automatic iCloud Drive sync with local copies, conflict preservation, and account-change protection. Real-device cross-device verification is still required.
- Shared note storage, source relationships, creation-order timeline, collections, and tags.
- Markdown editing and preview; editable tables with row, column, and cell colors.
- Independent actions and subitems.
- Embedded images and documents, image captions and sizing, and document sharing.
- Email and Messages through the system share sheet; type `@` for sharing or adding a person.
- Reminders and on-device summaries when Apple Intelligence is available.
- JSON and SQLite exports using the same format as the Mac app.
- Existing measured.one app icon.
- `measurednotes://capture` opens a new note.

## Not yet included

This is a TestFlight beta, without complete Mac feature parity. Archive import is not implemented. iCloud signing has been provisioned, and two-replica filesystem tests pass; real iCloud transfer and account switching still need device tests. The mobile timeline shows source links, but does not yet draw the Mac's full branch trace. iPhone supports microphone meeting recording, playback, sharing, and Apple on-device transcription with retries. Recordings and transcripts sync through the shared library. Other apps’ call audio and screen video are not captured. Automatic speaker diarization is not included. Physical-device recording, interruptions, and locked-screen capture still need acceptance tests. Lock-screen quick capture, share extensions, and interactive fold-transition tests remain outstanding.

## Build

Install Xcode 27 and XcodeGen, then run from the repository root:

```sh
xcodegen generate --spec iOS/project.yml
xcodebuild -project iOS/MeasuredNotesMobile.xcodeproj \
  -scheme MeasuredNotesMobile -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/measured-mobile-build CODE_SIGNING_ALLOWED=NO build
```

Open the generated project in Xcode to run on a signed device. Device provisioning with the shared iCloud container is configured. TestFlight upload and real-device sync verification remain outstanding. The checked-in project specification is authoritative; the generated Xcode project is ignored.

## Reproducible App Store export

Run `BUILD_NUMBER=1 bash scripts/build-ios.sh` from the repository root. Use a new build number for each uploaded build. The script generates the Xcode project, archives with automatic signing, exports into `dist/iOS/build-<number>/export/`, and checks the package contents. It does not upload anything. Requires Xcode with the development team signed in and XcodeGen installed.

TestFlight copy and remaining account setup are in `AppStore/TestFlight.md`. Real-device acceptance checks are in `AppStore/DeviceTests.md`.

## Meetings

Open a note’s menu → Record meeting, choose a language, and start recording. Meeting notes also show a direct Meeting recordings button. Stop to save audio and begin transcription. Audio remains saved if transcription fails or is cancelled; Transcribe again retries after a model download or interruption. The Index shows recording controls while you browse other notes.

On compact screens, All notes opens a persistent browser. Selecting a note marks it with a checkmark and keeps the browser open; Done returns to the selected note. Search, collection filters, new notes, and Index and settings remain available inside the browser. The regular-width layout keeps its three columns.
