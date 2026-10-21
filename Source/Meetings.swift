import AppKit
import SwiftUI
import ScreenCaptureKit
import AVFoundation
import Speech

@MainActor final class MeetingRecorder: NSObject, ObservableObject, SCContentSharingPickerObserver, SCStreamDelegate, SCRecordingOutputDelegate {
    static let shared = MeetingRecorder()
    @Published var phase = ""
    @Published var noteID: UUID?
    @Published var started: Date?
    @Published var errorMessage: String?
    var busy: Bool { noteID != nil }
    var canStop: Bool { phase == "Recording" }
    private var store: NoteStore?
    private var stream: SCStream?
    private var output: SCRecordingOutput?
    private var record: MeetingRecording?
    private var microphone = true
    private var locale = "en-US"
    private var finishing = false
    private var transcriptionTask: Task<Void, Never>?

    static func fileURL(_ recording: MeetingRecording, storage: URL) -> URL? {
        // A loaded archive must never be able to reference files outside recordings.
        guard recording.fileName == recording.id.uuidString + ".mp4" else { return nil }
        return storage.deletingLastPathComponent().appendingPathComponent("Recordings").appendingPathComponent(recording.fileName)
    }
    func begin(store: NoteStore, noteID: UUID, microphone: Bool, locale: String) {
        guard !busy, store.storageReadable else { return }
        self.store = store; self.noteID = noteID; self.microphone = microphone; self.locale = locale
        store.recordingNoteID = noteID; errorMessage = nil; phase = "Preparing"; finishing = false
        Task {
            let microphoneAllowed = microphone ? await AVCaptureDevice.requestAccess(for: .audio) : true
            if !microphoneAllowed {
                fail("Microphone permission is off. Enable it in System Settings, or start without a microphone.")
                return
            }
            let picker = SCContentSharingPicker.shared
            var configuration = SCContentSharingPickerConfiguration()
            configuration.allowedPickerModes = [.singleWindow]
            configuration.allowsChangingSelectedContent = false
            picker.defaultConfiguration = configuration
            picker.maximumStreamCount = 1
            picker.add(self)
            picker.isActive = true
            phase = "Choose a window"
            picker.present(using: .window)
        }
    }
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
        if self.stream == nil && phase == "Choose a window" { reset() }

        }
    }
    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in fail(error.localizedDescription)
        }
    }
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
        guard self.stream == nil, phase == "Choose a window" else { return }
        phase = "Starting"
        Task { await start(filter) }

        }
    }
    private func start(_ filter: SCContentFilter) async {
        guard let store, let noteID else { return }
        do {
            var recording = MeetingRecording(fileName: "", locale: locale, microphone: microphone)
            recording.fileName = recording.id.uuidString + ".mp4"
            let url = Self.fileURL(recording, storage: store.storageURL)!
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            record = recording
            store.update(noteID) { $0.kind = "Meeting"; $0.recordings = ($0.recordings ?? []) + [recording] }
            let configuration = SCStreamConfiguration()
            let rect = filter.contentRect
            let scale = min(2.0, 1920.0 / max(1, rect.width), 1080.0 / max(1, rect.height))
            configuration.width = max(2, Int(rect.width * scale) / 2 * 2)
            configuration.height = max(2, Int(rect.height * scale) / 2 * 2)
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.captureMicrophone = microphone
            configuration.sampleRate = 48000; configuration.channelCount = 2
            let recordingConfiguration = SCRecordingOutputConfiguration()
            recordingConfiguration.outputURL = url
            recordingConfiguration.outputFileType = .mp4
            recordingConfiguration.videoCodecType = .h264
            let output = SCRecordingOutput(configuration: recordingConfiguration, delegate: self)
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            self.output = output; self.stream = stream
            try stream.addRecordingOutput(output)
            try await stream.startCapture()
        } catch { fail(error.localizedDescription) }
    }
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
        guard recordingOutput === output else { return }
        phase = "Recording"; started = Date()

        }
    }
    func stop() {
        guard let stream, canStop else { return }
        phase = "Saving recording"
        Task { do { try await stream.stopCapture() } catch { fail(error.localizedDescription) } }
    }
    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        Task { @MainActor in
        guard recordingOutput === output else { return }; fail(error.localizedDescription)

        }
    }
    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor in
        guard stream === self.stream else { return }
        // Preserve any usable partial recording for a manual transcription retry.
        fail("Capture stopped: " + error.localizedDescription)

        }
    }
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
        guard recordingOutput === output, !finishing, let record else { return }
        finishing = true
        self.stream = nil; output = nil
        disablePicker()
        updateRecord { $0.status = "Recorded" }
        transcriptionTask = Task { await transcribe(record) }

        }
    }
    func retry(_ recording: MeetingRecording, store: NoteStore, noteID: UUID) {
        guard !busy else { return }
        self.store = store; self.noteID = noteID; self.record = recording
        store.recordingNoteID = noteID; errorMessage = nil
        transcriptionTask = Task { await transcribe(recording) }
    }
    func cancelTranscription() {
        guard phase == "Transcribing on this Mac" else { return }
        transcriptionTask?.cancel()
        updateRecord { $0.status = "Recorded · transcription cancelled" }
        reset()
    }
    private func transcribe(_ recording: MeetingRecording) async {
        guard let store, let url = Self.fileURL(recording, storage: store.storageURL) else { fail("Invalid recording path."); return }
        phase = "Transcribing on this Mac"
        updateRecord { $0.status = "Transcribing" }
        do {
            let segments = try await MeetingTranscription.transcribe(url: url, locale: Locale(identifier: recording.locale))
            guard record?.id == recording.id, !Task.isCancelled else { return }
            updateRecord { $0.transcript = segments; $0.status = segments.isEmpty ? "No speech detected" : "Transcribed" }
            reset()
        } catch { if record?.id == recording.id && !Task.isCancelled { fail("Recording kept. Transcription failed: " + error.localizedDescription) } }
    }
    private func updateRecord(_ change: (inout MeetingRecording) -> Void) {
        guard let store, let noteID, let record else { return }
        store.update(noteID) { note in
            if let index = note.recordings?.firstIndex(where: { $0.id == record.id }) { change(&note.recordings![index]) }
        }
    }
    private func fail(_ message: String) {
        errorMessage = message
        updateRecord { $0.status = message }
        if let stream { Task { try? await stream.stopCapture() } }
        reset()
    }
    private func disablePicker() {
        let picker = SCContentSharingPicker.shared
        picker.remove(self); picker.isActive = false
    }
    private func reset() {
        disablePicker(); store?.recordingNoteID = nil
        stream = nil; output = nil; record = nil; noteID = nil; started = nil; phase = ""; store = nil; finishing = false
    }
}

