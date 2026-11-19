import AppKit
import SwiftUI
import WebKit

/// Owns the render queue for one preview. The web view is created (and
/// re-created, e.g. when the layout flips) by `PreviewView`; this object
/// outlives it and replays the latest Markdown once the page reports `ready`.
@MainActor
final class PreviewController: ObservableObject {
    private weak var webView: WKWebView?
    private var schemeHandler: LocalFileSchemeHandler?
    private var isReady = false
    private var latestMarkdown = ""
    private var renderTask: Task<Void, Never>?

    var documentDirectory: URL? {
        didSet { schemeHandler?.documentRoot = documentDirectory }
    }

    func attach(webView: WKWebView, schemeHandler: LocalFileSchemeHandler) {
        self.webView = webView
        self.schemeHandler = schemeHandler
        schemeHandler.documentRoot = documentDirectory
        isReady = false
    }

    func handle(_ message: PreviewBridge.Message) {
        switch message {
        case .ready:
            isReady = true
            webView?.alphaValue = 1  // shown only once the page can paint its own background
            Task {
                await run(PreviewBridge.baseScript, ["href": PreviewBridge.documentBaseURL])
                await pushMarkdown()
            }
        }
    }

    /// The web content process died; hide the blank view until the reloaded page reports `ready` again.
    func pageDidTerminate() {
        isReady = false
        webView?.alphaValue = 0
    }

    /// Debounced ~50 ms. Calls made before the page is ready are replayed on `ready`.
    func render(_ markdown: String) {
        latestMarkdown = markdown
        guard isReady else { return }
        renderTask?.cancel()
        renderTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            await self?.pushMarkdown()
        }
    }

    func setScrollRatio(_ ratio: Double) {
        guard isReady, ratio.isFinite else { return }
        Task { _ = await run(PreviewBridge.scrollScript, ["ratio": ratio]) }
    }

    /// The sanitized HTML of the preview, after Mermaid has finished drawing.
    func renderedHTML() async -> String? {
        guard isReady else { return nil }
        return await run(PreviewBridge.htmlScript, [:]) as? String
    }

    private func pushMarkdown() async {
        await run(PreviewBridge.renderScript, ["markdown": latestMarkdown])
    }

    @discardableResult
    private func run(_ script: String, _ arguments: [String: Any]) async -> Any? {
        guard let webView else { return nil }
        do {
            return try await webView.callAsyncJavaScript(
                script, arguments: arguments, in: nil, contentWorld: .page)
        } catch {
            NSLog("Preview script failed: \(error)")
            return nil
        }
    }
}

struct PreviewView: NSViewRepresentable {
    let controller: PreviewController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> WKWebView {
        let handler = LocalFileSchemeHandler(appRoot: LocalFileSchemeHandler.bundledAppRoot())
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: PreviewBridge.scheme)
        config.userContentController.add(context.coordinator, name: PreviewBridge.handlerName)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // Invisible until the page reports `ready`, so there is no white flash before it paints (see PreviewController.handle).
        webView.alphaValue = 0

        controller.attach(webView: webView, schemeHandler: handler)
        webView.load(URLRequest(url: PreviewBridge.pageURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: PreviewBridge.handlerName)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let controller: PreviewController

        init(controller: PreviewController) {
            self.controller = controller
        }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard let parsed = PreviewBridge.parse(message.body) else { return }
            Task { @MainActor in controller.handle(parsed) }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Task { @MainActor in controller.pageDidTerminate() }
            webView.load(URLRequest(url: PreviewBridge.pageURL))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let decision = PreviewNavigation.decide(
                url: url, linkActivated: navigationAction.navigationType == .linkActivated)

            switch decision {
            case .allow:
                decisionHandler(.allow)
            case .cancel:
                decisionHandler(.cancel)
            case .openExternally(let external):
                NSWorkspace.shared.open(external)
                decisionHandler(.cancel)
            case .openFile:
                // A link to a sibling file: only reveal it in Finder. Opening it could launch an app or script from the folder.
                Task { @MainActor in
                    let target = LocalFileSchemeHandler.resolve(
                        url: url,
                        appRoot: LocalFileSchemeHandler.bundledAppRoot(),
                        documentRoot: controller.documentDirectory)
                    if let target, FileManager.default.fileExists(atPath: target.path) {
                        NSWorkspace.shared.activateFileViewerSelecting([target])
                    }
                }
                decisionHandler(.cancel)
            }
        }
    }
}
