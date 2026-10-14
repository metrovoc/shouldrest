import AppKit

@MainActor
final class StatusMenuHeaderView: NSView {
    private enum Metrics {
        static let width: CGFloat = 300
        static let horizontalInset: CGFloat = 14
        static let verticalInset: CGFloat = 10
        static let tileSize: CGFloat = 34
        static let glyphSize: CGFloat = 22
        static let progressHeight: CGFloat = 4
        static let textWidth: CGFloat = width - horizontalInset * 2 - tileSize - 10
    }

    private let tile = SurfaceView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let primaryLabel = NSTextField(labelWithString: "")
    private let secondaryLabel = NSTextField(labelWithString: "")
    private let badgeContainer = SurfaceView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private let progressView = StatusMenuProgressView()
    private var content: MenuStatusPresenter.HeaderContent

    init(content: MenuStatusPresenter.HeaderContent) {
        self.content = content
        super.init(frame: NSRect(x: 0, y: 0, width: Metrics.width, height: 60))
        identifier = NSUserInterfaceItemIdentifier("statusMenu.header")
        buildLayout()
        update(content: content)
        let fittingHeight = ceil(fittingSize.height)
        frame.size = NSSize(width: Metrics.width, height: fittingHeight)
        widthAnchor.constraint(equalToConstant: Metrics.width).isActive = true
        heightAnchor.constraint(equalToConstant: fittingHeight).isActive = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    var progressForTesting: Double? {
        progressView.isHidden ? nil : progressView.progress
    }

    /// Refreshes the header in place, so an open menu keeps counting down.
    func update(content: MenuStatusPresenter.HeaderContent) {
        self.content = content
        let summary = Self.accessibilitySummary(for: content)
        toolTip = summary
        setAccessibilityLabel(summary)
        setAccessibilityHelp(summary)

        let tint = tintColor(for: content)
        tile.surfaceStyle = SurfaceStyle(
            fill: { tint.withAlphaComponent($0 ? 0.22 : 0.14) },
            stroke: { _ in nil },
            cornerRadius: 9
        )
        iconView.image = image(for: content.icon)
        iconView.contentTintColor = tint
        let appName = L10n.tr("app.name")
        iconView.toolTip = appName
        iconView.setAccessibilityLabel(appName)
        iconView.setAccessibilityHelp(summary)

        setText(content.title, on: titleLabel)
        setText(content.primary, on: primaryLabel)
        setOptionalText(content.secondary, on: secondaryLabel)
        setOptionalText(content.healthBadge, on: badgeLabel)
        badgeContainer.isHidden = badgeLabel.isHidden
        let badgeWidth = badgeContainer.isHidden ? 0 : ceil(badgeLabel.intrinsicContentSize.width) + 14 + 8
        titleLabel.preferredMaxLayoutWidth = Metrics.textWidth - badgeWidth

        progressView.isHidden = content.progress == nil
        progressView.progress = content.progress ?? 0
        progressView.tint = tint
    }

    private func buildLayout() {
        translatesAutoresizingMaskIntoConstraints = false

        tile.translatesAutoresizingMaskIntoConstraints = false
        iconView.identifier = NSUserInterfaceItemIdentifier("statusMenu.headerIcon")
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(iconView)

        configure(titleLabel, identifier: "statusMenu.headerTitle", font: .systemFont(ofSize: 13, weight: .semibold), color: .labelColor)
        configure(primaryLabel, identifier: "statusMenu.headerPrimary", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        configure(secondaryLabel, identifier: "statusMenu.headerSecondary", font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
        for label in [titleLabel, primaryLabel, secondaryLabel] {
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 2
            label.cell?.truncatesLastVisibleLine = true
            label.preferredMaxLayoutWidth = Metrics.textWidth
        }

        badgeLabel.identifier = NSUserInterfaceItemIdentifier("statusMenu.headerBadge")
        badgeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textColor = .systemOrange
        badgeLabel.alignment = .center
        badgeLabel.lineBreakMode = .byClipping
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.surfaceStyle = SurfaceStyle(
            fill: { NSColor.systemOrange.withAlphaComponent($0 ? 0.2 : 0.13) },
            stroke: { _ in nil },
            cornerRadius: 9
        )
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)
        badgeContainer.setContentHuggingPriority(.required, for: .horizontal)
        badgeContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        let titleRow = NSStackView(views: [titleLabel, badgeContainer])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8
        titleRow.distribution = .fill
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [titleRow, primaryLabel, secondaryLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.setCustomSpacing(4, after: titleRow)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        progressView.identifier = NSUserInterfaceItemIdentifier("statusMenu.headerProgress")
        progressView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(tile)
        addSubview(textStack)
        addSubview(progressView)

        let textLeading = Metrics.horizontalInset + Metrics.tileSize + 10
        let progressTop = progressView.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 8)
        NSLayoutConstraint.activate([
            tile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.horizontalInset),
            tile.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.verticalInset),
            tile.widthAnchor.constraint(equalToConstant: Metrics.tileSize),
            tile.heightAnchor.constraint(equalToConstant: Metrics.tileSize),
            iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Metrics.glyphSize),
            iconView.heightAnchor.constraint(equalToConstant: Metrics.glyphSize),

            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textLeading),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.horizontalInset),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.verticalInset - 1),
            titleRow.widthAnchor.constraint(equalTo: textStack.widthAnchor),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Metrics.verticalInset),
            tile.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Metrics.verticalInset),

            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 7),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -7),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            badgeContainer.heightAnchor.constraint(equalToConstant: 18),

            progressTop,
            progressView.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: textStack.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: Metrics.progressHeight),
            progressView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Metrics.verticalInset - 2)
        ])
    }

    private static func accessibilitySummary(for content: MenuStatusPresenter.HeaderContent) -> String {
        [content.title, content.primary, content.secondary, content.healthBadge]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    private func configure(_ label: NSTextField, identifier: String, font: NSFont, color: NSColor) {
        label.identifier = NSUserInterfaceItemIdentifier(identifier)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func setText(_ text: String, on label: NSTextField) {
        let readableText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        label.stringValue = text
        label.isHidden = readableText.isEmpty
        label.toolTip = readableText.isEmpty ? nil : text
        label.setAccessibilityLabel(readableText.isEmpty ? nil : text)
        label.setAccessibilityHelp(readableText.isEmpty ? nil : text)
    }

    private func setOptionalText(_ text: String?, on label: NSTextField) {
        let readableText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let readableText, !readableText.isEmpty else {
            label.stringValue = ""
            label.isHidden = true
            label.toolTip = nil
            label.setAccessibilityLabel(nil)
            label.setAccessibilityHelp(nil)
            return
        }

        label.stringValue = readableText
        label.isHidden = false
        label.toolTip = readableText
        label.setAccessibilityLabel(readableText)
        label.setAccessibilityHelp(readableText)
    }

    private func tintColor(for content: MenuStatusPresenter.HeaderContent) -> NSColor {
        switch content.tone {
        case .active:
            return .controlAccentColor
        case .onHold:
            return .secondaryLabelColor
        }
    }

    private func image(for icon: MenuStatusPresenter.MenuBarIcon) -> NSImage {
        let appName = L10n.tr("app.name")
        switch icon.glyph {
        case .eye where icon.badge == .paused:
            return symbolImage("pause.fill", accessibilityDescription: appName)
        case .eye:
            return RestGateIcon.glyphImage(pointSize: Metrics.glyphSize, accessibilityDescription: appName)
        case .bodyBreak:
            return symbolImage("figure.walk", accessibilityDescription: appName)
        }
    }

    private func symbolImage(_ symbolName: String, accessibilityDescription: String) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
            ?? RestGateIcon.glyphImage(pointSize: Metrics.glyphSize, accessibilityDescription: accessibilityDescription)
        image.isTemplate = true
        return image
    }
}

/// A slim capsule showing how much of the current interval or rest has elapsed.
@MainActor
final class StatusMenuProgressView: NSView {
    var progress: Double = 0 {
        didSet { needsDisplay = true }
    }

    var tint: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        let clamped = min(1, max(0, progress))
        guard clamped > 0 else { return }
        let width = max(bounds.height, bounds.width * clamped)
        tint.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height),
            xRadius: radius,
            yRadius: radius
        ).fill()
    }
}
