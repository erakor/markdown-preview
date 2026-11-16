import SwiftUI

struct ContentView: View {
    @Binding var text: String
    /// nil for unsaved documents and the scratchpad.
    let documentURL: URL?

    @AppStorage(SettingsKey.syncScroll) private var syncScroll = SettingsDefault.syncScroll
    @AppStorage(SettingsKey.stackedLayout) private var stackedLayout = SettingsDefault.stackedLayout
    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsDefault.fontSize
    @StateObject private var preview = PreviewController()

    var body: some View {
        // Flipping between the two split views recreates the web view; the
        // controller replays the latest Markdown when the new page is ready.
        Group {
            if stackedLayout {
                VSplitView { editor; previewPane }
            } else {
                HSplitView { editor; previewPane }
            }
        }
        .frame(minWidth: 520, minHeight: 320)
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $stackedLayout) {
                    Label("Stack Layout", systemImage: stackedLayout ? "rectangle.split.1x2" : "rectangle.split.2x1")
                }
                .help("Switch between side-by-side and stacked layout")

                Toggle(isOn: $syncScroll) {
                    Label("Sync Scroll", systemImage: "arrow.up.and.down.text.horizontal")
                }
                .help("Scroll the preview along with the editor")

                Button {
                    Clipboard.copy(text)
                } label: {
                    Label("Copy Markdown", systemImage: "doc.on.doc")
                }
                .help("Copy the Markdown source")
            }
        }
        .focusedSceneValue(\.documentText, $text)
        .focusedSceneValue(\.previewController, preview)
        .onChange(of: text, initial: true) { _, newValue in
            preview.render(newValue)
        }
        .onChange(of: documentURL, initial: true) { _, url in
            preview.documentDirectory = url?.deletingLastPathComponent()
        }
    }

    private var editor: some View {
        EditorView(text: $text, fontSize: fontSize) { ratio in
            if syncScroll { preview.setScrollRatio(ratio) }
        }
        .frame(minWidth: 200, minHeight: 120)
    }

    private var previewPane: some View {
        PreviewView(controller: preview)
            .frame(minWidth: 200, minHeight: 120)
    }
}
