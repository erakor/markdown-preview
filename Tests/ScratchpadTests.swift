import XCTest
@testable import MarkdownPreview

@MainActor
final class ScratchpadTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private var fileURL: URL { dir.appendingPathComponent("nested/scratchpad.md") }

    func testFirstLaunchIsSeeded() {
        let store = ScratchpadStore(url: fileURL, seed: "seed")
        XCTAssertEqual(store.text, "seed")
    }

    func testSaveNowCreatesDirectoriesAndPersists() throws {
        let store = ScratchpadStore(url: fileURL, seed: "seed")
        store.text = "changed"
        store.saveNow()
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "changed")

        let reloaded = ScratchpadStore(url: fileURL, seed: "seed")
        XCTAssertEqual(reloaded.text, "changed")
    }

    func testEmptyFileIsReseededLikeTheWebApp() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: fileURL)
        XCTAssertEqual(ScratchpadStore(url: fileURL, seed: "seed").text, "seed")
    }

    func testDebouncedSaveEventuallyWrites() async throws {
        let store = ScratchpadStore(url: fileURL, seed: "seed")
        store.text = "typed"
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "typed")
    }
}
