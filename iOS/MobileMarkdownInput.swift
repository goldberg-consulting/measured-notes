import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MobileMarkdownInput: UIViewRepresentable {
    @Binding var text: String
    var importMedia: (Data, String, UTType) throws -> String
    var reportError: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> PasteNoteView {
        let view = PasteNoteView()
        view.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.accessibilityLabel = "Markdown editor"
        view.delegate = context.coordinator
        view.pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [UTType.image.identifier, UTType.movie.identifier, UTType.video.identifier, UTType.data.identifier, UTType.url.identifier, UTType.text.identifier])
        let paste = UIPasteControl()
        paste.target = view
        let toolbar = UIToolbar()
        toolbar.items = [UIBarButtonItem(customView: paste), .flexibleSpace(), UIBarButtonItem(title: "Done", style: .prominent, target: view, action: #selector(PasteNoteView.dismissKeyboard))]
        toolbar.sizeToFit()
        view.inputAccessoryView = toolbar
        view.text = text
        configure(view, context: context)
        return view
    }
    func updateUIView(_ view: PasteNoteView, context: Context) {
        context.coordinator.parent = self
        configure(view, context: context)
        if view.text != text {
            let selection = view.selectedRange
            view.text = text
            view.selectedRange = NSRange(location: min(selection.location, (text as NSString).length), length: 0)
        }
    }
    private func configure(_ view: PasteNoteView, context: Context) {
        view.importMedia = { try context.coordinator.parent.importMedia($0, $1, $2) }
        view.reportError = { context.coordinator.parent.reportError($0) }
    }
    static func dismantleUIView(_ view: PasteNoteView, coordinator: Coordinator) {
        view.pasteTask?.cancel()
        view.delegate = nil
        view.importMedia = nil
        view.reportError = nil
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MobileMarkdownInput
        init(_ parent: MobileMarkdownInput) { self.parent = parent }
        func textViewDidChange(_ view: UITextView) { parent.text = view.text }
    }
}

final class PasteNoteView: UITextView {
    var importMedia: ((Data, String, UTType) throws -> String)?
    var reportError: ((String) -> Void)?
    var pasteTask: Task<Void, Never>?

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)), UIPasteboard.general.hasImages || UIPasteboard.general.hasURLs || UIPasteboard.general.contains(pasteboardTypes: [UTType.movie.identifier, UTType.video.identifier, UTType.pdf.identifier, UTType.fileURL.identifier]) { return true }
        return super.canPerformAction(action, withSender: sender)
    }
    @objc func dismissKeyboard() { resignFirstResponder() }

    override func paste(_ sender: Any?) {
        paste(itemProviders: UIPasteboard.general.itemProviders)
    }
    override func paste(itemProviders providers: [NSItemProvider]) {
        guard pasteTask == nil else { return }
        pasteTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.pasteTask = nil }
            do {
                for provider in providers {
                    let types = provider.registeredTypeIdentifiers.compactMap(UTType.init)
                    let mediaType = types.first(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
                        ?? types.first(where: { $0.conforms(to: .image) })
                        ?? types.first(where: { $0.conforms(to: .data) && !$0.conforms(to: .text) && !$0.conforms(to: .url) })
                    if let type = mediaType {
                        let data = try await MobileMediaTransfer.read(provider, type: type)
                        try Task.checkCancellation()
                        let name = MobileMediaTransfer.name(provider.suggestedName, type: type)
                        guard let markdown = try self.importMedia?(data, name, type) else { return }
                        self.insertText("\n" + markdown + "\n")
                    } else if provider.canLoadObject(ofClass: NSURL.self), let url = try await MobileMediaTransfer.url(provider), url.isFileURL {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isRegularFileKey])
                        guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= MobileMediaTransfer.limit else { throw CocoaError(.fileReadTooLarge) }
                        let bytes = try Data(contentsOf: url)
                        try Task.checkCancellation()
                        guard let markdown = try self.importMedia?(bytes, url.lastPathComponent, values.contentType ?? .data) else { return }
                        self.insertText("\n" + markdown + "\n")
                    } else {
                        let text = try await MobileMediaTransfer.text(provider)
                        try Task.checkCancellation()
                        self.insertText(text)
                    }
                }
            } catch is CancellationError { }
            catch { self.reportError?(error.localizedDescription) }
        }
    }
}

enum MobileMediaTransfer {
    static func url(_ provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: NSURL.self) { object, error in
                if let url = object as? URL { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? CocoaError(.fileReadCorruptFile)) }
            }
        }
    }
    static func text(_ provider: NSItemProvider) async throws -> String {
        if provider.canLoadObject(ofClass: NSURL.self), let value = try await url(provider) { return value.absoluteString }
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: NSString.self) { object, error in
                if let text = object as? String { continuation.resume(returning: text) }
                else { continuation.resume(throwing: error ?? CocoaError(.fileReadCorruptFile)) }
            }
        }
    }
    static let limit = 100 * 1024 * 1024
    static func name(_ name: String?, type: UTType) -> String {
        let base = (name ?? "Attachment") as NSString
        let safe = base.lastPathComponent
        return (safe as NSString).pathExtension.isEmpty ? safe + "." + (type.preferredFilenameExtension ?? "bin") : safe
    }
    static func read(_ provider: NSItemProvider, type: UTType) async throws -> Data {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                    do {
                        guard let url else { throw error ?? CocoaError(.fileReadUnknown) }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                        guard size <= limit else { throw CocoaError(.fileReadTooLarge) }
                        let data = try Data(contentsOf: url)
                        guard data.count <= limit else { throw CocoaError(.fileReadTooLarge) }
                        continuation.resume(returning: data)
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } catch {
            // Some clipboard images supply bytes without a file representation.
            guard type.conforms(to: .image) else { throw error }
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                    guard let data, data.count <= limit else {
                        continuation.resume(throwing: error ?? CocoaError(.fileReadTooLarge)); return
                    }
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
