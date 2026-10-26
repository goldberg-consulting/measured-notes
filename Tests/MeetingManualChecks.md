# Mac meeting and editor checks

Automated checks cover isolated editor undo/redo, external replacement, transcript migration, speaker alignment, edit preservation, and SQLite export.

The speaker helper was also run against a 34-second synthetic recording with two voices alternating four times. It identified two speakers and reused the appropriate label for each return. This checks model loading and inference; it does not measure real-meeting accuracy.

Before a public release:

- Type in one note, switch notes, press Undo/Redo, switch back, and close/reopen quick capture. Repeat with Preview toggled and a synced text replacement.
- Record a real meeting with headphones and microphone enabled. Confirm both sides are audible and labels follow the voices.
- Label an existing recording. Confirm manual names and transcript edits survive.
- Cancel labeling during the first download and during inference; verify the recording and transcript remain available and retry succeeds.
- Check overlapping speech, short interjections, and changes inside one transcript passage. Mixed passages should be reviewed rather than treated as a named speaker.
