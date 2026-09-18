import AppKit
import Foundation

// MARK: - Design tokens (dark, macOS-native)

enum EMPalette {
    // Surfaces
    static let window = NSColor(srgbRed: 0.055, green: 0.055, blue: 0.063, alpha: 1)          // #0E0E10
    static let canvas = NSColor(srgbRed: 0.075, green: 0.075, blue: 0.086, alpha: 1)          // #131316
    static let card = NSColor(srgbRed: 0.098, green: 0.098, blue: 0.110, alpha: 1)            // #19191C
    static let cardRaised = NSColor(srgbRed: 0.125, green: 0.125, blue: 0.140, alpha: 1)      // #202024
    static let field = NSColor(srgbRed: 0.055, green: 0.055, blue: 0.063, alpha: 1)

    // Lines
    static let border = NSColor(white: 1, alpha: 0.075)
    static let borderStrong = NSColor(white: 1, alpha: 0.13)
    static let separator = NSColor(white: 1, alpha: 0.065)
    static let hover = NSColor(white: 1, alpha: 0.055)
    static let press = NSColor(white: 1, alpha: 0.10)
    static let selection = NSColor(white: 1, alpha: 0.11)

    // Text
    static let text = NSColor(white: 1, alpha: 0.93)
    static let textSecondary = NSColor(white: 1, alpha: 0.58)
    static let textTertiary = NSColor(white: 1, alpha: 0.38)

    // Accents
    static let accent = NSColor.controlAccentColor
    static let accentSoft = NSColor.controlAccentColor.withAlphaComponent(0.22)
    static let ok = NSColor.systemGreen
    static let warn = NSColor.systemOrange
    static let bad = NSColor.systemRed
    static let link = NSColor.systemTeal
    static let idle = NSColor(white: 1, alpha: 0.30)

    // Legacy aliases (kept so the page code stays terse)
    static let face = card
    static let faceLight = cardRaised
    static let faceDark = NSColor(white: 1, alpha: 0.14)
    static let edgeLight = NSColor(white: 1, alpha: 0.10)
    static let edgeShadow = NSColor(white: 1, alpha: 0.06)
    static let edgeDeep = text
    static let skyTop = NSColor(srgbRed: 0.055, green: 0.055, blue: 0.070, alpha: 1)
    static let skyBottom = NSColor(srgbRed: 0.10, green: 0.11, blue: 0.14, alpha: 1)
    static let gloss = NSColor(white: 1, alpha: 0.06)

    static let sideTop = window
    static let sideBottom = window
    static let sideRow = hover
    static let sideRowHover = NSColor(white: 1, alpha: 0.075)
    static let sideSelTop = selection
    static let sideSelBottom = selection
    static let sideText = text
    static let titleTop = window
    static let titleMid = window
    static let titleBottom = window
    static let titleText = text
}

// MARK: - Typography

enum EMFont {
    /// System UI font — SF by default, as Apple intends.
    static func ui(_ size: CGFloat, bold: Bool = false) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
    }

    static func medium(_ size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .medium)
    }

    static func semibold(_ size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    /// Monospaced digits / console text.
    static func pixel(_ size: CGFloat, bold: Bool = false) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .medium : .regular)
    }

    static func label(_ size: CGFloat, bold: Bool = false) -> NSFont {
        ui(size, bold: bold)
    }

    /// Small uppercase section label with the tracking Apple uses at small sizes.
    static func section(_ size: CGFloat = 10.5) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .semibold)
    }
}

enum EMStyle {
    /// Tracking is size specific: tight for display text, open for captions.
    static func tracking(for size: CGFloat) -> CGFloat {
        if size >= 20 { return -0.6 }
        if size >= 15 { return -0.25 }
        if size <= 11 { return 0.35 }
        return 0
    }

    static func sectionAttributes(_ text: String, color: NSColor = EMPalette.textTertiary,
                                  size: CGFloat = 10.5) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: EMFont.section(size),
            .foregroundColor: color,
            .kern: 0.7,
        ])
    }

    static func titleAttributes(size: CGFloat, color: NSColor = EMPalette.text, weight: NSFont.Weight = .semibold) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .kern: tracking(for: size),
        ]
    }
}

// MARK: - Text helpers

