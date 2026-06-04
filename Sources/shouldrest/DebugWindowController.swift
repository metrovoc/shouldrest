import AppKit
import Foundation

enum DebugSafetySeverity {
    case ready
    case active
    case warning
}

struct DebugSafetySummary {
    var title: String
    var body: String
    var symbolName: String
    var severity: DebugSafetySeverity

    static var ready: DebugSafetySummary {
        DebugSafetySummary(
            title: L10n.tr("debug.summaryReadyTitle"),
            body: L10n.tr("debug.summaryReadyBody"),
            symbolName: "checkmark.shield",
            severity: .ready
        )
    }
}

@MainActor
final class DebugWindowController: NSWindowController {
    private let debugInfoProvider: () -> String
    private let safetySummaryProvider: () -> DebugSafetySummary
    private let textView = NSTextView()
    private let safetyPanel = NSView()
    private let safetyIcon = NSImageView()
    private let safetyTitleLabel = NSTextField(labelWithString: "")
    private let safetyBodyLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton()
    private let refreshButton = NSButton()
    private let openLogButton = NSButton()
    private let openSettingsButton = NSButton()
    private var logURL: URL?
    private var settingsURL: URL?

    init(
        debugInfoProvider: @escaping () -> String = { "" },
        safetySummaryProvider: @escaping () -> DebugSafetySummary = { .ready }
    ) {
        self.debugInfoProvider = debugInfoProvider
        self.safetySummaryProvider = safetySummaryProvider

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("debug.title")
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.minSize = NSSize(width: 640, height: 420)
        super.init(window: window)

        window.contentView = buildContent()
        window.center()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(text: String, logURL: URL? = nil, settingsURL: URL? = nil) {
        textView.string = text
        self.logURL = logURL
        self.settingsURL = settingsURL
        updateSafetySummary()
        updatePathButtons()
    }

    private func buildContent() -> NSView {
        configureTextView()
        configureSafetySummary()
        configureButtons()
        configureStatusLabel()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 18, right: 24)
        root.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(root)

        let textScrollView = NSScrollView()
        textScrollView.identifier = NSUserInterfaceItemIdentifier("debug.textScroll")
        textScrollView.hasVerticalScroller = true
        textScrollView.hasHorizontalScroller = true
        textScrollView.drawsBackground = true
        textScrollView.borderType = .bezelBorder
        textScrollView.translatesAutoresizingMaskIntoConstraints = false
        textScrollView.documentView = textView

        let header = headerView()
        let safetySummary = safetySummaryView()
        let footer = footerView()

        root.addArrangedSubview(header)
        root.addArrangedSubview(safetySummary)
        root.addArrangedSubview(textScrollView)
        root.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            textScrollView.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -48),
            textScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
            header.widthAnchor.constraint(equalTo: textScrollView.widthAnchor),
            safetySummary.widthAnchor.constraint(equalTo: textScrollView.widthAnchor),
            footer.widthAnchor.constraint(equalTo: textScrollView.widthAnchor)
        ])

        return contentView
    }

    private func headerView() -> NSView {
        let icon = NSImageView(image: symbolImage("stethoscope"))
        icon.identifier = NSUserInterfaceItemIdentifier("debug.headerIcon")
        icon.contentTintColor = .controlAccentColor
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 40).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let title = NSTextField(labelWithString: L10n.tr("debug.heading"))
        title.identifier = NSUserInterfaceItemIdentifier("debug.heading")
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let subtitle = NSTextField(labelWithString: L10n.tr("debug.subtitle"))
        subtitle.identifier = NSUserInterfaceItemIdentifier("debug.subtitle")
        subtitle.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let copyStack = NSStackView(views: [title, subtitle])
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 4

        let header = NSStackView(views: [icon, copyStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        return header
    }

    private func safetySummaryView() -> NSView {
        let copyStack = NSStackView(views: [safetyTitleLabel, safetyBodyLabel])
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 3
        copyStack.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [safetyIcon, copyStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        safetyPanel.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: safetyPanel.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: safetyPanel.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: safetyPanel.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: safetyPanel.bottomAnchor, constant: -10)
        ])

        return safetyPanel
    }

    private func footerView() -> NSView {
        let leftButtons = NSStackView(views: [copyButton, refreshButton])
        leftButtons.orientation = .horizontal
        leftButtons.alignment = .centerY
        leftButtons.spacing = 8

        let pathButtons = NSStackView(views: [openLogButton, openSettingsButton])
        pathButtons.orientation = .horizontal
        pathButtons.alignment = .centerY
        pathButtons.spacing = 8

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let footer = NSStackView(views: [leftButtons, statusLabel, spacer, pathButtons])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12
        return footer
    }

    private func configureTextView() {
        textView.identifier = NSUserInterfaceItemIdentifier("debug.textView")
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    private func configureButtons() {
        configureButton(
            copyButton,
            identifier: "debug.copyButton",
            title: L10n.tr("debug.copy"),
            symbolName: "doc.on.doc",
            action: #selector(copyPressed),
            toolTip: L10n.tr("debug.copyHelp")
        )
        configureButton(
            refreshButton,
            identifier: "debug.refreshButton",
            title: L10n.tr("debug.refresh"),
            symbolName: "arrow.clockwise",
            action: #selector(refreshPressed),
            toolTip: L10n.tr("debug.refreshHelp")
        )
        configureButton(
            openLogButton,
            identifier: "debug.openLogButton",
            title: L10n.tr("debug.openLog"),
            symbolName: "doc.text.magnifyingglass",
            action: #selector(openLogPressed),
            toolTip: L10n.tr("debug.openLogHelp")
        )
        configureButton(
            openSettingsButton,
            identifier: "debug.openSettingsButton",
            title: L10n.tr("debug.openSettings"),
            symbolName: "gearshape",
            action: #selector(openSettingsPressed),
            toolTip: L10n.tr("debug.openSettingsHelp")
        )
    }

    private func configureSafetySummary() {
        safetyPanel.identifier = NSUserInterfaceItemIdentifier("debug.safetyPanel")
        safetyPanel.wantsLayer = true
        safetyPanel.layer?.cornerRadius = 8
        safetyPanel.layer?.borderWidth = 1
        safetyPanel.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.8).cgColor

        safetyIcon.identifier = NSUserInterfaceItemIdentifier("debug.safetyIcon")
        safetyIcon.symbolConfiguration = .init(pointSize: 17, weight: .semibold)
        safetyIcon.imageScaling = .scaleProportionallyUpOrDown
        safetyIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        safetyIcon.heightAnchor.constraint(equalToConstant: 24).isActive = true

        safetyTitleLabel.identifier = NSUserInterfaceItemIdentifier("debug.safetyTitle")
        safetyTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        safetyBodyLabel.identifier = NSUserInterfaceItemIdentifier("debug.safetyBody")
        safetyBodyLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        safetyBodyLabel.textColor = .secondaryLabelColor
        safetyBodyLabel.lineBreakMode = .byWordWrapping
        safetyBodyLabel.maximumNumberOfLines = 2
        safetyBodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        updateSafetySummary()
    }

    private func configureButton(
        _ button: NSButton,
        identifier: String,
        title: String,
        symbolName: String,
        action: Selector,
        toolTip: String
    ) {
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.title = title
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.image = symbolImage(symbolName)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.toolTip = toolTip
        button.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func configureStatusLabel() {
        statusLabel.identifier = NSUserInterfaceItemIdentifier("debug.status")
        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = L10n.tr("debug.ready")
    }

    private func updatePathButtons() {
        openLogButton.isEnabled = logURL != nil
        openSettingsButton.isEnabled = settingsURL != nil
        openLogButton.toolTip = logURL == nil ? L10n.tr("debug.pathHidden") : L10n.tr("debug.openLogHelp")
        openSettingsButton.toolTip = settingsURL == nil ? L10n.tr("debug.pathHidden") : L10n.tr("debug.openSettingsHelp")
    }

    private func updateSafetySummary() {
        let summary = safetySummaryProvider()
        safetyTitleLabel.stringValue = summary.title
        safetyBodyLabel.stringValue = summary.body
        safetyIcon.image = symbolImage(summary.symbolName)

        let tint: NSColor
        switch summary.severity {
        case .ready:
            tint = .controlAccentColor
        case .active:
            tint = .systemRed
        case .warning:
            tint = .systemOrange
        }
        safetyIcon.contentTintColor = tint
        safetyPanel.layer?.backgroundColor = tint.withAlphaComponent(0.08).cgColor
        safetyPanel.layer?.borderColor = tint.withAlphaComponent(0.26).cgColor
    }

    @objc private func copyPressed() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
        statusLabel.stringValue = L10n.tr("debug.copied")
    }

    @objc private func refreshPressed() {
        update(text: debugInfoProvider(), logURL: logURL, settingsURL: settingsURL)
        statusLabel.stringValue = L10n.tr("debug.updated")
    }

    @objc private func openLogPressed() {
        guard let logURL else { return }
        reveal(url: logURL)
    }

    @objc private func openSettingsPressed() {
        guard let settingsURL else { return }
        reveal(url: settingsURL)
    }

    private func reveal(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let parentURL = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(parentURL)
        }
    }

    private func symbolImage(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }
}
