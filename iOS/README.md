# Measured Notes for iOS

Development companion for iPhone and iPad, built with the iOS 27 SDK for adaptive layouts on iPhone Duo. Requires iOS 26 or later.

## Layout

The same navigation hierarchy adapts to available space: Index → note timeline → Markdown editor. The outer display and narrow app windows use stacked navigation. Expanded windows use a native three-column `NavigationSplitView`. Actions and attachments live in a dismissible inspector, which becomes a sheet in compact layouts. Standard toolbars, sheets, and safe areas let iOS position controls for Duo.

The note store sits above the navigation hierarchy so resizing does not recreate it. The editor identity changes only when the selected note changes.

References: [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/), [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/).

## Included

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

This is a development build, not a TestFlight release or complete Mac feature parity. Automatic Mac/iPhone sync and archive import are not implemented. Notes are currently local to each installation. The mobile timeline shows source links, but does not yet draw the Mac's full branch trace. Mac window recording and transcription have not been ported; the mobile Meeting option currently creates a meeting note template. Background/lock-screen capture, share extensions, and interactive fold-transition tests remain outstanding.

## Build

Install Xcode 27 and XcodeGen, then run from the repository root:

```sh
xcodegen generate --spec iOS/project.yml
xcodebuild -project iOS/MeasuredNotesMobile.xcodeproj \
  -scheme MeasuredNotesMobile -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/measured-mobile-build CODE_SIGNING_ALLOWED=NO build
```

Open the generated project in Xcode to run on a signed device. Device provisioning and TestFlight distribution have not been configured. The checked-in project specification is authoritative; the generated Xcode project is ignored.
