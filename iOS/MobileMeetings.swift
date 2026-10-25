import SwiftUI
import AVFoundation
import AVKit

@MainActor final class MobileMeetingRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var noteID: UUID?
    @Published var phase = ""
    @Published var started: Date?
    @Published var error = ""
    private var recorder: AVAudioRecorder?
    private var store: NoteStore?
    private var recordingID: UUID?
    private var transcription: Task<Void, Never>?
    private var interruption: NSObjectProtocol?
    var busy: Bool { noteID != nil }
    var isRecording: Bool { phase == "Recording" }

    override init() {
        super.init()
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in self?.stop() }
        }
    }
    deinit { if let interruption { NotificationCenter.default.removeObserver(interruption) } }
    static func url(_ recording: MeetingRecording, store: NoteStore) -> URL? {
        guard recording.fileName == (recording.fileName as NSString).lastPathComponent,
              UUID(uuidString: (recording.fileName as NSString).deletingPathExtension) != nil,
              ["mp4", "m4a"].contains((recording.fileName as NSString).pathExtension) else { return nil }
        return store.storageURL.deletingLastPathComponent().appendingPathComponent("Recordings").appendingPathComponent(recording.fileName)
    }
    func start(store: NoteStore, noteID: UUID, locale: String) async {
        guard !busy, store.storageReadable, store.notes.contains(where: { $0.id == noteID }) else { return }
        self.store = store; self.noteID = noteID; store.recordingNoteID = noteID; error = ""; phase = "Preparing"
        guard await AVAudioApplication.requestRecordPermission() else { fail("Allow microphone access in Settings to record a meeting."); return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            var recording = MeetingRecording(fileName: "", locale: locale, microphone: true)
            recording.fileName = recording.id.uuidString + ".m4a"
            let url = Self.url(recording, store: store)!
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let capture = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            capture.delegate = self
            recordingID = recording.id
            store.update(noteID) { $0.kind = "Meeting"; $0.recordings = ($0.recordings ?? []) + [recording] }
            recorder = capture
            guard capture.record() else { throw MeetingMedia.error("The microphone could not start. Try again after ending other audio sessions.") }
            started = Date(); phase = "Recording"
        } catch { fail(error.localizedDescription) }
    }
    func stop() {
        guard isRecording, let recorder else { return }
        phase = "Saving audio"; recorder.stop()
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard self.recorder === recorder else { return }
            self.recorder = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            update { $0.status = flag ? "Recorded" : "Recording interrupted · audio kept" }
            if flag { transcribe() } else { finish() }
        }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            guard self.recorder === recorder else { return }
            fail(error?.localizedDescription ?? "Recording interrupted. Any saved audio is kept.")
        }
    }
    func retry(_ recording: MeetingRecording, store: NoteStore, noteID: UUID) {
        guard !busy else { return }
        self.store = store; self.noteID = noteID; recordingID = recording.id; store.recordingNoteID = noteID; error = ""
        transcribe()
    }
    private func transcribe() {
        guard let store, let noteID, let recording = store.notes.first(where: { $0.id == noteID })?.recordings?.first(where: { $0.id == recordingID }), let url = Self.url(recording, store: store) else { fail("Recording unavailable."); return }
        phase = "Transcribing"; update { $0.status = "Transcribing" }
        transcription = Task {
            do {
                let segments = try await MeetingTranscription.transcribe(url: url, locale: Locale(identifier: recording.locale))
                guard !Task.isCancelled else { return }
                update { $0.transcript = segments; $0.status = segments.isEmpty ? "No speech detected" : "Transcribed" }
                finish()
            } catch {
                guard !Task.isCancelled else { return }
                fail("Audio saved. Transcription failed: " + error.localizedDescription)
            }
        }
    }
    func cancelTranscription() {
        guard phase == "Transcribing" else { return }
        transcription?.cancel(); update { $0.status = "Recorded · transcription cancelled" }; finish()
    }
    private func update(_ change: (inout MeetingRecording) -> Void) {
        guard let store, let noteID, let recordingID else { return }
        store.update(noteID) { note in
            if let index = note.recordings?.firstIndex(where: { $0.id == recordingID }) { change(&note.recordings![index]) }
        }
    }
    private func fail(_ message: String) {
        error = message; update { $0.status = message }
        let capture = recorder; recorder = nil; capture?.stop()
        finish()
    }
    private func finish() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        store?.recordingNoteID = nil; noteID = nil; recordingID = nil; phase = ""; started = nil; transcription = nil
    }
}

