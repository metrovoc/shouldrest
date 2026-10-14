import AppKit
import Foundation

@MainActor
final class AboutWindowController: NSWindowController {
    private enum Metrics {
        static let width: CGFloat = 580
        static let contentWidth: CGFloat = 500
    }

    private let version: String
    private let projectURL: URL
    private let onOpenDebug: () -> Void
    private let onOpenProject: (URL) -> Void
    private let closeButton = NSButton()
    private let debugButton = NSButton()
    private let projectButton = NSButton()

    init(
        version: String,
        projectURL: URL,
        onOpenDebug: @escaping () -> Void,
        onOpenProject: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.version = version
        self.projectURL = projectURL
        self.onOpenDebug = onOpenDebug
        self.onOpenProject = onOpenProject

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.width, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("about.title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        super.init(window: window)

        let contentView = buildContent()
        window.contentView = contentView
        contentView.layoutSubtreeIfNeeded()
        let height = max(400, ceil(contentView.fittingSize.height))
        window.setContentSize(NSSize(width: Metrics.width, height: height))
        window.center()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContent() -> NSView {
        configureButtons()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 20
        root.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 24, right: 40)
        root.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(root)

        let header = headerView()
        root.addArrangedSubview(header)
        root.addArrangedSubview(summaryPanel())
        root.addArrangedSubview(buttonRow())
        root.setCustomSpacing(24, after: header)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        return contentView
    }

    private func headerView() -> NSView {
        let icon = NSImageView(image: RestGateIcon.appIcon(size: 88, accessibilityDescription: L10n.tr("app.name")))
        icon.identifier = NSUserInterfaceItemIdentifier("about.brandIcon")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 88).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 88).isActive = true

        let title = NSTextField(labelWithString: L10n.tr("app.name"))
        title.identifier = NSUserInterfaceItemIdentifier("about.heading")
        title.font = .systemFont(ofSize: 26, weight: .bold)

        let versionLabel = NSTextField(labelWithString: L10n.format("about.version", version))
        versionLabel.identifier = NSUserInterfaceItemIdentifier("about.version")
        versionLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.isSelectable = true

        let tagline = NSTextField(wrappingLabelWithString: L10n.tr("about.tagline"))
        tagline.identifier = NSUserInterfaceItemIdentifier("about.tagline")
        tagline.font = .systemFont(ofSize: 13, weight: .medium)
        tagline.textColor = .secondaryLabelColor
        tagline.alignment = .center
        tagline.isSelectable = false
        tagline.preferredMaxLayoutWidth = 420
        tagline.widthAnchor.constraint(lessThanOrEqualToConstant: 420).isActive = true

        let header = NSStackView(views: [icon, title, versionLabel, tagline])
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 4
        header.setCustomSpacing(14, after: icon)
        header.setCustomSpacing(10, after: versionLabel)
        header.widthAnchor.constraint(greaterThanOrEqualToConstant: Metrics.contentWidth).isActive = true
        return header
    }

    private func summaryPanel() -> NSView {
        let panel = SurfaceStackView(style: .card)
        panel.identifier = NSUserInterfaceItemIdentifier("about.summaryPanel")
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 14
        panel.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        panel.addArrangedSubview(featureRow(
            identifier: "about.feature.eyeGate",
            image: RestGateIcon.glyphImage(pointSize: 18, accessibilityDescription: L10n.tr("about.eyeGateTitle")),
            title: L10n.tr("about.eyeGateTitle"),
            body: L10n.tr("about.eyeGateBody")
        ))
        panel.addArrangedSubview(featureRow(
            identifier: "about.feature.bodyBreak",
            image: symbolImage("figure.walk", accessibilityDescription: L10n.tr("about.bodyBreakTitle")),
            title: L10n.tr("about.bodyBreakTitle"),
            body: L10n.tr("about.bodyBreakBody")
        ))
        panel.addArrangedSubview(featureRow(
            identifier: "about.feature.compatibility",
            image: symbolImage("slider.horizontal.3", accessibilityDescription: L10n.tr("about.compatibilityTitle")),
            title: L10n.tr("about.compatibilityTitle"),
            body: L10n.tr("about.compatibilityBody")
        ))
        panel.widthAnchor.constraint(equalToConstant: Metrics.contentWidth).isActive = true
        return panel
    }

    private func featureRow(identifier: String, image: NSImage, title: String, body: String) -> NSView {
        let row = NSStackView()
        row.identifier = NSUserInterfaceItemIdentifier(identifier)
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12

        let icon = NSImageView(image: image)
        icon.identifier = NSUserInterfaceItemIdentifier("\(identifier).icon")
        icon.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        icon.contentTintColor = .controlAccentColor
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let tile = SurfaceView(style: SurfaceStyle(
            fill: { NSColor.controlAccentColor.withAlphaComponent($0 ? 0.22 : 0.13) },
            stroke: { _ in nil },
            cornerRadius: 8
        ))
        tile.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 30),
            tile.heightAnchor.constraint(equalToConstant: 30),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18)
        ])

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let bodyWidth = Metrics.contentWidth - 32 - 30 - 12
        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.isSelectable = false
        bodyLabel.preferredMaxLayoutWidth = bodyWidth
        bodyLabel.widthAnchor.constraint(equalToConstant: bodyWidth).isActive = true

        let copyStack = NSStackView(views: [titleLabel, bodyLabel])
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 2

        row.addArrangedSubview(tile)
        row.addArrangedSubview(copyStack)
        return row
    }

    private func buttonRow() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [projectButton, debugButton, spacer, closeButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: Metrics.contentWidth).isActive = true
        return row
    }

    private func configureButtons() {
        configureButton(
            projectButton,
            identifier: "about.projectButton",
            title: L10n.tr("about.project"),
            symbolName: "arrow.up.right.square",
            action: #selector(openProjectPressed),
            toolTip: L10n.tr("about.projectHelp")
        )
        configureButton(
            debugButton,
            identifier: "about.debugButton",
            title: L10n.tr("about.debug"),
            symbolName: "doc.text.magnifyingglass",
            action: #selector(openDebugPressed),
            toolTip: L10n.tr("about.debugHelp")
        )
        configureButton(
            closeButton,
            identifier: "about.closeButton",
            title: L10n.tr("about.close"),
            symbolName: "checkmark",
            action: #selector(closePressed),
            toolTip: L10n.tr("about.closeHelp")
        )
        closeButton.keyEquivalent = "\r"
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
        button.controlSize = .large
        button.image = symbolImage(symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.toolTip = toolTip
        button.setAccessibilityLabel(title)
        button.setAccessibilityHelp(toolTip)
        button.setContentHuggingPriority(.required, for: .horizontal)
    }

    @objc private func openDebugPressed() {
        onOpenDebug()
    }

    @objc private func openProjectPressed() {
        onOpenProject(projectURL)
    }

    @objc private func closePressed() {
        window?.performClose(nil)
    }

    private func symbolImage(_ name: String, accessibilityDescription: String? = nil) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) ?? NSImage()
    }
}
