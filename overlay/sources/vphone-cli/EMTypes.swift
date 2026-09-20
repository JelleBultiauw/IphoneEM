import AppKit
import Foundation

// MARK: - Shared types

enum EMPage: Int, CaseIterable {
    case phones
    case files
    case apps
    case location
    case screenshots
    case setup
    case info

    var title: String {
        switch self {
        case .phones: "Phones"
        case .files: "Files"
        case .apps: "Apps"
        case .location: "Location"
        case .screenshots: "Screenshots"
        case .setup: "Setup"
        case .info: "Info"
        }
    }

    var subtitle: String {
        switch self {
        case .phones: "Live device bays"
        case .files: "iPhone storage"
        case .apps: "Installed applications"
        case .location: "Location simulation"
        case .screenshots: "Captured screens"
        case .setup: "Library, host checks and console"
        case .info: "Connection details and paths"
        }
    }

    /// Phone bound shortcuts act on the selected bay; the others are shared.
    var isPhoneBound: Bool {
        switch self {
        case .phones, .files, .apps, .location: true
        case .screenshots, .setup, .info: false
        }
    }

    var symbolName: String {
        switch self {
        case .phones: "iphone.gen3"
        case .files: "folder"
        case .apps: "square.grid.2x2"
        case .location: "location"
        case .screenshots: "photo.on.rectangle.angled"
        case .setup: "slider.horizontal.3"
        case .info: "info.circle"
        }
    }
}

enum EMPhoneState: Equatable {
    case empty
    case offline
    case booting
    case running
    case linked
    case error(String)

    var text: String {
        switch self {
        case .empty: "No VM"
        case .offline: "Offline"
        case .booting: "Booting"
        case .running: "Running"
        case .linked: "Connected"
        case .error: "Error"
        }
    }

    var color: NSColor {
        switch self {
        case .empty, .offline: EMPalette.textTertiary
        case .booting: EMPalette.warn
        case .running: EMPalette.ok
        case .linked: EMPalette.accent
        case .error: EMPalette.bad
        }
    }
}

// MARK: - Log

@MainActor
final class EMLog {
    static let shared = EMLog()
    private(set) var lines: [String] = []
    var onChange: (() -> Void)?

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    func write(_ message: String) {
        let stamped = "[\(formatter.string(from: Date()))] \(message)"
        lines.append(stamped)
        if lines.count > 4000 { lines.removeFirst(lines.count - 3000) }
        onChange?()
        NotificationCenter.default.post(name: .emLogChanged, object: nil)
    }

    func clear() {
        lines.removeAll()
        onChange?()
        NotificationCenter.default.post(name: .emLogChanged, object: nil)
    }

    var text: String { lines.joined(separator: "\n") }
}

// MARK: - Helpers

enum EMFormat {
    static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func date(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Read-only value field

@MainActor
final class EMReadOnlyField: NSTextField {
    init(text: String, size: CGFloat = 11.5, mono: Bool = true, color: NSColor = EMPalette.text) {
        super.init(frame: .zero)
        stringValue = text
        font = mono ? EMFont.pixel(size) : EMFont.ui(size)
        textColor = color
        isEditable = false
        isSelectable = true
        isBezeled = false
        isBordered = false
        drawsBackground = true
        backgroundColor = EMPalette.field
        focusRingType = .none
        lineBreakMode = .byTruncatingMiddle
        wantsLayer = true
        if let layer {
            layer.cornerRadius = 6
            layer.borderWidth = 1
            layer.borderColor = EMPalette.border.cgColor
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        // keep the text off the rounded edge
        if let cell = cell as? NSTextFieldCell {
            _ = cell
        }
    }
}

// MARK: - Section header

@MainActor
final class EMSectionHeaderView: NSView {
    private let title: String
    private let trailing: String

    init(title: String, trailing: String = "") {
        self.title = title
        self.trailing = trailing
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 18) }

    override func draw(_ dirtyRect: NSRect) {
        EMStyle.sectionAttributes(title).draw(at: NSPoint(x: 0, y: 3))
        if !trailing.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.ui(11),
                .foregroundColor: EMPalette.textTertiary,
            ]
            let size = (trailing as NSString).size(withAttributes: attributes)
            (trailing as NSString).draw(at: NSPoint(x: bounds.maxX - size.width, y: 4), withAttributes: attributes)
        }
    }
}
