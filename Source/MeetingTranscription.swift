import Foundation
import AVFoundation
import Speech

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
            throw MeetingMedia.error("Apple Speech does not support the selected language on this device.")
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
                if !text.isEmpty { segments.append(TranscriptSegment(seconds: max(0, result.range.start.seconds), endSeconds: result.range.end.seconds, text: text)) }
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
