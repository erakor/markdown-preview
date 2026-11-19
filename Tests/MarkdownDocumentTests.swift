import XCTest

@testable import MarkdownPreview

final class MarkdownDocumentTests: XCTestCase {
    func testRoundTripPreservesUnicodeAndNewlines() throws {
        let text = "# Title\n\nCafé ☕ — 日本語\r\nline two\n"
        let decoded = try MarkdownDocument.decode(MarkdownDocument.encode(text))
        XCTAssertEqual(decoded, text)
    }

    func testDecodeStripsLeadingByteOrderMark() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("hello".utf8)
        XCTAssertEqual(try MarkdownDocument.decode(data), "hello")
    }

    func testDecodeRejectsInvalidUTF8() {
        XCTAssertThrowsError(try MarkdownDocument.decode(Data([0xFF, 0xFE, 0x00])))
    }

    func testEmptyFileDecodesToEmptyString() throws {
        XCTAssertEqual(try MarkdownDocument.decode(Data()), "")
    }

    func testSampleDocumentHasMermaidFenceAndNoIndentation() {
        XCTAssertTrue(SampleDocument.text.hasPrefix("# Markdown syntax guide"))
        XCTAssertTrue(SampleDocument.text.contains("```mermaid\ngraph TD"))
    }
}
