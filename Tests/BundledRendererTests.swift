import XCTest
@testable import MarkdownPreview

/// The other tests only exercise path logic; this one catches a packaging mistake
/// (wrong folder reference or exclude in project.yml) that would give a blank preview.
final class BundledRendererTests: XCTestCase {
    func testRendererFilesAreInsideTheAppBundle() {
        let root = LocalFileSchemeHandler.bundledAppRoot()
        for name in ["preview.html", "preview.js", "preview.css"] {
            let path = root.appendingPathComponent(name).path
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "missing from bundle: \(path)")
        }
    }
}
