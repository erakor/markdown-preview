import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves `mdpreview://app/...` from the bundled renderer and
/// `mdpreview://doc/...` from the open document's folder, so relative image
/// paths in Markdown work without enabling file:// access in the web view.
final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    let appRoot: URL
    /// Folder of the open document; nil for unsaved documents and the scratchpad.
    /// Only touched on the main thread (WebKit calls the handler there).
    var documentRoot: URL?

    init(appRoot: URL) {
        self.appRoot = appRoot
    }

    static func bundledAppRoot() -> URL {
        Bundle.main.resourceURL!.appendingPathComponent("Renderer", isDirectory: true)
    }

    // MARK: - Path resolution (unit tested)

    /// Maps a request URL to a file URL inside `appRoot` or `documentRoot`.
    /// Returns nil for unknown hosts, a missing document root, and anything
    /// that would leave the root (`..` segments, including percent-encoded ones).
    static func resolve(url: URL, appRoot: URL, documentRoot: URL?) -> URL? {
        guard url.scheme == PreviewBridge.scheme, let host = url.host else { return nil }

        let root: URL
        switch host {
        case PreviewBridge.appHost: root = appRoot
        case PreviewBridge.docHost:
            guard let documentRoot else { return nil }
            root = documentRoot
        default: return nil
        }

        // `url.path` is already percent-decoded, so %2e%2e shows up as "..".
        let segments = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !segments.isEmpty,
            !segments.contains(where: { $0 == ".." || $0 == "." || $0.contains("\0") })
        else {
            return nil
        }

        let rootURL = root.standardizedFileURL
        let candidate = segments.reduce(rootURL) { $0.appendingPathComponent($1) }.standardizedFileURL
        // Containment is judged on symlink-resolved paths, so a link inside the root cannot lead outside it.
        let resolvedRoot = rootURL.resolvingSymlinksInPath().path
        let rootPrefix = resolvedRoot.hasSuffix("/") ? resolvedRoot : resolvedRoot + "/"
        guard candidate.resolvingSymlinksInPath().path.hasPrefix(rootPrefix) else {
            return nil
        }
        return candidate
    }

    static func mimeType(for fileURL: URL) -> String {
        UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
            let fileURL = Self.resolve(url: url, appRoot: appRoot, documentRoot: documentRoot),
            let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe)
        else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let mime = Self.mimeType(for: fileURL)
        let isText = mime.hasPrefix("text/") || mime.contains("javascript") || mime.contains("svg")
        let response = URLResponse(
            url: url,
            mimeType: mime,
            expectedContentLength: data.count,
            textEncodingName: isText ? "utf-8" : nil
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
