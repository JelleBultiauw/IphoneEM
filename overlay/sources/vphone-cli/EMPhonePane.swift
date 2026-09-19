import AppKit
import Foundation
import Virtualization

// MARK: - Phone pane

@MainActor
final class EMPhonePaneView: NSView {
    let index: Int

    var state: EMPhoneState = .offline { didSet { needsDisplay = true; updateStatus() } }
    var vmTitle: String = "no vm" { didSet { needsDisplay = true } }
    private var bundleLabel: String? { vmTitle == "no vm" ? nil : vmTitle }
    var linkText: String = "" { didSet { needsDisplay = true } }
    var isActive: Bool = false { didSet { needsDisplay = true; updateControls() } }
    var isDual: Bool = false { didSet { needsDisplay = true } }
    /// True when the selected machine has no firmware restored yet.
    var needsFirmware = false { didSet { needsDisplay = true } }

    var onBoot: (() -> Void)?
    var onStop: (() -> Void)?
    var onHome: (() -> Void)?
    var onPower: (() -> Void)?
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?
    var onSnapshot: (() -> Void)?
    var onPickVM: ((NSView) -> Void)?
    var onDisplayRefresh: (() -> Void)?
    var onRecents: (() -> Void)?
    var onSelect: (() -> Void)?

    private(set) var screenView: VPhoneVirtualMachineView?
    private let screenHolder = NSView()
    private var buttons: [EMButton] = []
    private let bootButton: EMButton
    private let stopButton: EMButton
    private let snapButton: EMButton
    private let homeButton: EMButton
    private let powerButton: EMButton
    private let volumeUpButton: EMButton
    private let volumeDownButton: EMButton
    private let vmButton: EMButton
    private let refreshButton: EMButton
    private let recentsButton: EMButton

    private var screenWidth = 1290
    private var screenHeight = 2796
    private var displayScale: Double = 3.0
    private var fittedScreenRect: NSRect = .zero
    private var fittedBezelRect: NSRect = .zero

    private let headerHeight: CGFloat = 44
    private let controlHeight: CGFloat = 44

    init(index: Int) {
        self.index = index
        bootButton = EMButton(title: "Boot", kind: .primary, compact: true)
        stopButton = EMButton(title: "Stop", kind: .normal, compact: true)
        snapButton = EMButton(title: "Snapshot", kind: .normal, compact: true)
        homeButton = EMButton(kind: .quiet, compact: true, square: true)
        powerButton = EMButton(kind: .quiet, compact: true, square: true)
        volumeUpButton = EMButton(kind: .quiet, compact: true, square: true)
        volumeDownButton = EMButton(kind: .quiet, compact: true, square: true)
        vmButton = EMButton(title: "Select VM", kind: .quiet, compact: true)
        refreshButton = EMButton(kind: .quiet, compact: true, square: true)
        recentsButton = EMButton(kind: .quiet, compact: true, square: true)
        super.init(frame: .zero)
        wantsLayer = true

        addSubview(screenHolder)
        screenHolder.wantsLayer = true
        screenHolder.layer?.masksToBounds = true

        buttons = [bootButton, stopButton, snapButton, homeButton, powerButton, volumeUpButton, volumeDownButton, vmButton, refreshButton, recentsButton]
        for button in buttons { addSubview(button) }

        bootButton.onAction = { [weak self] in self?.onBoot?() }
        stopButton.onAction = { [weak self] in self?.onStop?() }
        snapButton.onAction = { [weak self] in self?.onSnapshot?() }
        homeButton.onAction = { [weak self] in self?.onHome?() }
        powerButton.onAction = { [weak self] in self?.onPower?() }
        volumeUpButton.onAction = { [weak self] in self?.onVolumeUp?() }
        volumeDownButton.onAction = { [weak self] in self?.onVolumeDown?() }
        recentsButton.onAction = { [weak self] in
            self?.onRecents?()
        }
        refreshButton.onAction = { [weak self] in
            guard let self else { return }
            self.refreshDisplay()
            self.onDisplayRefresh?()
        }
        vmButton.onAction = { [weak self] in
            guard let self else { return }
            self.onPickVM?(self.vmButton)
        }

        for (button, symbol) in [
            (bootButton, "power"), (stopButton, "stop.fill"), (snapButton, "camera"),
            (homeButton, "circle.dotted"), (powerButton, "lock"), (volumeUpButton, "speaker.plus"),
            (volumeDownButton, "speaker.minus"), (refreshButton, "arrow.clockwise"),
            (homeButton, "house"),
            (recentsButton, "square.on.square"),
        ] {
            button.iconName = symbol
        }
        homeButton.toolTip = "Home button"
        powerButton.toolTip = "Lock / wake"
        volumeUpButton.toolTip = "Volume up"
        volumeDownButton.toolTip = "Volume down"
        snapButton.toolTip = "Save a screenshot"
        bootButton.toolTip = "Boot this machine"
        stopButton.toolTip = "Stop this machine"
        vmButton.toolTip = "Choose the virtual machine in this bay"
        refreshButton.toolTip = "Reconnect the display if the screen stays black"
        homeButton.toolTip = "Home"
        recentsButton.toolTip = "App switcher"
        powerButton.toolTip = "Lock / wake"

        updateControls()
        updateStatus()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Engine attachment

    func configure(width: Int, height: Int, scale: Double) {
        screenWidth = width
        screenHeight = height
        displayScale = scale
        needsLayout = true
    }

    func attach(vm: VZVirtualMachine, control: VPhoneControl, keyHelper: VPhoneKeyHelper,
                width: Int, height: Int, scale: Double) {
        detach()
        configure(width: width, height: height, scale: scale)

        let view = VPhoneVirtualMachineView()
        view.virtualMachine = vm
        view.capturesSystemKeys = true
        view.keyHelper = keyHelper
        view.control = control
        view.wantsLayer = true
        view.alphaValue = 0
        screenView = view
        screenHolder.addSubview(view)
        needsLayout = true

        // gentle power-on
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.animator().alphaValue = 1
        }
    }

