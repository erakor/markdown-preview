import XCTest
@testable import MarkdownPreview

@MainActor
final class EditorViewTests: XCTestCase {
    func testScrollRatioMatchesWebMaths() {
        XCTAssertEqual(EditorView.scrollRatio(offset: 0, contentHeight: 1000, visibleHeight: 500), 0)
        XCTAssertEqual(EditorView.scrollRatio(offset: 250, contentHeight: 1000, visibleHeight: 500), 0.5)
        XCTAssertEqual(EditorView.scrollRatio(offset: 500, contentHeight: 1000, visibleHeight: 500), 1)
    }

    func testScrollRatioIsClampedAndSafeWhenContentFits() {
        XCTAssertEqual(EditorView.scrollRatio(offset: 900, contentHeight: 1000, visibleHeight: 500), 1)
        XCTAssertEqual(EditorView.scrollRatio(offset: -20, contentHeight: 1000, visibleHeight: 500), 0)
        XCTAssertEqual(EditorView.scrollRatio(offset: 0, contentHeight: 300, visibleHeight: 500), 0)
    }
}
