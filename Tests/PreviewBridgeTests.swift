import XCTest
@testable import MarkdownPreview

final class PreviewBridgeTests: XCTestCase {
    // MARK: message parsing

    func testParsesReady() {
        XCTAssertEqual(PreviewBridge.parse(["type": "ready"]), .ready)
    }

    func testRejectsMalformedMessages() {
        XCTAssertNil(PreviewBridge.parse("ready"))
        XCTAssertNil(PreviewBridge.parse(["type": "nope"]))
        XCTAssertNil(PreviewBridge.parse(["type": "scroll", "ratio": 0.5]))
        XCTAssertNil(PreviewBridge.parse([:]))
    }

    // MARK: navigation policy

    private func decide(_ string: String, linked: Bool) -> PreviewNavigation.Decision {
        PreviewNavigation.decide(url: URL(string: string)!, linkActivated: linked)
    }

    func testInitialLoadOfAppPageIsAllowedButNothingElse() {
        XCTAssertEqual(decide("mdpreview://app/preview.html", linked: false), .allow)
        XCTAssertEqual(decide("mdpreview://doc/secret.md", linked: false), .cancel)
        XCTAssertEqual(decide("https://example.com", linked: false), .cancel)
        XCTAssertEqual(decide("file:///etc/passwd", linked: false), .cancel)
    }

    func testExternalLinksGoToTheSystem() {
        XCTAssertEqual(decide("https://example.com/a", linked: true), .openExternally(URL(string: "https://example.com/a")!))
        XCTAssertEqual(decide("mailto:a@b.c", linked: true), .openExternally(URL(string: "mailto:a@b.c")!))
        XCTAssertEqual(decide("javascript:alert(1)", linked: true), .cancel)
        XCTAssertEqual(decide("file:///etc/passwd", linked: true), .cancel)
    }

    func testRelativeFileLinksOpenExternally() {
        XCTAssertEqual(decide("mdpreview://doc/notes/other.md", linked: true), .openFile)
        XCTAssertEqual(decide("mdpreview://doc/", linked: true), .cancel)
    }
}
