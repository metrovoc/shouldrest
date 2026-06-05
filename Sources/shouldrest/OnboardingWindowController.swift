import AppKit
import Foundation

private enum OnboardingFeatureIcon {
    case restGate
    case systemSymbol(String)
}

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let onUsePreset: (RestRhythmPreset) -> Void
    private let onOpenPreferences: (RestRhythmPreset) -> Void
    private let onLearnMore: () -> Void
    private let rhythmPresetControl = NSSegmentedControl()
    private let rhythmPresetIcon = NSImageView()
    private let rhythmPresetDescription = NSTextField(labelWithString: "")
    private let rhythmPresetRationale = NSTextField(labelWithString: "")
    private let rhythmPresetRationaleIcon = NSImageView()
    private let rhythmMetricEyeInterval = NSTextField(labelWithString: "")
    private let rhythmMetricEyeDuration = NSTextField(labelWithString: "")
    private let rhythmMetricBodyAfter = NSTextField(labelWithString: "")
    private let rhythmMetricBodyDuration = NSTextField(labelWithString: "")
    private var useSelectedButton: NSButton?
    private var selectedRhythmPreset: RestRhythmPreset = .firstRunDefault

    init(
        onUsePreset: @escaping (RestRhythmPreset) -> Void,
        onOpenPreferences: @escaping (RestRhythmPreset) -> Void,
        onLearnMore: @escaping () -> Void
    ) {
        self.onUsePreset = onUsePreset
        self.onOpenPreferences = onOpenPreferences
        self.onLearnMore = onLearnMore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 590),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("onboarding.title")
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.center()
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 30, bottom: 24, right: 30)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        stack.addArrangedSubview(heroView())
        stack.addArrangedSubview(featureList())
        stack.addArrangedSubview(rhythmPresetPanel())
        stack.addArrangedSubview(buttonRow())

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func heroView() -> NSView {
        let hero = NSStackView()
        hero.orientation = .horizontal
        hero.alignment = .centerY
        hero.spacing = 18

        let icon = NSImageView(image: brandImage())
        icon.identifier = NSUserInterfaceItemIdentifier("onboarding.brandIcon")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        hero.addArrangedSubview(icon)

        let copy = NSStackView()
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 6

        let title = NSTextField(labelWithString: L10n.tr("onboarding.heading"))
        title.identifier = NSUserInterfaceItemIdentifier("onboarding.heading")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.lineBreakMode = .byWordWrapping
        title.maximumNumberOfLines = 2

        let subtitle = NSTextField(labelWithString: L10n.tr("onboarding.subtitle"))
        subtitle.identifier = NSUserInterfaceItemIdentifier("onboarding.subtitle")
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 2

        let body = NSTextField(labelWithString: L10n.tr("onboarding.body"))
        body.identifier = NSUserInterfaceItemIdentifier("onboarding.body")
        body.font = .systemFont(ofSize: 13, weight: .regular)
        body.textColor = .secondaryLabelColor
        body.lineBreakMode = .byWordWrapping
        body.maximumNumberOfLines = 3

        [title, subtitle, body].forEach { label in
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 520).isActive = true
            copy.addArrangedSubview(label)
        }
        hero.addArrangedSubview(copy)
        return hero
    }

    private func featureList() -> NSView {
        let panel = NSView()
        panel.identifier = NSUserInterfaceItemIdentifier("onboarding.featureList")
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 8
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.8).cgColor
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor
        panel.setContentHuggingPriority(.required, for: .vertical)
        panel.setContentCompressionResistancePriority(.required, for: .vertical)

        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 14
        list.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(list)

        list.addArrangedSubview(featureRow(
            identifier: "onboarding.feature.eye",
            icon: .restGate,
            title: L10n.tr("onboarding.eyeFeatureTitle"),
            body: L10n.tr("onboarding.eyeFeatureBody")
        ))
        list.addArrangedSubview(featureRow(
            identifier: "onboarding.feature.emergency",
            icon: .systemSymbol("exclamationmark.triangle"),
            title: L10n.tr("onboarding.emergencyFeatureTitle"),
            body: L10n.tr("onboarding.emergencyFeatureBody")
        ))
        list.addArrangedSubview(featureRow(
            identifier: "onboarding.feature.body",
            icon: .systemSymbol("figure.walk"),
            title: L10n.tr("onboarding.bodyFeatureTitle"),
            body: L10n.tr("onboarding.bodyFeatureBody")
        ))

        NSLayoutConstraint.activate([
            list.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            list.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            list.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            list.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14)
        ])
        panel.widthAnchor.constraint(equalToConstant: 620).isActive = true
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
            imageView.image = RestGateIcon.menuBarImage(accessibilityDescription: title)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.identifier = NSUserInterfaceItemIdentifier("\(identifier).restGateIcon")
        case let .systemSymbol(symbolName):
            imageView.image = symbolImage(symbolName, accessibilityDescription: title)
            imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            imageView.identifier = NSUserInterfaceItemIdentifier("\(identifier).systemIcon")
        }
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        row.addArrangedSubview(imageView)

        let copy = NSStackView()
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 3

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let bodyLabel = NSTextField(labelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.maximumNumberOfLines = 2
        bodyLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 540).isActive = true

        copy.addArrangedSubview(titleLabel)
        copy.addArrangedSubview(bodyLabel)
        row.addArrangedSubview(copy)
        return row
    }

    private func rhythmPresetPanel() -> NSView {
        let panel = NSView()
        panel.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmPresetPanel")
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 8
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        panel.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.07).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        rhythmPresetIcon.image = symbolImage(
            "timer",
            accessibilityDescription: rhythmPresetAccessibilityTitle()
        )
        rhythmPresetIcon.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmPresetIcon")
        rhythmPresetIcon.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        rhythmPresetIcon.contentTintColor = .secondaryLabelColor
        rhythmPresetIcon.setAccessibilityLabel(L10n.tr("onboarding.rhythmTitle"))
        rhythmPresetIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        rhythmPresetIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        titleRow.addArrangedSubview(rhythmPresetIcon)

        let title = NSTextField(labelWithString: L10n.tr("onboarding.rhythmTitle"))
        title.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmTitle")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        titleRow.addArrangedSubview(title)

        configureRhythmPresetControl()
        configureRhythmPresetDescription()

        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(rhythmPresetControl)
        stack.addArrangedSubview(rhythmPresetDescription)
        stack.addArrangedSubview(rhythmPresetRationaleRow())
        stack.addArrangedSubview(rhythmMetricsView())

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12)
        ])
        panel.widthAnchor.constraint(equalToConstant: 620).isActive = true
        return panel
    }

    private func rhythmMetricsView() -> NSView {
        let row = NSStackView()
        row.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmMetricRow")
        row.orientation = .horizontal
        row.alignment = .top
        row.distribution = .fillEqually
        row.spacing = 12
        row.widthAnchor.constraint(equalToConstant: 592).isActive = true

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
            identifier: "onboarding.metric.bodyAfter",
            symbolName: "arrow.triangle.2.circlepath",
            title: L10n.tr("onboarding.metric.bodyAfter"),
            valueLabel: rhythmMetricBodyAfter
        ))
        row.addArrangedSubview(rhythmMetricColumn(
            identifier: "onboarding.metric.bodyDuration",
            symbolName: "figure.walk",
            title: L10n.tr("onboarding.metric.bodyDuration"),
            valueLabel: rhythmMetricBodyDuration
        ))

        updateRhythmPresetSelectionUI()
        return row
    }

    private func rhythmMetricColumn(
        identifier: String,
        symbolName: String,
        title: String,
        valueLabel: NSTextField
    ) -> NSView {
        let column = NSStackView()
        column.identifier = NSUserInterfaceItemIdentifier(identifier)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        column.setContentCompressionResistancePriority(.required, for: .vertical)

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 5

        let icon = NSImageView(image: symbolImage(symbolName, accessibilityDescription: title))
        icon.identifier = NSUserInterfaceItemIdentifier("\(identifier).icon")
        icon.symbolConfiguration = .init(pointSize: 11, weight: .medium)
        icon.contentTintColor = .tertiaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 14).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.identifier = NSUserInterfaceItemIdentifier("\(identifier).title")
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        titleRow.addArrangedSubview(icon)
        titleRow.addArrangedSubview(titleLabel)

        valueLabel.identifier = NSUserInterfaceItemIdentifier("\(identifier).value")
        valueLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = .labelColor
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.maximumNumberOfLines = 1

        column.addArrangedSubview(titleRow)
        column.addArrangedSubview(valueLabel)
        return column
    }

    private func configureRhythmPresetControl() {
        rhythmPresetControl.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmPresetControl")
        rhythmPresetControl.segmentCount = RestRhythmPreset.allCases.count
        rhythmPresetControl.segmentStyle = .rounded
        rhythmPresetControl.trackingMode = .selectOne
        rhythmPresetControl.selectedSegment = selectedRhythmPreset.rawValue
        rhythmPresetControl.target = self
        rhythmPresetControl.action = #selector(rhythmPresetChanged(_:))
        rhythmPresetControl.setAccessibilityLabel(L10n.tr("onboarding.rhythmTitle"))
        rhythmPresetControl.setContentHuggingPriority(.required, for: .horizontal)
        rhythmPresetControl.setContentCompressionResistancePriority(.required, for: .horizontal)

        for preset in RestRhythmPreset.allCases {
            rhythmPresetControl.setLabel(preset.title, forSegment: preset.rawValue)
            rhythmPresetControl.setImage(
                rhythmPresetSegmentImage(for: preset),
                forSegment: preset.rawValue
            )
            rhythmPresetControl.setWidth(176, forSegment: preset.rawValue)
            rhythmPresetControl.setToolTip(preset.help, forSegment: preset.rawValue)
        }
    }

    private func configureRhythmPresetDescription() {
        rhythmPresetDescription.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmPresetDescription")
        rhythmPresetDescription.font = .systemFont(ofSize: 12, weight: .regular)
        rhythmPresetDescription.textColor = .secondaryLabelColor
        rhythmPresetDescription.lineBreakMode = .byWordWrapping
        rhythmPresetDescription.maximumNumberOfLines = 2
        rhythmPresetDescription.widthAnchor.constraint(lessThanOrEqualToConstant: 560).isActive = true
        updateRhythmPresetSelectionUI()
    }

    private func rhythmPresetRationaleRow() -> NSView {
        let row = NSStackView()
        row.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmPresetRationaleRow")
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 6

        rhythmPresetRationaleIcon.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmPresetRationaleIcon")
        rhythmPresetRationaleIcon.symbolConfiguration = .init(pointSize: 12, weight: .semibold)
        rhythmPresetRationaleIcon.contentTintColor = .controlAccentColor
        rhythmPresetRationaleIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        rhythmPresetRationaleIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        rhythmPresetRationale.identifier = NSUserInterfaceItemIdentifier("onboarding.rhythmPresetRationale")
        rhythmPresetRationale.font = .systemFont(ofSize: 11.5, weight: .medium)
        rhythmPresetRationale.textColor = .labelColor
        rhythmPresetRationale.lineBreakMode = .byWordWrapping
        rhythmPresetRationale.maximumNumberOfLines = 2
        rhythmPresetRationale.widthAnchor.constraint(lessThanOrEqualToConstant: 540).isActive = true
        rhythmPresetRationale.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rhythmPresetRationale.setContentCompressionResistancePriority(.required, for: .vertical)

        row.addArrangedSubview(rhythmPresetRationaleIcon)
        row.addArrangedSubview(rhythmPresetRationale)
        updateRhythmPresetSelectionUI()
        return row
    }

    private func buttonRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: 620).isActive = true

        let learnMoreButton = onboardingButton(
            title: L10n.tr("onboarding.learnMore"),
            identifier: "onboarding.aboutButton",
            symbolName: "questionmark.circle",
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
        let useSelectedButton = onboardingButton(
            title: primaryActionTitle(for: selectedRhythmPreset),
            identifier: "onboarding.useSelectedButton",
            symbolName: "checkmark.circle.fill",
            help: L10n.tr("onboarding.useSelectedHelp"),
            action: #selector(useSelectedPreset)
        )
        useSelectedButton.keyEquivalent = "\r"
        self.useSelectedButton = useSelectedButton

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(learnMoreButton)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(preferencesButton)
        row.addArrangedSubview(useSelectedButton)
        return row
    }

    private func onboardingButton(title: String, identifier: String, symbolName: String, help: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.bezelStyle = .rounded
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

    private func brandImage() -> NSImage {
        if let appIcon = NSImage(named: "AppIcon") {
            return appIcon
        }
        return RestGateIcon.fallbackAppImage(size: 64, accessibilityDescription: L10n.tr("app.name"))
    }

    private func symbolImage(_ symbolName: String, accessibilityDescription: String?) -> NSImage {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
            ?? NSImage(systemSymbolName: "circle", accessibilityDescription: accessibilityDescription)
            ?? NSImage(size: NSSize(width: 16, height: 16))
    }

    @objc private func rhythmPresetChanged(_ sender: NSSegmentedControl) {
        guard let preset = RestRhythmPreset(rawValue: sender.selectedSegment) else {
            sender.selectedSegment = selectedRhythmPreset.rawValue
            return
        }
        selectedRhythmPreset = preset
        updateRhythmPresetSelectionUI()
    }

    private func updateRhythmPresetSelectionUI() {
        rhythmPresetDescription.stringValue = selectedRhythmPreset.help
        rhythmPresetDescription.toolTip = selectedRhythmPreset.help
        rhythmPresetDescription.setAccessibilityLabel(selectedRhythmPreset.help)
        rhythmPresetDescription.setAccessibilityHelp(selectedRhythmPreset.help)
        rhythmPresetControl.toolTip = selectedRhythmPreset.help
        rhythmPresetControl.setAccessibilityHelp(selectedRhythmPreset.help)
        rhythmPresetIcon.image = rhythmPresetHeaderImage(for: selectedRhythmPreset)
        rhythmPresetIcon.setAccessibilityHelp(selectedRhythmPreset.help)
        let rationale = selectedRhythmPreset.onboardingRationale
        rhythmPresetRationale.stringValue = rationale
        rhythmPresetRationale.toolTip = rationale
        rhythmPresetRationale.setAccessibilityLabel(rationale)
        rhythmPresetRationale.setAccessibilityHelp(rationale)
        rhythmPresetRationaleIcon.image = symbolImage(
            selectedRhythmPreset == .firstRunDefault ? "checkmark.seal" : selectedRhythmPreset.symbolName,
            accessibilityDescription: rationale
        )
        rhythmPresetRationaleIcon.setAccessibilityLabel(rationale)
        rhythmPresetRationaleIcon.setAccessibilityHelp(rationale)
        rhythmMetricEyeInterval.stringValue = L10n.format(
            "onboarding.metric.eyeIntervalValue",
            selectedRhythmPreset.eyeIntervalMinutes
        )
        rhythmMetricEyeDuration.stringValue = L10n.format(
            "onboarding.metric.eyeDurationValue",
            selectedRhythmPreset.eyeDurationSeconds
        )
        rhythmMetricBodyAfter.stringValue = L10n.format(
            "onboarding.metric.bodyAfterValue",
            selectedRhythmPreset.bodyAfterEyeGateCount
        )
        rhythmMetricBodyDuration.stringValue = L10n.format(
            "onboarding.metric.bodyDurationValue",
            selectedRhythmPreset.bodyDurationMinutes
        )
        updateRhythmMetricAccessibility()

        guard let useSelectedButton else { return }
        let title = primaryActionTitle(for: selectedRhythmPreset)
        useSelectedButton.title = title
        useSelectedButton.setAccessibilityLabel(title)
        useSelectedButton.setAccessibilityHelp(useSelectedButton.toolTip)
        useSelectedButton.image?.accessibilityDescription = title
    }

    private func rhythmPresetAccessibilityTitle() -> String {
        "\(L10n.tr("onboarding.rhythmTitle")): \(selectedRhythmPreset.title)"
    }

    private func rhythmPresetHeaderImage(for preset: RestRhythmPreset) -> NSImage {
        symbolImage(preset.symbolName, accessibilityDescription: rhythmPresetAccessibilityTitle(for: preset))
    }

    private func rhythmPresetSegmentImage(for preset: RestRhythmPreset) -> NSImage {
        symbolImage(preset.symbolName, accessibilityDescription: preset.title)
    }

    private func rhythmPresetAccessibilityTitle(for preset: RestRhythmPreset) -> String {
        "\(L10n.tr("onboarding.rhythmTitle")): \(preset.title)"
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
            title: L10n.tr("onboarding.metric.bodyAfter"),
            valueLabel: rhythmMetricBodyAfter
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

    private func primaryActionTitle(for preset: RestRhythmPreset) -> String {
        L10n.format("onboarding.useSelectedWithPreset", preset.title)
    }

    @objc private func useSelectedPreset() {
        onUsePreset(selectedRhythmPreset)
        close()
    }

    @objc private func openPreferences() {
        onOpenPreferences(selectedRhythmPreset)
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
