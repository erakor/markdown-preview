import XCTest
@testable import MarkdownPreview

@MainActor
final class LocalFileSchemeHandlerTests: XCTestCase {
    private let appRoot = URL(fileURLWithPath: "/tmp/app/Renderer", isDirectory: true)
    private let docRoot = URL(fileURLWithPath: "/tmp/docs/notes", isDirectory: true)

    private func resolve(_ string: String, docRoot: URL? = URL(fileURLWithPath: "/tmp/docs/notes", isDirectory: true)) -> String? {
        LocalFileSchemeHandler.resolve(url: URL(string: string)!, appRoot: appRoot, documentRoot: docRoot)?.path
    }

    func testResolvesAppAndDocumentFiles() {
        XCTAssertEqual(resolve("mdpreview://app/preview.html"), "/tmp/app/Renderer/preview.html")
        XCTAssertEqual(resolve("mdpreview://doc/images/a.png"), "/tmp/docs/notes/images/a.png")
        XCTAssertEqual(resolve("mdpreview://doc/my%20image.png"), "/tmp/docs/notes/my image.png")
    }

    func testRefusesParentTraversal() {
        XCTAssertNil(resolve("mdpreview://doc/../secret.txt"))
        XCTAssertNil(resolve("mdpreview://doc/images/../../secret.txt"))
        XCTAssertNil(resolve("mdpreview://doc/%2e%2e/secret.txt"))
        XCTAssertNil(resolve("mdpreview://doc/..%2Fsecret.txt"))
        XCTAssertNil(resolve("mdpreview://app/../Info.plist"))
        XCTAssertNil(resolve("mdpreview://doc/./a.png"))
    }

    func testRefusesSiblingDirectoryWithSharedPrefix() {
        // "/tmp/docs/notes-evil" starts with "/tmp/docs/notes" as a string; it must still be refused.
        XCTAssertNil(resolve("mdpreview://doc/../notes-evil/x.txt"))
    }

    func testRefusesUnknownHostsSchemesAndMissingRoot() {
        XCTAssertNil(resolve("mdpreview://other/a.png"))
        XCTAssertNil(resolve("https://app/preview.html"))
        XCTAssertNil(resolve("mdpreview://doc/a.png", docRoot: nil))
        XCTAssertNil(resolve("mdpreview://app/"))
        XCTAssertNil(resolve("mdpreview://app"))
    }

    func testRefusesSymlinkThatLeavesTheRoot() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = base.appendingPathComponent("docs", isDirectory: true)
        let outside = base.appendingPathComponent("outside", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        try Data("secret".utf8).write(to: outside.appendingPathComponent("secret.txt"))
        try Data("ok".utf8).write(to: root.appendingPathComponent("a.txt"))
        try fm.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: outside)

        XCTAssertNil(resolve("mdpreview://doc/link/secret.txt", docRoot: root))
        XCTAssertNotNil(resolve("mdpreview://doc/a.txt", docRoot: root))
    }

    func testMimeTypes() {
        XCTAssertEqual(LocalFileSchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/a.html")), "text/html")
        XCTAssertEqual(LocalFileSchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/a.css")), "text/css")
        XCTAssertEqual(LocalFileSchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/a.svg")), "image/svg+xml")
        XCTAssertEqual(LocalFileSchemeHandler.mimeType(for: URL(fileURLWithPath: "/x/a.unknownext")), "application/octet-stream")
    }
}
