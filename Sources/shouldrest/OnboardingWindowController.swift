import AppKit
import ShouldRestCore

private enum OnboardingFeatureIcon {
    case restGate
    case systemSymbol(String)
}

@MainActor
final class OnboardingWindowController: NSWindowController {
    private enum Metrics {
        static let width: CGFloat = 640
        static let contentWidth: CGFloat = 560
    }

    private let onStart: () -> Void
    private let onOpenPreferences: () -> Void
    private let onLearnMore: () -> Void
    private let rhythmIcon = NSImageView()
    private let rhythmRationale = NSTextField(labelWithString: "")
    private let rhythmRationaleIcon = NSImageView()
    private let rhythmMetricEyeInterval = NSTextField(labelWithString: "")
    private let rhythmMetricEyeDuration = NSTextField(labelWithString: "")
    private let rhythmMetricBodyInterval = NSTextField(labelWithString: "")
    private let rhythmMetricBodyDuration = NSTextField(labelWithString: "")
    private var startButton: NSButton?

    init(
        onStart: @escaping () -> Void,
        onOpenPreferences: @escaping () -> Void,
        onLearnMore: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onOpenPreferences = onOpenPreferences
        self.onLearnMore = onLearnMore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.width, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("onboarding.title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        super.init(window: window)
        buildContent()
        window.center()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContent() {
        guard let window, let contentView = window.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 44, left: 40, bottom: 28, right: 40)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let hero = heroView()
        let rhythm = rhythmPanel()
        let features = featureList()
        let buttons = buttonRow()
        stack.addArrangedSubview(hero)
        stack.addArrangedSubview(rhythm)
        stack.addArrangedSubview(features)
        stack.addArrangedSubview(buttons)
        stack.setCustomSpacing(26, after: hero)
        stack.setCustomSpacing(24, after: features)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        stack.layoutSubtreeIfNeeded()
        let height = max(540, ceil(stack.fittingSize.height))
        window.setContentSize(NSSize(width: Metrics.width, height: height))
    }

    private func heroView() -> NSView {
        let icon = NSImageView(image: RestGateIcon.appIcon(size: 84, accessibilityDescription: L10n.tr("app.name")))
        icon.identifier = NSUserInterfaceItemIdentifier("onboarding.brandIcon")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 84).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 84).isActive = true

        let title = centeredLabel(
            L10n.tr("onboarding.heading"),
            identifier: "onboarding.heading",
            font: .systemFont(ofSize: 26, weight: .bold),
            color: .labelColor
        )
        let subtitle = centeredLabel(
            L10n.tr("onboarding.subtitle"),
            identifier: "onboarding.subtitle",
            font: .systemFont(ofSize: 14, weight: .medium),
            color: .secondaryLabelColor
        )
        let body = centeredLabel(
            L10n.tr("onboarding.body"),
            identifier: "onboarding.body",
            font: .systemFont(ofSize: 13),
            color: .secondaryLabelColor
        )