enum EMText {
    static func label(_ text: String, size: CGFloat = 12, bold: Bool = false,
                      color: NSColor = EMPalette.text, mono: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = mono ? EMFont.pixel(size, bold: bold) : (bold ? EMFont.semibold(size) : EMFont.ui(size))
        field.textColor = color
        field.drawsBackground = false
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    static func caption(_ text: String, size: CGFloat = 11) -> NSTextField {
        label(text, size: size, bold: false, color: EMPalette.textSecondary)
    }
}

// MARK: - Drawing

enum EMDraw {
    static func fill(_ rect: NSRect, _ color: NSColor, radius: CGFloat = 0) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    static func line(from: NSPoint, to: NSPoint, color: NSColor, width: CGFloat = 1) {
        let path = NSBezierPath()
        path.move(to: from)
        path.line(to: to)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    /// A soft surface with a hairline border — the base of every card here.
    static func card(_ rect: NSRect, fill fillColor: NSColor = EMPalette.card, radius: CGFloat = 10,
                     border: NSColor = EMPalette.border, topHighlight: Bool = true) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        fillColor.setFill()
        path.fill()
        if topHighlight {
            NSGraphicsContext.current?.saveGraphicsState()
            path.addClip()
            NSColor(white: 1, alpha: 0.05).setFill()
            NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }
        border.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    /// Inset field: darker than its container, with an inner top shadow.
    static func field(_ rect: NSRect, radius: CGFloat = 6, fill fillColor: NSColor = EMPalette.field) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        fillColor.setFill()
        path.fill()
        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        NSColor(white: 0, alpha: 0.35).setFill()
        NSRect(x: rect.minX, y: rect.maxY - 1.5, width: rect.width, height: 1.5).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
        NSColor(white: 1, alpha: 0.06).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    static func glossFill(_ rect: NSRect, top: NSColor, bottom: NSColor, radius: CGFloat = 8,
                          border: NSColor? = nil, borderWidth: CGFloat = 1) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        if let gradient = NSGradient(starting: top, ending: bottom) {
            gradient.draw(in: path, angle: -90)
        } else {
            top.setFill()
            path.fill()
        }
        if let border {
            border.setStroke()
            path.lineWidth = borderWidth
            path.stroke()
        }
    }

    static func sunkenFill(_ rect: NSRect, color: NSColor = EMPalette.field, radius: CGFloat = 6) {
        field(rect, radius: radius, fill: color)
    }

    static func raisedBorder(_ rect: NSRect, radius: CGFloat = 8) {
        NSColor(white: 1, alpha: 0.08).setStroke()
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.lineWidth = 1
        path.stroke()
    }

    static func glossHighlight(_ rect: NSRect, radius: CGFloat = 8, alpha: CGFloat = 0.06) {
        NSGraphicsContext.current?.saveGraphicsState()
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.addClip()
        if let gradient = NSGradient(starting: NSColor(white: 1, alpha: alpha),
                                     ending: NSColor(white: 1, alpha: 0)) {
            gradient.draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2),
                          angle: -90)
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    static func checker(_ rect: NSRect, size: CGFloat = 2, color: NSColor) { _ = (rect, size, color) }

    static func cloud(in rect: NSRect, color: NSColor) {
        color.setFill()
        for (fx, fy, fw, fh) in [(0.0, 0.25, 0.55, 0.50), (0.30, 0.05, 0.60, 0.75), (0.62, 0.20, 0.50, 0.55)] {
            NSBezierPath(ovalIn: NSRect(x: rect.minX + CGFloat(fx) * rect.width,
                                        y: rect.minY + CGFloat(fy) * rect.height,
                                        width: CGFloat(fw) * rect.width,
                                        height: CGFloat(fh) * rect.height)).fill()
        }
    }

    /// Soft drop shadow for floating surfaces.
    static func shadow(_ rect: NSRect, radius: CGFloat, blur: CGFloat, dy: CGFloat = -6, alpha: CGFloat = 0.45) {
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: alpha)
        shadow.shadowBlurRadius = blur
        shadow.shadowOffset = NSSize(width: 0, height: dy)
        shadow.set()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}

// MARK: - Symbols

enum EMSymbol {
    static func image(_ name: String, size: CGFloat = 13, weight: NSFont.Weight = .medium) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    static func tinted(_ name: String, size: CGFloat = 13, color: NSColor) -> NSImage? {
        guard let image = image(name, size: size) else { return nil }
        let tinted = NSImage(size: image.size)
        tinted.lockFocus()
        image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}

// MARK: - Button

@MainActor
final class EMButton: NSControl {
    enum Kind { case normal, primary, danger, ghost, quiet }

