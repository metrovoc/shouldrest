import AppKit

extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

/// Fill, stroke, and corner styling for a layer-backed panel. Layer colors are
/// resolved against the view's effective appearance whenever it changes, so panels
/// follow light and dark switches while a window stays open.
@MainActor
struct SurfaceStyle {
    var fill: (_ isDark: Bool) -> NSColor?
    var stroke: (_ isDark: Bool) -> NSColor?
    var strokeWidth: CGFloat = 1
    var cornerRadius: CGFloat = 8

    /// Grouped form background, like System Settings sections.
    static let card = SurfaceStyle(
        fill: { $0 ? NSColor(white: 1, alpha: 0.05) : NSColor(white: 0, alpha: 0.032) },
        stroke: { $0 ? NSColor(white: 1, alpha: 0.09) : NSColor(white: 0, alpha: 0.06) },
        strokeWidth: 0.5,
        cornerRadius: 12
    )

    /// Subdued inset rows inside a card, such as saved rules and ideas.
    static let inset = SurfaceStyle(
        fill: { $0 ? NSColor(white: 1, alpha: 0.05) : NSColor(white: 1, alpha: 0.9) },
        stroke: { $0 ? NSColor(white: 1, alpha: 0.08) : NSColor(white: 0, alpha: 0.07) }
    )

    static let accentNotice = tinted(.controlAccentColor)
    static let warningNotice = tinted(.systemOrange)

    static func tinted(_ color: NSColor) -> SurfaceStyle {
        SurfaceStyle(
            fill: { color.withAlphaComponent($0 ? 0.16 : 0.08) },
            stroke: { color.withAlphaComponent($0 ? 0.32 : 0.2) }
        )
    }

    func apply(to view: NSView) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }
        let appearance = view.effectiveAppearance
        let isDark = appearance.isDarkMode
        appearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = fill(isDark)?.cgColor
            layer.borderColor = stroke(isDark)?.cgColor
        }
        layer.borderWidth = stroke(isDark) == nil ? 0 : strokeWidth
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
    }
}

/// A stack view drawn as a panel that follows appearance changes.
class SurfaceStackView: NSStackView {
    var surfaceStyle: SurfaceStyle? {
        didSet { surfaceStyle?.apply(to: self) }
    }

    convenience init(style: SurfaceStyle) {
        self.init(frame: .zero)
        // Property observers do not run inside the class's own initializers.
        surfaceStyle = style
        style.apply(to: self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        surfaceStyle?.apply(to: self)
    }
}

/// A plain view drawn as a panel that follows appearance changes.
class SurfaceView: NSView {
    var surfaceStyle: SurfaceStyle? {
        didSet { surfaceStyle?.apply(to: self) }
    }

    convenience init(style: SurfaceStyle) {
        self.init(frame: .zero)
        // Property observers do not run inside the class's own initializers.
        surfaceStyle = style
        style.apply(to: self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        surfaceStyle?.apply(to: self)
    }
}
