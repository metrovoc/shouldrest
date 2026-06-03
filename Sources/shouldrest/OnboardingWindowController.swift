import AppKit
import Foundation

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let onUseDefaults: () -> Void
    private let onOpenPreferences: () -> Void

    init(onUseDefaults: @escaping () -> Void, onOpenPreferences: @escaping () -> Void) {
        self.onUseDefaults = onUseDefaults
        self.onOpenPreferences = onOpenPreferences

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
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
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let title = NSTextField(labelWithString: L10n.tr("onboarding.heading"))
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let body = NSTextField(labelWithString: L10n.tr("onboarding.body"))
        body.lineBreakMode = .byWordWrapping
        body.widthAnchor.constraint(equalToConstant: 460).isActive = true

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 12
        buttons.addArrangedSubview(NSButton(title: L10n.tr("onboarding.useDefaults"), target: self, action: #selector(useDefaults)))
        buttons.addArrangedSubview(NSButton(title: L10n.tr("onboarding.preferences"), target: self, action: #selector(openPreferences)))

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(body)
        stack.addArrangedSubview(buttons)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc private func useDefaults() {
        onUseDefaults()
        close()
    }

    @objc private func openPreferences() {
        onOpenPreferences()
        close()
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
