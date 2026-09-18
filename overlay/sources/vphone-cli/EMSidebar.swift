import AppKit
import Foundation

// MARK: - Sidebar

@MainActor
final class EMSidebarView: NSView {
    struct PhoneRow {
        var title: String
        var subtitle: String
        var state: EMPhoneState
    }

    private struct Item {
        var rect: NSRect
        var page: EMPage
    }

    var phones: [PhoneRow] = [] { didSet { needsDisplay = true } }
    var activePhone: Int = 0 { didSet { needsDisplay = true } }
    var selectedPage: EMPage = .phones { didSet { needsDisplay = true } }
    var dualPhone: Bool = false { didSet { needsDisplay = true } }

    var onSelectPage: ((EMPage) -> Void)?
    var onSelectPhone: ((Int) -> Void)?
    var onToggleDual: ((Bool) -> Void)?

    private var pageItems: [Item] = []
    private var phoneRects: [NSRect] = []
    private var dualRect: NSRect = .zero
    private var switchRect: NSRect = .zero
    private var hoveredPage: EMPage?
    private var hoveredPhone: Int?
    private var hoveringDual = false
    private var trackingArea: NSTrackingArea?

    private let rowInset: CGFloat = 10

    override var isFlipped: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let page = pageItems.first(where: { $0.rect.contains(point) })?.page
        let phone = phoneRects.enumerated().first(where: { $0.element.contains(point) })?.offset
        let dual = dualRect.contains(point)
        if page != hoveredPage || phone != hoveredPhone || dual != hoveringDual {
            hoveredPage = page
            hoveredPhone = phone
            hoveringDual = dual
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hoveredPage = nil
        hoveredPhone = nil
        hoveringDual = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let hit = phoneRects.enumerated().first(where: { $0.element.contains(point) }) {
            onSelectPhone?(hit.offset)
            return
        }
        if dualRect.contains(point) {
            onToggleDual?(!dualPhone)
            return
        }
        if let hit = pageItems.first(where: { $0.rect.contains(point) }) {
            onSelectPage?(hit.page)
        }
    }

    // MARK: - Drawing

    private func rowBackground(_ rect: NSRect, selected: Bool, hovered: Bool) {
        if selected {
            EMDraw.fill(rect, EMPalette.selection, radius: 7)
        } else if hovered {
            EMDraw.fill(rect, EMPalette.hover, radius: 7)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Sidebar surface: slightly darker than the content area.
        EMPalette.window.setFill()
        bounds.fill()
        EMDraw.line(from: NSPoint(x: bounds.maxX - 0.5, y: 0), to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY),
                    color: EMPalette.separator)

        // Room for the window controls; the list itself starts right below them.
        var y = bounds.maxY - 44

        // ── phones ────────────────────────────────────────────────────
        EMStyle.sectionAttributes("Phones").draw(at: NSPoint(x: rowInset + 6, y: y - 12))
        y -= 26

        phoneRects = []
        for (index, phone) in phones.enumerated() {
            let row = NSRect(x: rowInset, y: y - 36, width: bounds.width - rowInset * 2, height: 34)
            phoneRects.append(row)
            rowBackground(row, selected: index == activePhone, hovered: hoveredPhone == index)

            let symbolColor = index == activePhone ? EMPalette.text : EMPalette.textSecondary
            if let image = EMSymbol.tinted("iphone.gen3", size: 13, color: symbolColor) {
                image.draw(in: NSRect(x: row.minX + 9, y: row.midY - 7, width: 14, height: 14))
            }

            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.medium(12),
                .foregroundColor: EMPalette.text,
            ]
            (phone.title as NSString).draw(at: NSPoint(x: row.minX + 32, y: row.midY + 3), withAttributes: nameAttributes)

            let detailAttributes: [NSAttributedString.Key: Any] = [
                .font: EMFont.ui(11),
                .foregroundColor: index == activePhone ? EMPalette.textSecondary : EMPalette.textTertiary,
            ]
            let detail = phone.subtitle.isEmpty ? "—" : phone.subtitle
            (detail as NSString).draw(at: NSPoint(x: row.minX + 32, y: row.midY - 11), withAttributes: detailAttributes)

            // state dot
            let dot = NSRect(x: row.maxX - 20, y: row.midY - 3.5, width: 7, height: 7)
            (phone.state == .offline || phone.state == .empty ? NSColor(white: 1, alpha: 0.18) : phone.state.color).setFill()
            NSBezierPath(ovalIn: dot).fill()

            y -= 38
        }

        // ── two phones switch ─────────────────────────────────────────
        dualRect = NSRect(x: rowInset, y: y - 28, width: bounds.width - rowInset * 2, height: 26)
        if hoveringDual { EMDraw.fill(dualRect, EMPalette.hover, radius: 7) }
        let switchSize = NSSize(width: 30, height: 17)
        switchRect = NSRect(x: dualRect.maxX - switchSize.width - 8, y: dualRect.midY - switchSize.height / 2,
                            width: switchSize.width, height: switchSize.height)
        EMDraw.fill(switchRect, dualPhone ? EMPalette.accent : NSColor(white: 1, alpha: 0.14), radius: switchSize.height / 2)
        let knobSize: CGFloat = 13
        let knob = NSRect(x: dualPhone ? switchRect.maxX - knobSize - 2 : switchRect.minX + 2,
                          y: switchRect.midY - knobSize / 2, width: knobSize, height: knobSize)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: knob).fill()

        let dualLabel = NSAttributedString(string: "Two phones", attributes: [
            .font: EMFont.ui(12),
            .foregroundColor: EMPalette.text,
        ])
        dualLabel.draw(at: NSPoint(x: dualRect.minX + 8, y: dualRect.midY - 8))
        y = dualRect.minY - 22

        // ── shortcuts ─────────────────────────────────────────────────
        EMStyle.sectionAttributes("Shortcuts").draw(at: NSPoint(x: rowInset + 6, y: y - 12))
        y -= 26

        pageItems = []
        for page in EMPage.allCases {
            let row = NSRect(x: rowInset, y: y - 30, width: bounds.width - rowInset * 2, height: 28)
            pageItems.append(Item(rect: row, page: page))
            let selected = page == selectedPage
            rowBackground(row, selected: selected, hovered: hoveredPage == page)

            let color = selected ? EMPalette.text : EMPalette.textSecondary
            if let image = EMSymbol.tinted(page.symbolName, size: 12.5, color: color) {
                image.draw(in: NSRect(x: row.minX + 9, y: row.midY - 6.5, width: 13, height: 13))
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: selected ? EMFont.medium(12) : EMFont.ui(12),
                .foregroundColor: color,
            ]
            (page.title as NSString).draw(at: NSPoint(x: row.minX + 32, y: row.midY - 8), withAttributes: attributes)
            y -= 32
        }
    }
}
