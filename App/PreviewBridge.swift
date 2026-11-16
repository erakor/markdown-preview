import Foundation

/// Swift <-> JS contract with the renderer bundle (renderer/src/preview.js).
/// Everything here is pure so it can be unit tested without a WKWebView.
enum PreviewBridge {
    static let scheme = "mdpreview"
    static let appHost = "app"
    static let docHost = "doc"

    static let pageURL = URL(string: "\(scheme)://\(appHost)/preview.html")!
    static let documentBaseURL = "\(scheme)://\(docHost)/"

    // Scripts run with callAsyncJavaScript, so values arrive as `arguments`
    // and are never spliced into the source string (no escaping needed).
    static let renderScript = "window.renderMarkdown(markdown);"
    static let scrollScript = "window.setScrollRatio(ratio);"
    static let baseScript = "window.setBaseHref(href);"
    static let htmlScript = "await window.whenIdle(); return window.getHTML();"
    static func anchorScript() -> String {
        "const el = document.getElementById(id) || document.getElementsByName(id)[0]; if (el) { el.scrollIntoView(); }"
    }

    enum Message: Equatable {
        case ready
        case scroll(ratio: Double)
    }

    /// Parses a `webkit.messageHandlers.bridge.postMessage(...)` body.
    static func parse(_ body: Any) -> Message? {
        guard let dict = body as? [String: Any], let type = dict["type"] as? String else {
            return nil
        }
        switch type {
        case "ready":
            return .ready
        case "scroll":
            if let ratio = (dict["ratio"] as? NSNumber)?.doubleValue, ratio.isFinite {
                return .scroll(ratio: ratio)
            }
            return nil
        default:
            return nil
        }
    }
}

/// What to do with a navigation request from the preview. The web view only
/// ever shows mdpreview:// content; everything else goes to the system.
enum PreviewNavigation {
    enum Decision: Equatable {
        case allow
        case cancel
        case openExternally(URL)
        case openFile(relativePath: String)
        case scrollToAnchor(String)
    }

    static func decide(url: URL, linkActivated: Bool) -> Decision {
        guard let scheme = url.scheme?.lowercased() else { return .cancel }

        if scheme == PreviewBridge.scheme {
            // Programmatic loads (our own initial load) may only target the app page.
            guard linkActivated else {
                return url.host == PreviewBridge.appHost ? .allow : .cancel
            }
            guard url.host == PreviewBridge.docHost else { return .cancel }
            let path = url.path
            if (path.isEmpty || path == "/"), let fragment = url.fragment, !fragment.isEmpty {
                return .scrollToAnchor(fragment.removingPercentEncoding ?? fragment)
            }
            return path.isEmpty || path == "/" ? .cancel : .openFile(relativePath: path)
        }

        if linkActivated, ["http", "https", "mailto"].contains(scheme) {
            return .openExternally(url)
        }
        return .cancel
    }
}
