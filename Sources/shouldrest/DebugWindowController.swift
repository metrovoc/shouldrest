import AppKit
import Foundation

@MainActor
final class DebugWindowController: NSWindowController {
    private let textView = NSTextView()

    init() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 720, height: 460))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        scrollView.documentView = textView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ShouldRest Debug"
        window.contentView = scrollView
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(text: String) {
        textView.string = text
    }
}

