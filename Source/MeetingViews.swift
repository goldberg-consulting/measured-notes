import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MeetingControls: View {
    @ObservedObject var store: NoteStore
    let noteID: UUID
    @ObservedObject private var recorder = MeetingRecorder.shared
    @State private var setup = false
    @State private var microphone = true
    @State private var locale = Locale.current.identifier
    @State private var languages: [Locale] = []
    @State private var transcriptID: UUID?
    @State private var showTranscript = false
    var recordings: [MeetingRecording] { store.notes.first { $0.id == noteID }?.recordings ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if recorder.busy {
                    if let start = recorder.started { TimelineView(.periodic(from: .now, by: 1)) { _ in Text(start, style: .timer).monospacedDigit() } }
                    Text(recorder.phase).font(.caption)
                    if recorder.noteID != noteID { Text("· another note").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if recorder.canStop { Button("Stop recording") { recorder.stop() } }
                    if recorder.phase == "Transcribing on this Mac" { Button("Cancel transcription") { recorder.cancelTranscription() } }
                } else {
                    Button { setup = true } label: { Label("Start meeting…", systemImage: "record.circle") }
                    Spacer()
                }
            }
            if !recordings.isEmpty {
                DisclosureGroup("Recordings (\(recordings.count))") {
                    ForEach(recordings) { recording in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(recording.started, format: .dateTime.month().day().hour().minute()).font(.caption)
                            Text(displayStatus(recording)).font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Button("Play") { if let url = recordingURL(recording) { NSWorkspace.shared.open(url) } }
                                Button("Save recording…") { saveVideo(recording) }
                                Button("Transcript") { transcriptID = recording.id; showTranscript = true }.disabled(recording.transcript.isEmpty)
                                Button("Transcribe") { recorder.retry(recording, store: store, noteID: noteID) }.disabled(recorder.busy || !recording.transcript.isEmpty)
                            }.controlSize(.small)
                        }.padding(.vertical, 6)
                    }
                }.font(.caption)
            }
            if let error = recorder.errorMessage {
                HStack { Text(error).font(.caption).foregroundStyle(.secondary); Button("Dismiss") { recorder.errorMessage = nil } }
            }
        }.padding(10).background(Color.black.opacity(0.035))
        .sheet(isPresented: $setup) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Record a meeting").font(.title2)
                Text("Choose a window in Apple’s picker. The recording saves video and that application’s audio; other windows in the same app may contribute audio.").font(.callout)
                Toggle("Include my microphone", isOn: $microphone)
                Text("Use headphones to avoid capturing meeting audio twice through your microphone.").font(.caption).foregroundStyle(.secondary)
                Picker("Spoken language", selection: $locale) {
                    ForEach(languages, id: \.identifier) { language in
                        Text(Locale.current.localizedString(forIdentifier: language.identifier) ?? language.identifier).tag(language.identifier)
                    }
                }.disabled(languages.isEmpty)
                Text("After you stop, Apple Speech transcribes on this Mac. A language model download may be needed. Speaker names are editable; automatic diarization is not included.").font(.caption).foregroundStyle(.secondary)
                HStack { Button("Cancel") { setup = false }; Spacer(); Button("Choose window & record") { setup = false; recorder.begin(store: store, noteID: noteID, microphone: microphone, locale: locale) }.disabled(recorder.busy || languages.isEmpty) }
            }.padding(24).frame(width: 470)
                .task {
                    languages = await MeetingTranscription.supportedLanguages()
                    if !languages.contains(where: { $0.identifier == locale }) { locale = languages.first(where: { $0.identifier == "en-US" })?.identifier ?? languages.first?.identifier ?? "" }
                }
        }
        .sheet(isPresented: $showTranscript) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Meeting transcript").font(.title2); Spacer(); Button("Copy") { if let record = recordings.first(where: { $0.id == transcriptID }) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(record.transcriptMarkdown, forType: .string) } }; Button("Done") { showTranscript = false } }
                Text("Edit words or add speaker names. Speaker labels are manual.").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    if let record = recordings.first(where: { $0.id == transcriptID }) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(record.transcript) { segment in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack { Text(segment.timestamp).monospacedDigit().font(.caption); TextField("Speaker (optional)", text: segmentBinding(record.id, segment.id, \.speaker)).textFieldStyle(.roundedBorder).frame(width: 220) }
                                    TextField("Transcript", text: segmentBinding(record.id, segment.id, \.text), axis: .vertical).textFieldStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }.padding(24).frame(width: 660, height: 520)
        }
    }
    func segmentBinding(_ recordingID: UUID, _ segmentID: UUID, _ key: WritableKeyPath<TranscriptSegment, String>) -> Binding<String> {
        Binding(get: { recordings.first { $0.id == recordingID }?.transcript.first { $0.id == segmentID }?[keyPath: key] ?? "" }, set: { text in
            store.update(noteID) { note in
                guard let r = note.recordings?.firstIndex(where: { $0.id == recordingID }), let s = note.recordings?[r].transcript.firstIndex(where: { $0.id == segmentID }) else { return }
                note.recordings![r].transcript[s][keyPath: key] = text
            }
        })
    }
    func recordingURL(_ recording: MeetingRecording) -> URL? { MeetingRecorder.fileURL(recording, storage: store.storageURL) }
    func displayStatus(_ recording: MeetingRecording) -> String {
        if recorder.noteID != noteID && ["Recording", "Transcribing"].contains(recording.status) { return "Interrupted · saved media can be retried" }
        return recording.status
    }
    func saveVideo(_ recording: MeetingRecording) {
        guard let source = recordingURL(recording) else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [source.pathExtension == "m4a" ? .mpeg4Audio : .mpeg4Movie]; panel.nameFieldStringValue = "Meeting-\(recording.id.uuidString.prefix(8)).\(source.pathExtension)"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do { try MeetingMedia.copy(source: source, to: destination) }
        catch { NSAlert(error: error).runModal() }
    }
}