struct MobileMeetings: View {
    @ObservedObject var store: NoteStore
    @EnvironmentObject var recorder: MobileMeetingRecorder
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var locale = Locale.current.identifier
    @State private var languages: [Locale] = []
    @State private var consent = false
    @State private var playback: URL?
    var note: Note { store.notes.first { $0.id == id } ?? Note() }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Record the room through your microphone. Other apps’ calls and screen video are not captured. Let participants know before recording.").font(.callout)
                    if recorder.busy {
                        Text(recorder.phase)
                        if let started = recorder.started { Text(started, style: .timer).monospacedDigit() }
                        if recorder.isRecording { Button("Stop recording", role: .destructive) { recorder.stop() } }
                        if recorder.phase == "Transcribing" { Button("Cancel transcription · keep audio") { recorder.cancelTranscription() } }
                        if recorder.noteID != id { Text("The active recording belongs to another note.").font(.caption) }
                    } else {
                        Picker("Language", selection: $locale) {
                            Text(Locale.current.localizedString(forIdentifier: locale) ?? locale).tag(locale)
                            ForEach(languages.filter { $0.identifier != locale }, id: \.identifier) { language in Text(Locale.current.localizedString(forIdentifier: language.identifier) ?? language.identifier).tag(language.identifier) }
                        }
                        Button("Start recording", systemImage: "mic.fill") { consent = true }
                    }
                    if !recorder.error.isEmpty { Text(recorder.error).foregroundStyle(.red) }
                }
                ForEach(note.recordings ?? []) { recording in
                    Section(recording.started.formatted(date: .abbreviated, time: .shortened)) {
                        Text(recorder.noteID != id && ["Recording", "Transcribing"].contains(recording.status) ? "Interrupted · saved audio can be retried" : recording.status).font(.caption).foregroundStyle(.secondary)
                        if let url = MobileMeetingRecorder.url(recording, store: store), FileManager.default.fileExists(atPath: url.path), !(recorder.noteID == id && recorder.isRecording) {
                            Button("Play recording", systemImage: "play.circle") { playback = url }
                            ShareLink(item: url) { Label("Share recording", systemImage: "square.and.arrow.up") }
                            Button("Transcribe again", systemImage: "text.bubble") { recorder.retry(recording, store: store, noteID: id) }.disabled(recorder.busy)
                        }
                        ForEach(recording.transcript) { segment in
                            VStack(alignment: .leading) {
                                Text(segment.timestamp).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Text(segment.text).textSelection(.enabled)
                            }
                        }
                    }
                }
            }.navigationTitle("Meeting recordings").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { languages = await MeetingTranscription.supportedLanguages() }
            .confirmationDialog("Start meeting recording?", isPresented: $consent, titleVisibility: .visible) {
                Button("Start recording") { Task { await recorder.start(store: store, noteID: id, locale: locale) } }
            } message: { Text("Audio is saved to this note and transcribed on this device after you stop. Speech model downloads may be required.") }
            .sheet(isPresented: Binding(get: { playback != nil }, set: { if !$0 { playback = nil } })) {
                if let playback { MeetingPlayback(url: playback) }
            }
    }
}
}
private struct MeetingPlayback: View {
    @State private var player: AVPlayer
    init(url: URL) { _player = State(initialValue: AVPlayer(url: url)) }
    var body: some View { VideoPlayer(player: player).onAppear { player.play() }.onDisappear { player.pause() } }
}