    func detach() {
        screenView?.removeFromSuperview()
        screenView = nil
    }

    var hasScreen: Bool { screenView != nil }

    /// The Face ID app switcher gesture: a slow swipe up from the bottom edge
    /// that pauses mid screen, so the guest opens the app switcher instead of
    /// going home. Works without the guest control channel.
    func showAppSwitcher() {
        guard let view = screenView else { return }
        let width = Double(screenWidth)
        let height = Double(screenHeight)
        view.injectSwipe(fromX: width * 0.5, fromY: height * 0.985,
                         toX: width * 0.5, toY: height * 0.42,
                         screenWidth: screenWidth, screenHeight: screenHeight,
                         durationMs: 900)
    }

    /// Re-attach the virtual machine to the display view. After a guest reboot
    /// (or a display sleep) the view can stop painting and show black even
    /// though the guest is fine; assigning the machine again reconnects it.
    func refreshDisplay() {
        guard let view = screenView, let machine = view.virtualMachine else { return }
        view.virtualMachine = nil
        view.virtualMachine = machine
        view.needsDisplay = true
    }

    // MARK: - Layout

    override func layout() {
        super.layout()

        let stage = NSRect(x: 0, y: controlHeight, width: bounds.width, height: bounds.height - headerHeight - controlHeight)
        let availableHeight = stage.height - 34
        let availableWidth = stage.width - 48

        let screenPointW = CGFloat(screenWidth) / CGFloat(displayScale)
        let screenPointH = CGFloat(screenHeight) / CGFloat(displayScale)
        let fit = min(availableHeight / screenPointH, availableWidth / screenPointW)
        let screenW = screenPointW * fit
        let screenH = screenPointH * fit
        let bezel = max(7, screenW * 0.038)
        let bezelRect = NSRect(x: stage.midX - (screenW + bezel * 2) / 2,
                               y: stage.minY + 16 + max(0, (availableHeight - (screenH + bezel * 2)) / 2),
                               width: screenW + bezel * 2, height: screenH + bezel * 2)
        fittedBezelRect = bezelRect
        fittedScreenRect = NSRect(x: bezelRect.minX + bezel, y: bezelRect.minY + bezel,
                                  width: screenW, height: screenH)
        screenHolder.frame = fittedScreenRect
        screenHolder.layer?.cornerRadius = min(fittedScreenRect.width, fittedScreenRect.height) * 0.115
        screenView?.frame = screenHolder.bounds

        // header
        let headerY = bounds.maxY - headerHeight
        vmButton.frame = NSRect(x: 112, y: headerY + 11, width: min(220, max(120, vmButton.intrinsicContentSize.width)), height: 22)

        // footer controls: boot/stop on the left, device controls on the right
        let y: CGFloat = 11
        var x: CGFloat = 14
        for button in [bootButton, stopButton] where !button.isHidden {
            let size = button.intrinsicContentSize
            button.frame = NSRect(x: x, y: y, width: size.width, height: 22)
            x += size.width + 6
        }
        var rightX = bounds.maxX - 14
        let rightGroup = [snapButton, refreshButton, powerButton, volumeUpButton,
                          volumeDownButton, homeButton, recentsButton]
        for button in rightGroup where !button.isHidden {
            let size = button.intrinsicContentSize
            rightX -= size.width
            button.frame = NSRect(x: rightX, y: y, width: size.width, height: 22)
            rightX -= 4
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Card
        EMDraw.card(bounds.insetBy(dx: 0.5, dy: 0.5), radius: 12,
                    border: isActive ? EMPalette.accent.withAlphaComponent(0.45) : EMPalette.border)

        // Header
        let header = NSRect(x: 1, y: bounds.maxY - headerHeight, width: bounds.width - 2, height: headerHeight - 1)
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: header, xRadius: 12, yRadius: 12).addClip()
        EMPalette.cardRaised.setFill()
        header.fill()
        NSColor(white: 1, alpha: 0.03).setFill()
        NSRect(x: header.minX, y: header.maxY - 1, width: header.width, height: 1).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
        EMDraw.line(from: NSPoint(x: 1, y: header.minY), to: NSPoint(x: bounds.maxX - 1, y: header.minY),
                    color: EMPalette.separator)

        if let image = EMSymbol.tinted("iphone.gen3", size: 13, color: EMPalette.textSecondary) {
            image.draw(in: NSRect(x: 18, y: header.midY - 7, width: 14, height: 14))
        }
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: EMFont.semibold(12.5),
            .foregroundColor: EMPalette.text,
            .kern: -0.1,
        ]
        ("Phone \(index + 1)" as NSString).draw(at: NSPoint(x: 40, y: header.midY - 8), withAttributes: titleAttributes)