    var title: String { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    var kind: Kind { didSet { needsDisplay = true } }
    /// SF Symbol name — tinted with the label colour in every state.
    var iconName: String? { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    var icon: NSImage? { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    var isActive = false { didSet { needsDisplay = true } }
    var compact = false { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    var square = false { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    var fontSize: CGFloat = 12 { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    private(set) var isPressed = false
    private var isHovering = false
    var onAction: (() -> Void)?

    init(title: String = "", kind: Kind = .normal, compact: Bool = false, square: Bool = false,
         fontSize: CGFloat = 12, onAction: (() -> Void)? = nil) {
        self.title = title
        self.kind = kind
        self.compact = compact
        self.square = square
        self.fontSize = fontSize
        self.onAction = onAction
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    private var height: CGFloat { compact ? 24 : 28 }
    private var radius: CGFloat { compact ? 6 : 6.5 }
    private var hasIcon: Bool { iconName != nil || icon != nil }

    override var intrinsicContentSize: NSSize {
        let textWidth = (title as NSString).size(withAttributes: [.font: EMFont.medium(fontSize)]).width
        if square || title.isEmpty {
            return NSSize(width: height, height: height)
        }
        let iconWidth: CGFloat = hasIcon ? fontSize + 6 : 0
        let padding: CGFloat = compact ? 20 : 26
        return NSSize(width: ceil(textWidth + iconWidth + padding), height: height)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    // MARK: Press feedback — instant on mouse-down, eased back out (100–160 ms).

    private func animateScale(_ scale: CGFloat) {
        guard let layer else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }

    override func mouseEntered(with event: NSEvent) { isHovering = true; needsDisplay = true }

    override func mouseExited(with event: NSEvent) {
        if isPressed { animateScale(1) }
        isHovering = false
        isPressed = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        animateScale(square ? 0.94 : 0.97)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        let wasPressed = isPressed
        if wasPressed { animateScale(1) }
        isPressed = false
        needsDisplay = true
        if inside && wasPressed { onAction?() }
    }

    // MARK: Drawing

    private var labelColor: NSColor {
        guard isEnabled else { return NSColor(white: 1, alpha: 0.32) }
        switch kind {
        case .primary, .danger: return .white
        case .normal, .ghost, .quiet: return isActive ? .white : EMPalette.text
        }
    }

    /// Light catching the top edge of a surface — the detail that makes a fill read as material.
    private func innerTopHighlight(_ rect: NSRect, alpha: CGFloat) {
        guard alpha > 0 else { return }
        NSGraphicsContext.current?.saveGraphicsState()
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.addClip()
        NSColor(white: 1, alpha: alpha).setFill()
        NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawSurface(_ rect: NSRect, fill: NSColor, border: NSColor?, shadow: NSColor? = nil) {
        if let shadow {
            NSGraphicsContext.current?.saveGraphicsState()
            let ns = NSShadow()
            ns.shadowColor = shadow
            ns.shadowBlurRadius = 7
            ns.shadowOffset = NSSize(width: 0, height: -2)
            ns.set()
            NSColor.black.withAlphaComponent(0.001).setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }
        EMDraw.fill(rect, fill, radius: radius)
        if let border {
            border.setStroke()
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.25, dy: 0.25), xRadius: radius, yRadius: radius)
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let enabled = isEnabled

        switch kind {
        case .primary:
            let base = enabled ? EMPalette.accent : EMPalette.accent.withAlphaComponent(0.28)
            let top = base.blended(withFraction: isPressed ? 0.0 : 0.07, of: .white) ?? base
            let bottom = base.blended(withFraction: isPressed ? 0.14 : 0.08, of: .black) ?? base
            EMDraw.glossFill(rect, top: isHovering && !isPressed ? (top.blended(withFraction: 0.06, of: .white) ?? top) : top,
                             bottom: bottom, radius: radius,
                             border: NSColor(white: 1, alpha: enabled ? 0.16 : 0.08))
            innerTopHighlight(rect, alpha: enabled ? 0.22 : 0.10)
            if enabled && !isPressed {
                // prominent actions carry a whisper of their own colour
                NSGraphicsContext.current?.saveGraphicsState()
                let ns = NSShadow()
                ns.shadowColor = EMPalette.accent.withAlphaComponent(isHovering ? 0.45 : 0.32)
                ns.shadowBlurRadius = 8
                ns.shadowOffset = NSSize(width: 0, height: -2)
                ns.set()
                NSColor.black.withAlphaComponent(0.001).setFill()
                NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
                NSGraphicsContext.current?.restoreGraphicsState()
            }
        case .danger:
            let base = enabled ? EMPalette.bad.blended(withFraction: 0.05, of: .black) ?? EMPalette.bad
                               : EMPalette.bad.withAlphaComponent(0.28)
            let top = base.blended(withFraction: isPressed ? 0.0 : (isHovering ? 0.12 : 0.06), of: .white) ?? base
            let bottom = base.blended(withFraction: isPressed ? 0.16 : 0.10, of: .black) ?? base
            EMDraw.glossFill(rect, top: top, bottom: bottom, radius: radius,
                             border: NSColor(white: 1, alpha: enabled ? 0.14 : 0.08))
            innerTopHighlight(rect, alpha: 0.18)
        case .normal:
            let fillColor: NSColor = isActive
                ? EMPalette.accent.withAlphaComponent(isPressed ? 0.75 : 0.9)
                : NSColor(white: 1, alpha: isPressed ? 0.055 : (isHovering ? 0.115 : 0.085))
            drawSurface(rect, fill: fillColor,
                        border: NSColor(white: 1, alpha: enabled ? (isHovering ? 0.155 : 0.105) : 0.05))
            innerTopHighlight(rect, alpha: isPressed ? 0.02 : 0.055)
        case .ghost, .quiet:
            if isPressed {
                drawSurface(rect, fill: NSColor(white: 1, alpha: 0.105), border: nil)
            } else if isHovering && enabled {
                drawSurface(rect, fill: NSColor(white: 1, alpha: 0.075), border: nil)
            }
        }

        drawContent()
    }

    private func drawContent() {
        let font = EMFont.medium(fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: labelColor,
        ]
        let textSize = (title as NSString).size(withAttributes: attributes)
        let iconSide: CGFloat = square ? 15 : fontSize + 1
        let spacing: CGFloat = 6
        var totalWidth = title.isEmpty ? 0 : textSize.width
        if hasIcon { totalWidth += iconSide + (title.isEmpty ? 0 : spacing) }
        var x = bounds.midX - totalWidth / 2

        // optical centring: align the cap height, not the bounding box
        let baselineY = bounds.midY + font.capHeight / 2

        if let iconName, let image = EMSymbol.tinted(iconName, size: iconSide - 2, color: labelColor) {
            image.draw(in: NSRect(x: x, y: bounds.midY - iconSide / 2 + 0.5, width: iconSide, height: iconSide))
            x += iconSide + (title.isEmpty ? 0 : spacing)
        } else if let icon {
            icon.draw(in: NSRect(x: x, y: bounds.midY - iconSide / 2 + 0.5, width: iconSide, height: iconSide),
                      from: .zero, operation: .sourceOver, fraction: isEnabled ? 1 : 0.32)
            x += iconSide + (title.isEmpty ? 0 : spacing)
        }

        if !title.isEmpty {
            let drawY = (baselineY - font.ascender).rounded()
            (title as NSString).draw(at: NSPoint(x: x.rounded(), y: drawY), withAttributes: attributes)
            _ = textSize
        }
    }
}

// MARK: - LED

@MainActor
final class EMLED: NSView {
    var color: NSColor = EMPalette.idle { didSet { needsDisplay = true } }
    var isLit = false { didSet { needsDisplay = true } }
    var diameter: CGFloat = 8 { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }

    override var intrinsicContentSize: NSSize { NSSize(width: diameter, height: diameter) }

    override func draw(_ dirtyRect: NSRect) {
        let rect = NSRect(x: (bounds.width - diameter) / 2, y: (bounds.height - diameter) / 2,
                          width: diameter, height: diameter)
        if isLit {
            NSGraphicsContext.current?.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = color.withAlphaComponent(0.7)
            glow.shadowBlurRadius = diameter * 0.9
            glow.set()
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }
        (isLit ? color : NSColor(white: 1, alpha: 0.22)).setFill()
        NSBezierPath(ovalIn: rect).fill()
    }
}

// MARK: - Card / group box

@MainActor
final class EMGroupBox: NSView {
    private let titleLabel: NSTextField
    private let content: NSView
    var inset: CGFloat = 14

    init(title: String, content: NSView) {
        self.content = content
        self.titleLabel = EMText.label(title.uppercased(), size: 10.5, bold: true, color: EMPalette.textTertiary)
        super.init(frame: .zero)
        wantsLayer = true
        for view in [titleLabel, content] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            content.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 9),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        EMDraw.card(bounds.insetBy(dx: 0.5, dy: 0.5), radius: 10)
    }
}

// MARK: - Separator

@MainActor
final class EMSeparator: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 9) }

    override func draw(_ dirtyRect: NSRect) {
        EMDraw.line(from: NSPoint(x: 0, y: bounds.midY), to: NSPoint(x: bounds.maxX, y: bounds.midY),
                    color: EMPalette.separator)
    }
}

// MARK: - Console

@MainActor
final class EMConsoleView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
    private var rendered = ""
    private var lastWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textColor = NSColor(white: 1, alpha: 0.78)
        textView.font = EMFont.pixel(11)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 4

        scrollView.documentView = textView
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        scrollView.frame = bounds.insetBy(dx: 1, dy: 1)
        let size = scrollView.contentSize
        guard size.width > 1 else { return }
        if abs(lastWidth - size.width) > 0.5 {
            lastWidth = size.width
            textView.frame = NSRect(x: 0, y: 0, width: size.width,
                                    height: max(size.height, textView.frame.height))
            applyText()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        EMDraw.field(bounds.insetBy(dx: 0.5, dy: 0.5), radius: 8, fill: NSColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1))
    }

    private func applyText() {
        textView.string = rendered
        textView.sizeToFit()
        if textView.frame.height < scrollView.contentSize.height {
            textView.frame = NSRect(x: 0, y: 0, width: textView.frame.width,
                                    height: scrollView.contentSize.height)
        }
        textView.scrollToEndOfDocument(nil)
    }

    func append(_ line: String) {
        rendered = line
        let lines = rendered.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > 4000 {
            rendered = lines.suffix(2500).joined(separator: "\n")
        }
        applyText()
    }

    func clear() {
        rendered = ""
        textView.string = ""
    }
}

// MARK: - Status bar

@MainActor
final class EMStatusBarView: NSView {
    struct Segment {
        var text: String
        var color: NSColor = EMPalette.textSecondary
        var width: CGFloat = 0
        var led: (NSColor, Bool)? = nil
    }

    var segments: [Segment] = [] { didSet { needsDisplay = true } }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 26) }

