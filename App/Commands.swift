import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Focused values (let menu commands reach the frontmost window's state)

struct DocumentTextKey: FocusedValueKey { typealias Value = Binding<String> }
struct PreviewControllerKey: FocusedValueKey { typealias Value = PreviewController }

extension FocusedValues {
    var documentText: Binding<String>? {
        get { self[DocumentTextKey.self] }
        set { self[DocumentTextKey.self] = newValue }
    }

    var previewController: PreviewController? {
        get { self[PreviewControllerKey.self] }
        set { self[PreviewControllerKey.self] = newValue }
    }
}

enum Clipboard {
    static func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

// MARK: - Commands

struct AppCommands: Commands {
    @FocusedBinding(\.documentText) private var text: String?
    @FocusedValue(\.previewController) private var preview: PreviewController?
    @AppStorage(SettingsKey.syncScroll) private var syncScroll = SettingsDefault.syncScroll
    @AppStorage(SettingsKey.stackedLayout) private var stackedLayout = SettingsDefault.stackedLayout
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Markdown") {
                if let text { Clipboard.copy(text) }
            }
            .disabled(text == nil)

            Button("Copy HTML") {
                Task { @MainActor in
                    if let html = await preview?.renderedHTML() { Clipboard.copy(html) }
                }
            }
            .disabled(preview == nil)
        }

        CommandGroup(after: .importExport) {
            Button("Export HTML…") {
                Task { @MainActor in await exportHTML() }
            }
            .disabled(preview == nil)
        }

        CommandMenu("Preview") {
            Toggle("Sync Scroll", isOn: $syncScroll)
            Toggle("Stack Editor Above Preview", isOn: $stackedLayout)
            Divider()
            Button("Reset to Sample…") { resetToSample() }
                .disabled(text == nil)
        }

        CommandGroup(before: .windowList) {
            Button("Show Scratchpad") { openWindow(id: ScratchpadView.windowID) }
                .keyboardShortcut("0", modifiers: [.command, .shift])
        }
    }

    // Mirrors the web app's Reset: confirm first if anything was changed.
    private func resetToSample() {
        guard let current = text else { return }
        if current != SampleDocument.text {
            let alert = NSAlert()
            alert.messageText = "Reset to the sample document?"
            alert.informativeText = "Are you sure you want to reset? Your changes will be lost."
            alert.addButton(withTitle: "Reset")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        text = SampleDocument.text
    }

    @MainActor
    private func exportHTML() async {
        guard let html = await preview?.renderedHTML() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "preview.html"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let page = HTMLExport.standalonePage(body: html, css: HTMLExport.bundledCSS())
        do {
            try MarkdownDocument.encode(page).write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

enum HTMLExport {
    static func bundledCSS() -> String {
        let url = LocalFileSchemeHandler.bundledAppRoot().appendingPathComponent("preview.css")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// Self-contained page: the same stylesheet the preview uses, inlined, with
    /// light/dark following the viewer's system setting.
    static func standalonePage(body: String, css: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <title>Markdown Preview export</title>
        <style>
        \(css)
        </style>
        </head>
        <body>
        <div id="output" class="markdown-body">
        \(body)
        </div>
        </body>
        </html>
        """
    }
}