        // status pill
        let pillText = state.text
        let pillAttributes: [NSAttributedString.Key: Any] = [
            .font: EMFont.medium(11),
            .foregroundColor: state.color,
        ]
        let pillSize = (pillText as NSString).size(withAttributes: pillAttributes)
        let pill = NSRect(x: header.maxX - pillSize.width - 30, y: header.midY - 10,
                          width: pillSize.width + 22, height: 20)
        EMDraw.fill(pill, state.color.withAlphaComponent(0.16), radius: 10)
        state.color.setFill()
        NSBezierPath(ovalIn: NSRect(x: pill.minX + 8, y: pill.midY - 3, width: 6, height: 6)).fill()
        (pillText as NSString).draw(at: NSPoint(x: pill.minX + 18, y: pill.midY - pillSize.height / 2 + 0.5),
                                    withAttributes: pillAttributes)

        // Footer
        let footer = NSRect(x: 1, y: 1, width: bounds.width - 2, height: controlHeight - 1)
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: footer, xRadius: 12, yRadius: 12).addClip()
        EMPalette.cardRaised.setFill()
        footer.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
        EMDraw.line(from: NSPoint(x: 1, y: footer.maxY - 0.5), to: NSPoint(x: bounds.maxX - 1, y: footer.maxY - 0.5),
                    color: EMPalette.separator)

        // metadata caption in the footer, left of the device controls
        if let bundleName = bundleLabel {
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.ui(11),
                .foregroundColor: EMPalette.textTertiary,
            ]
            let caption = "\(bundleName), \(screenWidth)x\(screenHeight) px"
            let size = (caption as NSString).size(withAttributes: captionAttributes)
            let snapLeft = bounds.maxX - (snapButton.isHidden ? 14 : snapButton.frame.minX) - 8
            let available = snapLeft - 130
            if available > size.width {
                (caption as NSString).draw(at: NSPoint(x: 130, y: footer.midY - size.height / 2),
                                          withAttributes: captionAttributes)
            }
        }

        guard !fittedBezelRect.isEmpty else { return }

        // Device shadow on the stage
        let shadowRect = NSRect(x: fittedBezelRect.minX + fittedBezelRect.width * 0.10,
                                y: fittedBezelRect.minY - 6,
                                width: fittedBezelRect.width * 0.80, height: 14)
        if let gradient = NSGradient(starting: NSColor(white: 0, alpha: 0.55), ending: NSColor(white: 0, alpha: 0)) {
            gradient.draw(in: NSBezierPath(ovalIn: shadowRect), angle: -90)
        }

        let corner = fittedBezelRect.width * 0.148

        // Bezel: titanium
        let bezelPath = NSBezierPath(roundedRect: fittedBezelRect, xRadius: corner, yRadius: corner)
        if let gradient = NSGradient(colorsAndLocations:
            (NSColor(srgbRed: 0.42, green: 0.42, blue: 0.45, alpha: 1), 0.0),
            (NSColor(srgbRed: 0.20, green: 0.20, blue: 0.22, alpha: 1), 0.18),
            (NSColor(srgbRed: 0.30, green: 0.30, blue: 0.33, alpha: 1), 0.55),
            (NSColor(srgbRed: 0.13, green: 0.13, blue: 0.15, alpha: 1), 1.0)) {
            gradient.draw(in: bezelPath, angle: 55)
        } else {
            NSColor(white: 0.2, alpha: 1).setFill()
            bezelPath.fill()
        }
        // outer rim light
        NSColor(white: 1, alpha: 0.28).setStroke()
        bezelPath.lineWidth = 1
        bezelPath.stroke()

        // side buttons
        let nubW = max(2, fittedBezelRect.width * 0.011)
        func nub(_ x: CGFloat, _ y: CGFloat, _ height: CGFloat, _ dark: Bool) {
            let rect = NSRect(x: x, y: y, width: nubW, height: height)
            (dark ? NSColor(srgbRed: 0.24, green: 0.24, blue: 0.26, alpha: 1) : NSColor(srgbRed: 0.46, green: 0.46, blue: 0.49, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect, xRadius: nubW / 2, yRadius: nubW / 2).fill()
        }
        let leftX = fittedBezelRect.minX - nubW + 0.5
        let rightX = fittedBezelRect.maxX - 0.5
        nub(leftX, fittedBezelRect.minY + fittedBezelRect.height * 0.585, fittedBezelRect.height * 0.075, false)
        nub(leftX, fittedBezelRect.minY + fittedBezelRect.height * 0.465, fittedBezelRect.height * 0.095, false)
        nub(leftX, fittedBezelRect.minY + fittedBezelRect.height * 0.345, fittedBezelRect.height * 0.095, false)
        nub(rightX, fittedBezelRect.minY + fittedBezelRect.height * 0.52, fittedBezelRect.height * 0.13, true)

        // inner bezel (black) around the display
        let inner = NSBezierPath(roundedRect: fittedScreenRect.insetBy(dx: -2.5, dy: -2.5),
                                 xRadius: (screenHolder.layer?.cornerRadius ?? 20) + 2.5,
                                 yRadius: (screenHolder.layer?.cornerRadius ?? 20) + 2.5)
        NSColor(white: 0.04, alpha: 1).setStroke()
        inner.lineWidth = 5
        inner.stroke()

        // Empty states
        if screenView == nil {
            let screenPath = NSBezierPath(roundedRect: fittedScreenRect, xRadius: screenHolder.layer?.cornerRadius ?? 20,
                                          yRadius: screenHolder.layer?.cornerRadius ?? 20)
            if let gradient = NSGradient(colorsAndLocations:
                (NSColor(srgbRed: 0.07, green: 0.07, blue: 0.09, alpha: 1), 0.0),
                (NSColor(srgbRed: 0.03, green: 0.03, blue: 0.04, alpha: 1), 1.0)) {
                gradient.draw(in: screenPath, angle: -90)
            }
            // very light diagonal sheen, like glass catching ambient light
            NSGraphicsContext.current?.saveGraphicsState()
            screenPath.addClip()
            if let sheen = NSGradient(starting: NSColor(white: 1, alpha: 0.045),
                                      ending: NSColor(white: 1, alpha: 0.0)) {
                sheen.draw(in: NSRect(x: fittedScreenRect.minX, y: fittedScreenRect.midY,
                                      width: fittedScreenRect.width, height: fittedScreenRect.height * 0.55),
                           angle: -70)
            }
            NSGraphicsContext.current?.restoreGraphicsState()

            let headline: String
            let hint: String
            switch state {
            case .empty:
                headline = "No virtual machine"
                hint = "Create one in Setup"
            case .booting:
                headline = "Booting..."
                hint = "Guest firmware is starting"
            case .error:
                headline = "Launch failed"
                hint = "Check the log in Setup"
            default:
                if needsFirmware {
                    headline = "No firmware installed"
                    hint = "Create Phone in Setup, then boot"
                } else {
                    headline = "Device off"
                    hint = "Press Boot to start"
                }
            }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let headlineAttributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.medium(13),
                .foregroundColor: EMPalette.textSecondary,
                .paragraphStyle: paragraph,
            ]
            let hintAttributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.ui(11),
                .foregroundColor: EMPalette.textTertiary,
                .paragraphStyle: paragraph,
            ]
            let width = fittedScreenRect.width - 24
            let headlineSize = (headline as NSString).boundingRect(with: NSSize(width: width, height: 60),
                                                                   options: [.usesLineFragmentOrigin],
                                                                   attributes: headlineAttributes)
            let hintSize = (hint as NSString).boundingRect(with: NSSize(width: width, height: 60),
                                                            options: [.usesLineFragmentOrigin],
                                                            attributes: hintAttributes)
            let total = headlineSize.height + hintSize.height + 4
            var y = fittedScreenRect.midY + total / 2 - headlineSize.height
            (headline as NSString).draw(in: NSRect(x: fittedScreenRect.minX + 12, y: y, width: width,
                                                   height: headlineSize.height), withAttributes: headlineAttributes)
            y -= hintSize.height + 4
            (hint as NSString).draw(in: NSRect(x: fittedScreenRect.minX + 12, y: y, width: width,
                                               height: hintSize.height), withAttributes: hintAttributes)
        } else if needsFirmware && (state == .running || state == .booting) {
            // the guest is up with an empty disk: say so instead of showing black
            let message = "No firmware on this machine. Create it in Setup."
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.medium(11.5),
                .foregroundColor: EMPalette.text,
                .paragraphStyle: paragraph,
            ]
            let size = (message as NSString).boundingRect(with: NSSize(width: fittedScreenRect.width - 40, height: 60),
                                                          options: [.usesLineFragmentOrigin], attributes: attributes)
            let chip = NSRect(x: fittedScreenRect.midX - size.width / 2 - 14,
                              y: fittedScreenRect.minY + 26,
                              width: size.width + 28, height: size.height + 16)
            EMDraw.fill(chip, NSColor(white: 0, alpha: 0.62), radius: chip.height / 2)
            NSColor(white: 1, alpha: 0.16).setStroke()
            let path = NSBezierPath(roundedRect: chip.insetBy(dx: 0.5, dy: 0.5), xRadius: chip.height / 2, yRadius: chip.height / 2)
            path.lineWidth = 1
            path.stroke()
            (message as NSString).draw(in: NSRect(x: chip.minX + 14, y: chip.midY - size.height / 2,
                                                  width: size.width + 1, height: size.height),
                                       withAttributes: attributes)
        }
    }

    // MARK: - State

    private func updateControls() {
        let booted = (state == .running || state == .linked || state == .booting)
        let linked = (state == .linked)
        bootButton.isHidden = booted
        stopButton.isHidden = !booted
        bootButton.isEnabled = !booted && state != .empty
        stopButton.isEnabled = booted
        homeButton.isEnabled = linked
        powerButton.isEnabled = linked
        volumeUpButton.isEnabled = linked
        volumeDownButton.isEnabled = linked
        recentsButton.isEnabled = booted
        recentsButton.isHidden = !booted
        // keep Home, Lock and volume visible once a phone is running: they are
        // the quick actions people reach for, and Home also wakes the display
        homeButton.isHidden = !booted
        powerButton.isHidden = !booted
        volumeUpButton.isHidden = !booted
        volumeDownButton.isHidden = !booted
        snapButton.isEnabled = state == .running || state == .linked
        refreshButton.isHidden = !booted
        refreshButton.isEnabled = booted
        vmButton.isEnabled = !booted
        needsLayout = true
    }

    private func updateStatus() {
        needsDisplay = true
        needsLayout = true
    }

    func setVMName(_ name: String?) {
        vmTitle = name ?? "no vm"
        vmButton.title = name.map { "\($0)" } ?? "Select VM"
        vmButton.kind = name == nil ? .quiet : .normal
        needsLayout = true
    }
}