    override func draw(_ dirtyRect: NSRect) {
        EMPalette.window.setFill()
        bounds.fill()
        EMDraw.line(from: NSPoint(x: 0, y: bounds.maxY - 0.5), to: NSPoint(x: bounds.maxX, y: bounds.maxY - 0.5),
                    color: EMPalette.separator)

        var x: CGFloat = 18
        for (index, segment) in segments.enumerated() {
            if index > 0 {
                x -= 10
                EMDraw.line(from: NSPoint(x: x, y: bounds.midY - 4), to: NSPoint(x: x, y: bounds.midY + 4),
                            color: EMPalette.separator)
                x += 12
            }
            if let (color, lit) = segment.led {
                let dot = NSRect(x: x, y: bounds.midY - 3, width: 6, height: 6)
                (lit ? color : NSColor(white: 1, alpha: 0.20)).setFill()
                NSBezierPath(ovalIn: dot).fill()
                x += 11
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.ui(11),
                .foregroundColor: segment.color,
            ]
            let size = (segment.text as NSString).size(withAttributes: attributes)
            let rect = NSRect(x: x, y: bounds.midY - size.height / 2, width: segment.width > 0 ? segment.width - 6 : size.width + 2,
                              height: size.height)
            (segment.text as NSString).draw(in: rect, withAttributes: attributes)
            x += (segment.width > 0 ? segment.width : size.width) + 12
        }
    }
}

// MARK: - Stage backdrop

@MainActor
final class EMSkyView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // Soft "device stage" light behind the phones.
        EMPalette.canvas.setFill()
        bounds.fill()
        if let gradient = NSGradient(colorsAndLocations:
            (NSColor(white: 1, alpha: 0.045), 0.0),
            (NSColor(white: 1, alpha: 0.012), 0.45),
            (NSColor(white: 1, alpha: 0.0), 1.0)) {
            gradient.draw(in: NSRect(x: bounds.minX, y: bounds.midY, width: bounds.width, height: bounds.height / 2),
                          angle: -90)
        }
    }
}
