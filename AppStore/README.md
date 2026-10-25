# App Store preparation

Target: iPhone/iPad companion, with adaptive layouts for iPhone Duo. The Mac app remains a separate Developer ID/Homebrew distribution.

Bundle ID: `one.measured.notes.mobile`

Developer team: `97UY84BV45` (Eli Goldberg, confirmed for this app)

App Store Connect app ID: `6826934510`

[App record](https://appstoreconnect.apple.com/apps/6826934510/distribution)

iCloud container: `iCloud.one.measured.notes`

Each user's Apple Account has its own contents within that container. Sharing an app container across Mac and iPhone does not share libraries between people. People labels do not grant access to notes.

## Before TestFlight

- The app record and signed distribution export are ready. Verify upload processing and TestFlight availability in App Store Connect.
- Test on two real devices signed in to the same iCloud account: new notes, offline edits, concurrent edits, deletions, attachments, recordings transferred from Mac, and account sign-out/switching.
- Check that iCloud Drive reports completed transfers; the app currently reports that changes are queued, not delivered to every device.
- Test folding/resizing on Duo. Simulator phone/tablet layouts are not sufficient evidence of fold behavior.
- Provide beta contact and review details in App Store Connect.

## Before public release

- Privacy policy is published at an immutable GitHub URL, linked in the app and TestFlight metadata. Confirm the same URL is entered in public App Store metadata before submission.
- Review privacy answers and required-reason API declarations against the final binary and any dependencies added before release.
- Choose pricing, territories, support URL/contact, age-rating answers, and final product name.
- Capture actual device screenshots of the release build. Do not submit development screenshots as evidence of Duo support.
- Finish or explicitly omit unported functionality from the listing: mobile recording/transcription, archive import, lock-screen/share-extension capture, and full branch-trace drawing.
- Submit through App Store Connect after the release candidate passes device tests.

Builds 0.1.0 (1) and (2) uploaded successfully. Build 2 includes in-app privacy and support links. No build has been submitted for public App Review and no public listing has been published.