// Keep recognition independent of the capture lifecycle so saved recordings can
// be retried after a model download, unsupported locale, or interrupted session.
enum MeetingMedia {
    static func error(_ text: String) -> NSError { NSError(domain: "one.measured.notes.meetings", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
    static func copy(source: URL, to destination: URL) throws {
        guard source.standardizedFileURL.resolvingSymlinksInPath() != destination.standardizedFileURL.resolvingSymlinksInPath() else { return }
        let temp = destination.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.copyItem(at: source, to: temp)
        if FileManager.default.fileExists(atPath: destination.path) { _ = try FileManager.default.replaceItemAt(destination, withItemAt: temp) }
        else { try FileManager.default.moveItem(at: temp, to: destination) }
    }
}

enum MeetingTranscription {
    static func supportedLanguages() async -> [Locale] {
        await SpeechTranscriber.supportedLocales.sorted { $0.identifier < $1.identifier }
    }
    static func transcribe(url: URL, locale: Locale) async throws -> [TranscriptSegment] {
        guard SpeechTranscriber.isAvailable,
              let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw MeetingMedia.error("Apple Speech does not support the selected language on this Mac.")
        }
        let transcriber = SpeechTranscriber(locale: supported, preset: .transcription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        try Task.checkCancellation()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let asset = AVURLAsset(url: url)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw MeetingMedia.error("Could not read audio from this recording.")
        }
        try await exporter.export(to: temporary, as: .m4a)
        try Task.checkCancellation()
        let file = try AVAudioFile(forReading: temporary)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let results = Task { () throws -> [TranscriptSegment] in
            var segments: [TranscriptSegment] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { segments.append(TranscriptSegment(seconds: max(0, result.range.start.seconds), text: text)) }
            }
            return segments
        }
        do {
            return try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
                return try await results.value
            } onCancel: {
                results.cancel()
                Task { await analyzer.cancelAndFinishNow() }
            }
        } catch {
            await analyzer.cancelAndFinishNow(); results.cancel(); throw error
        }
    }
}
