import AppKit
import SwiftUI

/// One autosaved buffer, the equivalent of the web app's localStorage buffer.
@MainActor
final class ScratchpadStore: ObservableObject {
    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("MarkdownPreview", isDirectory: true)
            .appendingPathComponent("scratchpad.md")
    }

    let url: URL
    @Published var text: String {
        didSet {
            if text != oldValue { scheduleSave() }
        }
    }

    private var saveTask: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    /// Loads the saved buffer. A missing or empty file is seeded with the
    /// sample document, matching the web app (`if (lastContent) ... else defaultInput`).
    init(url: URL = ScratchpadStore.defaultURL, seed: String = SampleDocument.text) {
        self.url = url
        let saved = try? String(contentsOf: url, encoding: .utf8)
        if let saved, !saved.isEmpty {
            self.text = saved
        } else {
            self.text = seed
        }
        // Flush on quit so the last keystrokes inside the debounce window survive.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url, options: .atomic)
        } catch {
            NSLog("Scratchpad save failed: \(error)")
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }
}

struct ScratchpadView: View {
    static let windowID = "scratchpad"
    @StateObject private var store = ScratchpadStore()

    var body: some View {
        ContentView(text: $store.text, documentURL: nil)
            .navigationTitle("Scratchpad")
    }
}
