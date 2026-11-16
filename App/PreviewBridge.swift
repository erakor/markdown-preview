import Foundation

/// Swift <-> JS contract with the renderer bundle (renderer/src/preview.js).
/// Everything here is pure so it can be unit tested without a WKWebView.
enum PreviewBridge {
    static let scheme = "mdpreview"
    static let appHost = "app"
    static let docHost = "doc"
    /// Name of the WKScriptMessageHandler; preview.js posts to `webkit.messageHandlers.bridge`.
    static let handlerName = "bridge"

    static let pageURL = URL(string: "\(scheme)://\(appHost)/preview.html")!
    static let documentBaseURL = "\(scheme)://\(docHost)/"

    // Scripts run with callAsyncJavaScript, so values arrive as `arguments`
    // and are never spliced into the source string (no escaping needed).
    static let renderScript = "window.renderMarkdown(markdown);"
    static let scrollScript = "window.setScrollRatio(ratio);"
    static let baseScript = "window.setBaseHref(href);"
    static let htmlScript = "await window.whenIdle(); return window.getHTML();"

    enum Message: Equatable {
        case ready
    }

    /// Parses a `webkit.messageHandlers.bridge.postMessage(...)` body.
    static func parse(_ body: Any) -> Message? {
        guard let dict = body as? [String: Any], dict["type"] as? String == "ready" else {
            return nil
        }
        return .ready
    }
}

/// What to do with a navigation request from the preview. The web view only
/// ever shows mdpreview:// content; everything else goes to the system.
/// (In-page `#anchor` links never get here: preview.js handles them itself.)
enum PreviewNavigation {
    enum Decision: Equatable {
        case allow
        case cancel
        case openExternally(URL)
        case openFile
    }

    static func decide(url: URL, linkActivated: Bool) -> Decision {
        guard let scheme = url.scheme?.lowercased() else { return .cancel }

        if scheme == PreviewBridge.scheme {
            // Programmatic loads (our own initial load) may only target the app page.
            guard linkActivated else {
                return url.host == PreviewBridge.appHost ? .allow : .cancel
            }
            let isRoot = url.path.isEmpty || url.path == "/"
            return url.host == PreviewBridge.docHost && !isRoot ? .openFile : .cancel
        }

        if linkActivated, ["http", "https", "mailto"].contains(scheme) {
            return .openExternally(url)
        }
        return .cancel
    }
}
