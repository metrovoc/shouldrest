import AppKit
import Foundation

private enum OnboardingFeatureIcon {
    case restGate
    case systemSymbol(String)
}

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let onUseDefaults: () -> Void
    private let onOpenPreferences: () -> Void
    private let onLearnMore: () -> Void

    init(
        onUseDefaults: @escaping () -> Void,
        onOpenPreferences: @escaping () -> Void,
        onLearnMore: @escaping () -> Void
    ) {
        self.onUseDefaults = onUseDefaults
        self.onOpenPreferences = onOpenPreferences
        self.onLearnMore = onLearnMore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 380),
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
        stack.spacing = 22
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 30, bottom: 24, right: 30)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        stack.addArrangedSubview(heroView())
        stack.addArrangedSubview(featureList())
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
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 480).isActive = true
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
        panel.widthAnchor.constraint(equalToConstant: 580).isActive = true
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
        bodyLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 500).isActive = true

        copy.addArrangedSubview(titleLabel)
        copy.addArrangedSubview(bodyLabel)
        row.addArrangedSubview(copy)
        return row
    }

    private func buttonRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.widthAnchor.constraint(equalToConstant: 580).isActive = true

        let learnMoreButton = onboardingButton(
            title: L10n.tr("onboarding.learnMore"),
            symbolName: "questionmark.circle",
            action: #selector(learnMore)
        )
        let preferencesButton = onboardingButton(
            title: L10n.tr("onboarding.preferences"),
            symbolName: "slider.horizontal.3",
            action: #selector(openPreferences)
        )
        let useDefaultsButton = onboardingButton(
            title: L10n.tr("onboarding.useDefaults"),
            symbolName: "checkmark.circle.fill",
            action: #selector(useDefaults)
        )
        useDefaultsButton.keyEquivalent = "\r"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(learnMoreButton)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(preferencesButton)
        row.addArrangedSubview(useDefaultsButton)
        return row
    }

    private func onboardingButton(title: String, symbolName: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.image = symbolImage(symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
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
            ?? NSImage(systemSymbolName: "circle", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 16, height: 16))
    }

    @objc private func useDefaults() {
        onUseDefaults()
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
