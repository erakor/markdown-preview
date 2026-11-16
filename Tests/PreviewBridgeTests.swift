import XCTest
@testable import MarkdownPreview

final class PreviewBridgeTests: XCTestCase {
    // MARK: message parsing

    func testParsesReady() {
        XCTAssertEqual(PreviewBridge.parse(["type": "ready"]), .ready)
    }

    func testParsesScrollRatioFromIntAndDouble() {
        XCTAssertEqual(PreviewBridge.parse(["type": "scroll", "ratio": 0.25]), .scroll(ratio: 0.25))
        XCTAssertEqual(PreviewBridge.parse(["type": "scroll", "ratio": 1]), .scroll(ratio: 1))
    }

    func testRejectsMalformedMessages() {
        XCTAssertNil(PreviewBridge.parse("ready"))
        XCTAssertNil(PreviewBridge.parse(["type": "nope"]))
        XCTAssertNil(PreviewBridge.parse(["type": "scroll"]))
        XCTAssertNil(PreviewBridge.parse(["type": "scroll", "ratio": "x"]))
        XCTAssertNil(PreviewBridge.parse(["type": "scroll", "ratio": Double.nan]))
    }

    func testScriptsTakeValuesAsArgumentsNotInterpolation() {
        // callAsyncJavaScript passes `arguments` as JS variables; nothing user-controlled may be spliced in.
        XCTAssertEqual(PreviewBridge.renderScript, "window.renderMarkdown(markdown);")
        XCTAssertFalse(PreviewBridge.scrollScript.contains("\""))
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

    func testInPageAnchorsScrollInsteadOfNavigating() {
        // With <base href="mdpreview://doc/">, "#section" resolves to mdpreview://doc/#section.
        XCTAssertEqual(decide("mdpreview://doc/#my%20section", linked: true), .scrollToAnchor("my section"))
    }

    func testRelativeFileLinksOpenExternally() {
        XCTAssertEqual(decide("mdpreview://doc/notes/other.md", linked: true), .openFile(relativePath: "/notes/other.md"))
        XCTAssertEqual(decide("mdpreview://doc/", linked: true), .cancel)
    }
}
