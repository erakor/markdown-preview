import SwiftUI

@main
struct MarkdownPreviewApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument(text: SampleDocument.text)) { file in
            ContentView(text: file.$document.text, documentURL: file.fileURL)
        }
        .commands { AppCommands() }

        // One autosaved buffer, like the web app's localStorage buffer.
        Window("Scratchpad", id: ScratchpadView.windowID) {
            ScratchpadView()
        }

        Settings {
            SettingsView()
        }
    }
}