        let hero = NSStackView(views: [icon, title, subtitle, body])
        hero.orientation = .vertical
        hero.alignment = .centerX
        hero.spacing = 6
        hero.setCustomSpacing(14, after: icon)
        return hero
    }

    private func rhythmPanel() -> NSView {
        let panel = SurfaceStackView(style: .card)
        panel.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmPanel")
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 12
        panel.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        panel.widthAnchor.constraint(equalToConstant: Metrics.contentWidth).isActive = true

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 7

        rhythmIcon.image = symbolImage("timer", accessibilityDescription: rhythmAccessibilityTitle())
        rhythmIcon.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmIcon")
        rhythmIcon.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
        rhythmIcon.contentTintColor = .controlAccentColor
        rhythmIcon.setAccessibilityLabel(L10n.tr("onboarding.rhythmTitle"))
        rhythmIcon.setAccessibilityHelp(rhythmDescriptionText)
        rhythmIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        rhythmIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        titleRow.addArrangedSubview(rhythmIcon)

        let title = NSTextField(labelWithString: L10n.tr("onboarding.rhythmTitle"))
        title.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmTitle")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        titleRow.addArrangedSubview(title)

        configureRhythmRationale()
        updateRhythmMetricValues()

        let metrics = rhythmMetricsView()
        panel.addArrangedSubview(titleRow)
        panel.addArrangedSubview(metrics)
        panel.addArrangedSubview(rhythmRationaleRow())
        metrics.widthAnchor.constraint(equalTo: panel.widthAnchor, constant: -32).isActive = true
        return panel
    }

    private func featureList() -> NSView {
        let panel = SurfaceStackView(style: .card)
        panel.identifier = NSUserInterfaceItemIdentifier("onboarding.featureList")
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 14
        panel.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        panel.widthAnchor.constraint(equalToConstant: Metrics.contentWidth).isActive = true

        panel.addArrangedSubview(featureRow(
            identifier: "onboarding.feature.eye",
            icon: .restGate,
            title: L10n.tr("onboarding.eyeFeatureTitle"),
            body: L10n.tr("onboarding.eyeFeatureBody")
        ))
        panel.addArrangedSubview(featureRow(
            identifier: "onboarding.feature.emergency",
            icon: .systemSymbol("exclamationmark.triangle"),
            title: L10n.tr("onboarding.emergencyFeatureTitle"),
            body: L10n.tr("onboarding.emergencyFeatureBody")
        ))
        panel.addArrangedSubview(featureRow(
            identifier: "onboarding.feature.body",
            icon: .systemSymbol("figure.walk"),
            title: L10n.tr("onboarding.bodyFeatureTitle"),
            body: L10n.tr("onboarding.bodyFeatureBody")
        ))
        return panel
    }

    private func featureRow(identifier: String, icon: OnboardingFeatureIcon, title: String, body: String) -> NSView {
        let row = NSStackView()
        row.identifier = NSUserInterfaceItemIdentifier(identifier)
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12

        let imageView = NSImageView()
        switch icon {
        case .restGate:
            imageView.image = RestGateIcon.glyphImage(pointSize: 18, accessibilityDescription: title)
            imageView.identifier = NSUserInterfaceItemIdentifier("\(identifier).restGateIcon")
        case let .systemSymbol(symbolName):
            imageView.image = symbolImage(symbolName, accessibilityDescription: title)
            imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            imageView.identifier = NSUserInterfaceItemIdentifier("\(identifier).systemIcon")
        }
        row.addArrangedSubview(iconTile(imageView))

        let copy = NSStackView()
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 2

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.isSelectable = false
        bodyLabel.preferredMaxLayoutWidth = Metrics.contentWidth - 32 - 30 - 12
        bodyLabel.widthAnchor.constraint(equalToConstant: Metrics.contentWidth - 32 - 30 - 12).isActive = true

        copy.addArrangedSubview(titleLabel)
        copy.addArrangedSubview(bodyLabel)
        row.addArrangedSubview(copy)
        return row
    }

    /// A tinted rounded tile behind a feature glyph.
    private func iconTile(_ imageView: NSImageView) -> NSView {
        let tile = SurfaceView(style: SurfaceStyle(
            fill: { NSColor.controlAccentColor.withAlphaComponent($0 ? 0.22 : 0.13) },
            stroke: { _ in nil },
            cornerRadius: 8
        ))
        tile.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentTintColor = .controlAccentColor
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(imageView)
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 30),
            tile.heightAnchor.constraint(equalToConstant: 30),
            imageView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])
        return tile
    }

    private func configureRhythmRationale() {
        let rationale = L10n.tr("onboarding.rhythmRationale")
        rhythmRationale.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmRationale")
        rhythmRationale.stringValue = rationale
        rhythmRationale.font = .systemFont(ofSize: 12)
        rhythmRationale.textColor = .secondaryLabelColor
        rhythmRationale.lineBreakMode = .byWordWrapping
        rhythmRationale.maximumNumberOfLines = 2
        rhythmRationale.preferredMaxLayoutWidth = Metrics.contentWidth - 32 - 22
        rhythmRationale.widthAnchor.constraint(lessThanOrEqualToConstant: Metrics.contentWidth - 32 - 22).isActive = true
        rhythmRationale.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rhythmRationale.setContentCompressionResistancePriority(.required, for: .vertical)
        rhythmRationale.toolTip = rationale
        rhythmRationale.setAccessibilityLabel(rationale)
        rhythmRationale.setAccessibilityHelp(rationale)

        rhythmRationaleIcon.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmRationaleIcon")
        rhythmRationaleIcon.image = symbolImage("checkmark.seal", accessibilityDescription: rationale)
        rhythmRationaleIcon.symbolConfiguration = .init(pointSize: 12, weight: .semibold)
        rhythmRationaleIcon.contentTintColor = .controlAccentColor
        rhythmRationaleIcon.setAccessibilityLabel(rationale)
        rhythmRationaleIcon.setAccessibilityHelp(rationale)
        rhythmRationaleIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        rhythmRationaleIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true
    }

    private func rhythmRationaleRow() -> NSView {
        let row = NSStackView()
        row.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmRationaleRow")
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 6
        row.addArrangedSubview(rhythmRationaleIcon)
        row.addArrangedSubview(rhythmRationale)
        return row
    }

    private func rhythmMetricsView() -> NSView {
        let row = NSStackView()
        row.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmMetricRow")
        row.orientation = .horizontal
        row.alignment = .top
        row.distribution = .fillEqually
        row.spacing = 8
        // The tiles already show each value; one sentence keeps VoiceOver brief.
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.group)
        row.setAccessibilityLabel(rhythmDescriptionText)
        row.toolTip = rhythmDescriptionText

        row.addArrangedSubview(rhythmMetricColumn(
            identifier: "onboarding.metric.eyeInterval",
            symbolName: "repeat",
            title: L10n.tr("onboarding.metric.eyeInterval"),
            valueLabel: rhythmMetricEyeInterval
        ))
        row.addArrangedSubview(rhythmMetricColumn(
            identifier: "onboarding.metric.eyeDuration",
            symbolName: "eye",
            title: L10n.tr("onboarding.metric.eyeDuration"),
            valueLabel: rhythmMetricEyeDuration
        ))
        row.addArrangedSubview(rhythmMetricColumn(
            identifier: "onboarding.metric.bodyInterval",
            symbolName: "arrow.triangle.2.circlepath",
            title: L10n.tr("onboarding.metric.bodyInterval"),
            valueLabel: rhythmMetricBodyInterval
        ))
        row.addArrangedSubview(rhythmMetricColumn(
            identifier: "onboarding.metric.bodyDuration",
            symbolName: "figure.walk",
            title: L10n.tr("onboarding.metric.bodyDuration"),
            valueLabel: rhythmMetricBodyDuration
        ))
        return row
    }

    private func rhythmMetricColumn(
        identifier: String,
        symbolName: String,
        title: String,
        valueLabel: NSTextField
    ) -> NSView {
        let column = SurfaceStackView(style: .inset)
        column.identifier = NSUserInterfaceItemIdentifier(identifier)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        column.edgeInsets = NSEdgeInsets(top: 9, left: 10, bottom: 9, right: 10)
        column.setContentCompressionResistancePriority(.required, for: .vertical)

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 4

        let icon = NSImageView(image: symbolImage(symbolName, accessibilityDescription: title))
        icon.identifier = NSUserInterfaceItemIdentifier("\(identifier).icon")
        icon.symbolConfiguration = .init(pointSize: 10, weight: .semibold)
        icon.contentTintColor = .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 13).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 13).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.identifier = NSUserInterfaceItemIdentifier("\(identifier).title")
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        titleRow.addArrangedSubview(icon)
        titleRow.addArrangedSubview(titleLabel)

        valueLabel.identifier = NSUserInterfaceItemIdentifier("\(identifier).value")
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = .labelColor
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.maximumNumberOfLines = 1

        column.addArrangedSubview(titleRow)
        column.addArrangedSubview(valueLabel)
        return column
    }

    private func buttonRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: Metrics.contentWidth).isActive = true

        let learnMoreButton = onboardingButton(
            title: L10n.tr("onboarding.learnMore"),
            identifier: "onboarding.aboutButton",
            symbolName: "info.circle",
            help: L10n.tr("onboarding.learnMoreHelp"),
            action: #selector(learnMore)
        )
        let preferencesButton = onboardingButton(
            title: L10n.tr("onboarding.preferences"),
            identifier: "onboarding.preferencesButton",
            symbolName: "slider.horizontal.3",
            help: L10n.tr("onboarding.preferencesHelp"),
            action: #selector(openPreferences)
        )
        let startButton = onboardingButton(
            title: L10n.tr("onboarding.useRecommended"),
            identifier: "onboarding.startButton",
            symbolName: "checkmark",
            help: L10n.tr("onboarding.startHelp"),
            action: #selector(start)
        )
        startButton.keyEquivalent = "\r"
        self.startButton = startButton

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(learnMoreButton)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(preferencesButton)
        row.addArrangedSubview(startButton)
        return row
    }

    private func onboardingButton(title: String, identifier: String, symbolName: String, help: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.image = symbolImage(symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.toolTip = help
        button.setAccessibilityLabel(title)
        button.setAccessibilityHelp(help)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    private func centeredLabel(_ text: String, identifier: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.identifier = NSUserInterfaceItemIdentifier(identifier)
        label.font = font
        label.textColor = color
        label.alignment = .center
        label.isSelectable = false
        label.preferredMaxLayoutWidth = Metrics.contentWidth
        label.widthAnchor.constraint(lessThanOrEqualToConstant: Metrics.contentWidth).isActive = true
        return label
    }

    private var rhythmDescriptionText: String {
        L10n.format(
            "onboarding.rhythmDescription",
            defaultEyeIntervalMinutes,
            defaultEyeDurationSeconds,
            defaultBodyIntervalMinutes,
            defaultBodyDurationMinutes
        )
    }

    private var defaultEyeIntervalMinutes: Int {
        Int(RestSettings.defaults.eyeGate.interval / 60)
    }

    private var defaultEyeDurationSeconds: Int {
        Int(RestSettings.defaults.eyeGate.duration)
    }

    private var defaultBodyIntervalMinutes: Int {
        Int(RestSettings.defaults.bodyBreak.interval / 60)
    }

    private var defaultBodyDurationMinutes: Int {
        Int(RestSettings.defaults.bodyBreak.duration / 60)
    }

    private func updateRhythmMetricValues() {
        rhythmMetricEyeInterval.stringValue = L10n.format(
            "onboarding.metric.eyeIntervalValue",
            defaultEyeIntervalMinutes
        )
        rhythmMetricEyeDuration.stringValue = L10n.format(
            "onboarding.metric.eyeDurationValue",
            defaultEyeDurationSeconds
        )
        rhythmMetricBodyInterval.stringValue = L10n.format(
            "onboarding.metric.bodyIntervalValue",
            defaultBodyIntervalMinutes
        )
        rhythmMetricBodyDuration.stringValue = L10n.format(
            "onboarding.metric.bodyDurationValue",
            defaultBodyDurationMinutes
        )
        updateRhythmMetricAccessibility()
    }

    private func updateRhythmMetricAccessibility() {
        updateRhythmMetricAccessibility(
            title: L10n.tr("onboarding.metric.eyeInterval"),
            valueLabel: rhythmMetricEyeInterval
        )
        updateRhythmMetricAccessibility(
            title: L10n.tr("onboarding.metric.eyeDuration"),
            valueLabel: rhythmMetricEyeDuration
        )
        updateRhythmMetricAccessibility(
            title: L10n.tr("onboarding.metric.bodyInterval"),
            valueLabel: rhythmMetricBodyInterval
        )
        updateRhythmMetricAccessibility(
            title: L10n.tr("onboarding.metric.bodyDuration"),
            valueLabel: rhythmMetricBodyDuration
        )
    }

    private func updateRhythmMetricAccessibility(title: String, valueLabel: NSTextField) {
        let help = "\(title): \(valueLabel.stringValue)"
        valueLabel.toolTip = help
        valueLabel.setAccessibilityLabel(help)
        valueLabel.setAccessibilityHelp(help)
    }

    private func rhythmAccessibilityTitle() -> String {
        "\(L10n.tr("onboarding.rhythmTitle")): \(rhythmDescriptionText)"
    }

    private func symbolImage(_ symbolName: String, accessibilityDescription: String?) -> NSImage {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
            ?? NSImage(systemSymbolName: "circle", accessibilityDescription: accessibilityDescription)
            ?? NSImage(size: NSSize(width: 16, height: 16))
    }

    @objc private func start() {
        onStart()
        close()
    }

    @objc private func openPreferences() {
        onOpenPreferences()
        close()
    }

    @objc private func learnMore() {
        onLearnMore()
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
