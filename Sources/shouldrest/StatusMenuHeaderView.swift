import AppKit

@MainActor
final class StatusMenuHeaderView: NSView {
    private enum Metrics {
        static let width: CGFloat = 318
        static let height: CGFloat = 82
        static let horizontalInset: CGFloat = 12
        static let iconSize: CGFloat = 30
    }

    init(content: MenuStatusPresenter.HeaderContent) {
        super.init(frame: NSRect(x: 0, y: 0, width: Metrics.width, height: Metrics.height))
        identifier = NSUserInterfaceItemIdentifier("statusMenu.header")
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: Metrics.width).isActive = true
        heightAnchor.constraint(equalToConstant: Metrics.height).isActive = true

        let iconView = NSImageView(image: image(for: content.icon))
        iconView.identifier = NSUserInterfaceItemIdentifier("statusMenu.headerIcon")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: Metrics.iconSize).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: Metrics.iconSize).isActive = true

        let titleLabel = label(
            content.title,
            identifier: "statusMenu.headerTitle",
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor
        )
        let primaryLabel = label(
            content.primary,
            identifier: "statusMenu.headerPrimary",
            font: .systemFont(ofSize: 12, weight: .regular),
            color: .secondaryLabelColor
        )
        let secondaryLabel = label(
            content.secondary ?? "",
            identifier: "statusMenu.headerSecondary",
            font: .systemFont(ofSize: 11, weight: .regular),
            color: .tertiaryLabelColor,
            lineBreakMode: .byWordWrapping,
            maximumNumberOfLines: 2
        )
        secondaryLabel.isHidden = content.secondary == nil

        let textStack = NSStackView(views: [titleLabel, primaryLabel, secondaryLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let badgeLabel = badge(content.healthBadge)
        badgeLabel.identifier = NSUserInterfaceItemIdentifier("statusMenu.headerBadge")
        badgeLabel.isHidden = content.healthBadge == nil

        let row = NSStackView(views: [iconView, textStack, badgeLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(
            top: 9,
            left: Metrics.horizontalInset,
            bottom: 9,
            right: Metrics.horizontalInset
        )
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            textStack.widthAnchor.constraint(lessThanOrEqualToConstant: 220)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func image(for icon: MenuStatusPresenter.MenuBarIcon) -> NSImage {
        switch icon {
        case .restGate:
            return RestGateIcon.fallbackAppImage(size: Metrics.iconSize, accessibilityDescription: L10n.tr("app.name"))
        case .systemSymbol(let symbolName):
            let configuration = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: L10n.tr("app.name"))?
                .withSymbolConfiguration(configuration)
                ?? NSImage(systemSymbolName: "circle", accessibilityDescription: L10n.tr("app.name"))
                ?? NSImage(size: NSSize(width: Metrics.iconSize, height: Metrics.iconSize))
            image.isTemplate = true
            return image
        }
    }

    private func label(
        _ text: String,
        identifier: String,
        font: NSFont,
        color: NSColor,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        maximumNumberOfLines: Int = 1
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.identifier = NSUserInterfaceItemIdentifier(identifier)
        label.font = font
        label.textColor = color
        label.lineBreakMode = lineBreakMode
        label.maximumNumberOfLines = maximumNumberOfLines
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func badge(_ text: String?) -> NSTextField {
        let badge = NSTextField(labelWithString: text ?? "")
        badge.font = .systemFont(ofSize: 11, weight: .medium)
        badge.textColor = .systemOrange
        badge.alignment = .center
        badge.lineBreakMode = .byTruncatingTail
        badge.maximumNumberOfLines = 1
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 6
        badge.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.12).cgColor
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 62).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return badge
    }
}
