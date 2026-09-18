import AppKit
import Foundation

// MARK: - List row model

struct EMRow {
    var icon: String = ""
    /// SF Symbol name — preferred over `icon` and `image`.
    var symbol: String?
    var image: NSImage?
    var title: String
    var columns: [String] = []
    var detail: String = ""
    var enabled: Bool = true
    var tint: NSColor?
}

// MARK: - List view

@MainActor
final class EMListView: NSView {
    var rows: [EMRow] = [] { didSet { reload() } }
    var columnWidths: [CGFloat] = [] { didSet { needsDisplay = true } }
    var selectedIndex: Int? {
        didSet {
            guard selectedIndex != oldValue else { return }
            needsDisplay = true
            onSelectionChange?()
        }
    }
    var onActivate: ((Int) -> Void)?
    var onSelectionChange: (() -> Void)?
    var emptyText: String = "Nothing here"
    var rowHeight: CGFloat = 26
    var showsDetail: Bool = true
    var rowInset: CGFloat = 0

    private var hoveredIndex: Int?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func reload() {
        if let selectedIndex, selectedIndex >= rows.count { self.selectedIndex = nil }
        let height = max(rowHeight, CGFloat(rows.count) * rowHeight + 8)
        setFrameSize(NSSize(width: max(bounds.width, superview?.bounds.width ?? bounds.width), height: height))
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(NSSize(width: newSize.width, height: max(newSize.height, CGFloat(rows.count) * rowHeight + 8)))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = rowIndex(at: point)
        if index != hoveredIndex {
            hoveredIndex = index
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hoveredIndex = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = rowIndex(at: point) else { return }
        selectedIndex = index
        if event.clickCount >= 2 { onActivate?(index) }
    }

    override func keyDown(with event: NSEvent) {
        guard !rows.isEmpty else { return }
        switch event.keyCode {
        case 125: selectedIndex = min((selectedIndex ?? -1) + 1, rows.count - 1)
        case 126: selectedIndex = max((selectedIndex ?? 1) - 1, 0)
        case 36, 76: if let index = selectedIndex { onActivate?(index) }
        default: super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    private func rowIndex(at point: NSPoint) -> Int? {
        let index = Int((point.y - 4) / rowHeight)
        guard index >= 0, index < rows.count else { return nil }
        return index
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let visible = rows.enumerated().filter { index, _ in
            let top = 4 + CGFloat(index) * rowHeight
            return top + rowHeight > dirtyRect.minY && top < dirtyRect.maxY
        }

        for (index, row) in visible {
            let rect = NSRect(x: rowInset, y: 4 + CGFloat(index) * rowHeight,
                              width: bounds.width - rowInset * 2, height: rowHeight - 1)
            let selected = selectedIndex == index
            if selected {
                EMDraw.fill(rect, EMPalette.accent.withAlphaComponent(0.26), radius: 6)
                EMPalette.accent.withAlphaComponent(0.55).setStroke()
                let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
                path.lineWidth = 1
                path.stroke()
            } else if hoveredIndex == index {
                EMDraw.fill(rect, EMPalette.hover, radius: 6)
            }

            let primary = row.enabled ? (selected ? EMPalette.text : NSColor(white: 1, alpha: 0.86))
                                      : EMPalette.textTertiary
            let secondary = selected ? NSColor(white: 1, alpha: 0.72) : EMPalette.textTertiary

            // icon
            let iconX = rect.minX + 10
            if let symbolName = row.symbol, let image = EMSymbol.tinted(symbolName, size: 12, color: row.tint ?? secondary) {
                image.draw(in: NSRect(x: iconX, y: rect.midY - 6, width: 12.5, height: 12.5))
            } else if let image = row.image {
                let side = rowHeight - 8
                image.draw(in: NSRect(x: iconX, y: rect.midY - side / 2, width: side, height: side))
            } else if !row.icon.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: EMFont.ui(12),
                    .foregroundColor: row.tint ?? secondary,
                ]
                (row.icon as NSString).draw(at: NSPoint(x: iconX, y: rect.midY - 8), withAttributes: attributes)
            }

            // trailing columns
            var rightEdge = rect.maxX - 10
            let widths = columnWidths.count == row.columns.count ? columnWidths
                : Array(repeating: 96, count: row.columns.count)
            for (columnIndex, value) in row.columns.enumerated().reversed() {
                let width = widths[columnIndex]
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: EMFont.ui(11),
                    .foregroundColor: secondary,
                ]
                let size = (value as NSString).size(withAttributes: attributes)
                let x = rightEdge - width + max(0, width - size.width - 8)
                (value as NSString).draw(at: NSPoint(x: min(x, rightEdge - size.width), y: rect.midY - size.height / 2),
                                         withAttributes: attributes)
                rightEdge -= width
            }

            // title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: selected ? EMFont.medium(12) : EMFont.ui(12),
                .foregroundColor: primary,
            ]
            let detailWidth: CGFloat = showsDetail ? 190 : 0
            let titleRect = NSRect(x: rect.minX + 30, y: rect.midY - 8,
                                   width: max(24, rightEdge - 38 - detailWidth), height: rowHeight)
            (row.title as NSString).draw(in: titleRect, withAttributes: titleAttributes)

            if showsDetail, !row.detail.isEmpty {
                let detailAttributes: [NSAttributedString.Key: Any] = [
                    .font: EMFont.ui(11),
                    .foregroundColor: secondary,
                ]
                let size = (row.detail as NSString).size(withAttributes: detailAttributes)
                (row.detail as NSString).draw(at: NSPoint(x: max(34, rightEdge - size.width - 8),
                                                          y: rect.midY - size.height / 2),
                                              withAttributes: detailAttributes)
            }
        }

        if rows.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.ui(12),
                .foregroundColor: EMPalette.textTertiary,
            ]
            let size = (emptyText as NSString).size(withAttributes: attributes)
            (emptyText as NSString).draw(at: NSPoint(x: max(10, bounds.midX - size.width / 2), y: 22),
                                         withAttributes: attributes)
        }
    }
}

// MARK: - Scroll wrapper

@MainActor
final class EMListBox: NSView {
    let listView = EMListView()
    private let scrollView = NSScrollView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = listView
        listView.autoresizingMask = [.width]
        listView.rowInset = 6
        addSubview(scrollView)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        scrollView.frame = bounds.insetBy(dx: 1, dy: 1)
        listView.setFrameSize(NSSize(width: scrollView.contentSize.width, height: listView.frame.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        EMDraw.field(bounds.insetBy(dx: 0.5, dy: 0.5), radius: 8, fill: NSColor(srgbRed: 0.055, green: 0.055, blue: 0.065, alpha: 1))
    }
}
