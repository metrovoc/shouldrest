import AppKit
import Foundation
import ShouldRestCore

@MainActor
final class PreferencesWindowController: NSWindowController {
    private var settings: RestSettings
    private let onSave: (RestSettings) -> Void

    private let eyeEnabled = NSButton(checkboxWithTitle: "Enable Eye Gate", target: nil, action: nil)
    private let eyeInterval = NSTextField()
    private let eyeDuration = NSTextField()
    private let bodyEnabled = NSButton(checkboxWithTitle: "Enable Body Break", target: nil, action: nil)
    private let bodyDuration = NSTextField()
    private let bodyAfterEyeGates = NSTextField()
    private let focusDefersBody = NSButton(checkboxWithTitle: "Focus mode defers Body Break", target: nil, action: nil)
    private let openAtLogin = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
    private let trayStyle = NSPopUpButton()

    init(settings: RestSettings, onSave: @escaping (RestSettings) -> Void) {
        self.settings = settings
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ShouldRest Preferences"
        window.center()
        super.init(window: window)

        buildContent()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(settings: RestSettings) {
        self.settings = settings
        loadSettings()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        stack.addArrangedSubview(sectionLabel("Eye Gate"))
        stack.addArrangedSubview(eyeEnabled)
        stack.addArrangedSubview(row("Every minutes", eyeInterval))
        stack.addArrangedSubview(row("Duration seconds", eyeDuration))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(sectionLabel("Body Break"))
        stack.addArrangedSubview(bodyEnabled)
        stack.addArrangedSubview(row("Duration minutes", bodyDuration))
        stack.addArrangedSubview(row("After Eye Gates", bodyAfterEyeGates))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(sectionLabel("Context And Menu"))
        stack.addArrangedSubview(focusDefersBody)
        stack.addArrangedSubview(openAtLogin)
        trayStyle.addItems(withTitles: ["default", "timeToBreak", "progress"])
        stack.addArrangedSubview(row("Menu bar style", trayStyle))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 12
        buttons.alignment = .centerY
        let save = NSButton(title: "Save", target: self, action: #selector(savePressed))
        let restore = NSButton(title: "Restore Defaults", target: self, action: #selector(restoreDefaultsPressed))
        buttons.addArrangedSubview(save)
        buttons.addArrangedSubview(restore)
        stack.addArrangedSubview(buttons)
    }

    private func loadSettings() {
        eyeEnabled.state = settings.eyeGate.isEnabled ? .on : .off
        eyeInterval.stringValue = String(Int(settings.eyeGate.interval / 60))
        eyeDuration.stringValue = String(Int(settings.eyeGate.duration))
        bodyEnabled.state = settings.bodyBreak.isEnabled ? .on : .off
        bodyDuration.stringValue = String(Int(settings.bodyBreak.duration / 60))
        bodyAfterEyeGates.stringValue = String(settings.bodyBreakAfterEyeGates)
        focusDefersBody.state = settings.focusMode.deferBodyBreak ? .on : .off
        openAtLogin.state = settings.operations.openAtLogin ? .on : .off
        trayStyle.selectItem(withTitle: settings.presentation.trayIconStyle.rawValue)
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        return label
    }

    private func row(_ title: String, _ field: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 160).isActive = true

        if let textField = field as? NSTextField {
            textField.widthAnchor.constraint(equalToConstant: 110).isActive = true
        } else if let popup = field as? NSPopUpButton {
            popup.widthAnchor.constraint(equalToConstant: 150).isActive = true
        }

        let stack = NSStackView(views: [label, field])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        return stack
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    @objc private func savePressed() {
        var next = settings
        next.eyeGate.isEnabled = eyeEnabled.state == .on
        next.eyeGate.interval = TimeInterval(max(1, intValue(eyeInterval)) * 60)
        next.eyeGate.duration = TimeInterval(max(1, intValue(eyeDuration)))
        next.bodyBreak.isEnabled = bodyEnabled.state == .on
        next.bodyBreak.duration = TimeInterval(max(1, intValue(bodyDuration)) * 60)
        next.bodyBreakAfterEyeGates = max(1, intValue(bodyAfterEyeGates))
        next.focusMode.deferBodyBreak = focusDefersBody.state == .on
        next.operations.openAtLogin = openAtLogin.state == .on
        if let selected = trayStyle.selectedItem?.title,
           let style = TrayIconStyle(rawValue: selected) {
            next.presentation.trayIconStyle = style
        }
        settings = next
        onSave(next)
    }

    @objc private func restoreDefaultsPressed() {
        settings = .defaults
        loadSettings()
        onSave(.defaults)
    }

    private func intValue(_ field: NSTextField) -> Int {
        Int(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
}
