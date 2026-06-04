import AppKit
import Foundation

@MainActor
final class AboutWindowController: NSWindowController {
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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("about.title")
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        super.init(window: window)

        window.contentView = buildContent()
        window.center()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContent() -> NSView {
        configureButtons()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.edgeInsets = NSEdgeInsets(top: 28, left: 30, bottom: 22, right: 30)
        root.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(root)

        root.addArrangedSubview(headerView())
        root.addArrangedSubview(summaryPanel())
        root.addArrangedSubview(buttonRow())

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        return contentView
    }

    private func headerView() -> NSView {
        let icon = NSImageView(image: appIcon())
        icon.identifier = NSUserInterfaceItemIdentifier("about.brandIcon")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let title = NSTextField(labelWithString: L10n.tr("app.name"))
        title.identifier = NSUserInterfaceItemIdentifier("about.heading")
        title.font = .systemFont(ofSize: 28, weight: .semibold)

        let versionLabel = NSTextField(labelWithString: L10n.format("about.version", version))
        versionLabel.identifier = NSUserInterfaceItemIdentifier("about.version")
        versionLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        versionLabel.textColor = .secondaryLabelColor

        let tagline = NSTextField(labelWithString: L10n.tr("about.tagline"))
        tagline.identifier = NSUserInterfaceItemIdentifier("about.tagline")
        tagline.font = .systemFont(ofSize: 13, weight: .medium)
        tagline.textColor = .secondaryLabelColor
        tagline.lineBreakMode = .byWordWrapping
        tagline.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let copyStack = NSStackView(views: [title, versionLabel, tagline])
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 5

        let header = NSStackView(views: [icon, copyStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 16
        header.widthAnchor.constraint(greaterThanOrEqualToConstant: 520).isActive = true
        return header
    }

    private func summaryPanel() -> NSView {
        let panel = NSStackView()
        panel.identifier = NSUserInterfaceItemIdentifier("about.summaryPanel")
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 12
        panel.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 8
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor
        panel.layer?.borderColor = NSColor.separatorColor.cgColor
        panel.layer?.borderWidth = 1

        panel.addArrangedSubview(featureRow(
            identifier: "about.feature.eyeGate",
            symbolName: "eye",
            title: L10n.tr("about.eyeGateTitle"),
            body: L10n.tr("about.eyeGateBody")
        ))
        panel.addArrangedSubview(featureRow(
            identifier: "about.feature.bodyBreak",
            symbolName: "figure.walk",
            title: L10n.tr("about.bodyBreakTitle"),
            body: L10n.tr("about.bodyBreakBody")
        ))
        panel.addArrangedSubview(featureRow(
            identifier: "about.feature.compatibility",
            symbolName: "slider.horizontal.3",
            title: L10n.tr("about.compatibilityTitle"),
            body: L10n.tr("about.compatibilityBody")
        ))
        panel.widthAnchor.constraint(equalToConstant: 540).isActive = true
        return panel
    }

    private func featureRow(identifier: String, symbolName: String, title: String, body: String) -> NSView {
        let row = NSStackView()
        row.identifier = NSUserInterfaceItemIdentifier(identifier)
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10

        let icon = NSImageView(image: symbolImage(symbolName, accessibilityDescription: title))
        icon.identifier = NSUserInterfaceItemIdentifier("\(identifier).icon")
        icon.contentTintColor = .secondaryLabelColor
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let bodyLabel = NSTextField(labelWithString: body)
        bodyLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.maximumNumberOfLines = 2
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let copyStack = NSStackView(views: [titleLabel, bodyLabel])
        copyStack.orientation = .vertical
        copyStack.alignment = .leading
        copyStack.spacing = 2
        copyStack.widthAnchor.constraint(equalToConstant: 480).isActive = true

        row.addArrangedSubview(icon)
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
        row.widthAnchor.constraint(equalToConstant: 540).isActive = true
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
            symbolName: "stethoscope",
            action: #selector(openDebugPressed),
            toolTip: L10n.tr("about.debugHelp")
        )
        configureButton(
            closeButton,
            identifier: "about.closeButton",
            title: L10n.tr("about.close"),
            symbolName: "xmark.circle",
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

    private func appIcon() -> NSImage {
        if let appIcon = NSApp.applicationIconImage {
            return appIcon
        }
        return RestGateIcon.fallbackAppImage(size: 72, accessibilityDescription: L10n.tr("app.name"))
    }

    private func symbolImage(_ name: String, accessibilityDescription: String? = nil) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription) ?? NSImage()
    }
}
