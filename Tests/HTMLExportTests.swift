import XCTest
@testable import MarkdownPreview

final class HTMLExportTests: XCTestCase {
    func testExportPageInlinesCSSAndBody() {
        let page = HTMLExport.standalonePage(body: "<h1>Hi</h1>", css: ".markdown-body{}")
        XCTAssertTrue(page.contains("<style>\n.markdown-body{}\n</style>"))
        XCTAssertTrue(page.contains("<h1>Hi</h1>"))
        XCTAssertTrue(page.contains("color-scheme"))
    }
}
