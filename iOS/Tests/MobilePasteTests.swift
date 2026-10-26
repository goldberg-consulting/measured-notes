import XCTest
import UIKit
import UniformTypeIdentifiers

final class MobilePasteTests: XCTestCase {
    @MainActor func testPastedImageInsertsAtCursorAndNotifiesBinding() async throws {
        let data = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).pngData { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            completion(data, nil); return nil
        }
        let view = PasteNoteView()
        let delegate = EditObserver()
        view.delegate = delegate
        view.text = "beforeafter"
        view.selectedRange = NSRange(location: 6, length: 0)
        var imported = false
        view.importMedia = { bytes, _, type in
            XCTAssertEqual(bytes, data); XCTAssertTrue(type.conforms(to: .image))
            imported = true
            return "![Image](measured-image:test)"
        }
        view.reportError = { XCTFail($0) }
        view.paste(itemProviders: [provider])
        for _ in 0..<100 where view.pasteTask != nil { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(imported)
        XCTAssertEqual(view.text, "before\n![Image](measured-image:test)\nafter")
        XCTAssertGreaterThan(delegate.changes, 0)
    }

    @MainActor func testPlainLinkPastePreservesSurroundingText() async throws {
        let provider = NSItemProvider(object: NSURL(string: "https://example.com/meeting")!)
        let view = PasteNoteView()
        view.text = "Link: "
        view.selectedRange = NSRange(location: 6, length: 0)
        view.paste(itemProviders: [provider])
        for _ in 0..<100 where view.pasteTask != nil { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(view.text, "Link: https://example.com/meeting")
    }

    func testVideoFileTransferPreservesBytesAndExtension() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let bytes = Data([1, 2, 3, 4])
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let provider = NSItemProvider()
        provider.registerFileRepresentation(forTypeIdentifier: UTType.quickTimeMovie.identifier, fileOptions: [], visibility: .all) { completion in
            completion(url, false, nil); return nil
        }
        let copied = try await MobileMediaTransfer.read(provider, type: .quickTimeMovie)
        XCTAssertEqual(copied, bytes)
        XCTAssertEqual(MobileMediaTransfer.name("Clip", type: .quickTimeMovie), "Clip.mov")
    }
}

@MainActor private final class EditObserver: NSObject, UITextViewDelegate {
    var changes = 0
    func textViewDidChange(_ textView: UITextView) { changes += 1 }
}
