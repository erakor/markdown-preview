import AppKit
import SwiftUI

/// Plain-text Markdown editor on NSTextView: monospaced, word wrap, find bar,
/// undo, and every automatic text substitution turned off (they corrupt Markdown).
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    /// Reports the vertical scroll position as 0...1 (for sync scroll).
    var onScroll: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.font = Self.font(size: fontSize)
        textView.textColor = .labelColor
        textView.string = text

        scrollView.hasVerticalScroller = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrolled(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only push the binding into the view when it changed from outside
        // (reset, file reload, undo of a document-level change). Edits made in
        // the view already match, which is what stops the feedback loop.
        if textView.string != text {
            context.coordinator.isUpdatingFromBinding = true
            let selection = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
            context.coordinator.isUpdatingFromBinding = false
        }

        if textView.font?.pointSize != CGFloat(fontSize) {
            textView.font = Self.font(size: fontSize)
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    static func font(size: Double) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: CGFloat(size), weight: .regular)
    }

    /// 0...1 position of a scroll view's visible rect; same maths as the web app (scrollTop / (scrollHeight - height)).
    static func scrollRatio(offset: CGFloat, contentHeight: CGFloat, visibleHeight: CGFloat) -> Double {
        let maxOffset = contentHeight - visibleHeight
        guard maxOffset > 0 else { return 0 }
        return Double(min(1, max(0, offset / maxOffset)))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        private var lastRatio = -1.0
        var isUpdatingFromBinding = false

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromBinding, let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        @objc func scrolled(_ notification: Notification) {
            // The notification fires for resizes and layout too; only forward real movement.
            guard let clip = notification.object as? NSClipView, let documentView = clip.documentView else { return }
            let ratio = EditorView.scrollRatio(
                offset: clip.bounds.origin.y,
                contentHeight: documentView.frame.height,
                visibleHeight: clip.bounds.height)
            guard abs(ratio - lastRatio) > 0.001 else { return }
            lastRatio = ratio
            parent.onScroll(ratio)
        }
    }
}
