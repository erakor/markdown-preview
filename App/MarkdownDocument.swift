import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Declared as an imported type in Info.plist (see project.yml).
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = try Self.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Self.encode(text))
    }

    // MARK: - Pure helpers (unit tested)

    /// UTF-8 only. A leading byte order mark is dropped so it never shows up in the editor.
    static func decode(_ data: Data) throws -> String {
        guard var string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        if string.hasPrefix("\u{FEFF}") {
            string.removeFirst()
        }
        return string
    }

    static func encode(_ text: String) -> Data {
        Data(text.utf8)
    }
}
