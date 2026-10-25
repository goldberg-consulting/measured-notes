# App Store preparation

Target: iPhone/iPad companion, with adaptive layouts for iPhone Duo. The Mac app remains a separate Developer ID/Homebrew distribution.

Bundle ID: `one.measured.notes.mobile`

Developer team: `97UY84BV45`

iCloud container: `iCloud.one.measured.notes`

Each user's Apple Account has its own contents within that container. Sharing an app container across Mac and iPhone does not share libraries between people. People labels do not grant access to notes.

## Before TestFlight

- A signed archive and App Store distribution export have been produced locally. Create/select its record in App Store Connect and upload the tested candidate.
- Test on two real devices signed in to the same iCloud account: new notes, offline edits, concurrent edits, deletions, attachments, recordings transferred from Mac, and account sign-out/switching.
- Check that iCloud Drive reports completed transfers; the app currently reports that changes are queued, not delivered to every device.
- Test folding/resizing on Duo. Simulator phone/tablet layouts are not sufficient evidence of fold behavior.
- Provide beta contact and review details in App Store Connect.

## Before public release

- Publish the privacy policy at a stable public URL and link it in the app and App Store metadata. `Privacy.md` is a draft reflecting the current implementation.
- Review privacy answers and required-reason API declarations against the final binary and any dependencies added before release.
- Choose pricing, territories, support URL/contact, age-rating answers, and final product name.
- Capture actual device screenshots of the release build. Do not submit development screenshots as evidence of Duo support.
- Finish or explicitly omit unported functionality from the listing: mobile recording/transcription, archive import, lock-screen/share-extension capture, and full branch-trace drawing.
- Submit through App Store Connect after the release candidate passes device tests.

No build has been submitted for Apple review, and no public App Store listing has been published.
