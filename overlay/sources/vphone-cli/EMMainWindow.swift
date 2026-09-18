import AppKit
import Foundation

// MARK: - Main window

@MainActor
final class EMMainWindowController: NSObject {
    private let app: EMAppController
    private var window: NSWindow?
    private let rootView = EMRootView()
    private let sidebar = EMSidebarView()
    private let pageArea = NSView()
    private let statusBar = EMStatusBarView()
    private let phonesPage = EMPhonesPageView()
    private var pages: [EMPage: EMPageView] = [:]
    private var currentPage: EMPage = .phones
    private var clockTimer: Timer?
    private var monitor: Any?

    private let sidebarWidth: CGFloat = 240
    private let statusHeight: CGFloat = 26

    init(app: EMAppController) {
        self.app = app
        super.init()
    }

    func showWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = "iPhoneEM"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = EMPalette.window
        window.isOpaque = true
        window.minSize = NSSize(width: 980, height: 660)
        window.isReleasedWhenClosed = false
        window.titlebarSeparatorStyle = .none

        rootView.attach(sidebar: sidebar, pageArea: pageArea, status: statusBar)
        rootView.addSubview(sidebar)
        rootView.addSubview(pageArea)
        rootView.addSubview(statusBar)
        window.contentView = rootView
        window.center()

        sidebar.onSelectPage = { [weak self] page in self?.show(page: page) }
        sidebar.onSelectPhone = { [weak self] index in self?.app.setActiveSlot(index) }
        sidebar.onToggleDual = { [weak self] enabled in self?.app.setDualPhone(enabled) }

        pages[.phones] = phonesPage
        phonesPage.app = app
        pages[.files] = EMFilesPage(app: app)
        pages[.apps] = EMAppsPage(app: app)
        pages[.screenshots] = EMScreenshotsPage(app: app)
        pages[.setup] = EMSetupPage(app: app)
        pages[.info] = EMInfoPage(app: app)
        for (_, page) in pages {
            page.translatesAutoresizingMaskIntoConstraints = true
            page.isHidden = true
            pageArea.addSubview(page)
        }

        self.window = window
        show(page: .phones)
        window.makeKeyAndOrderFront(nil)

        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatusBar() }
        }

        // Clicking a bay focuses it (the VM view swallows clicks itself).
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self, event.window === self.window, self.currentPage == .phones else { return event }
            let point = self.pageArea.convert(event.locationInWindow, from: nil)
            let local = self.phonesPage.convert(point, from: self.pageArea)
            for (index, pane) in self.phonesPage.panes where pane.frame.contains(local) {
                self.app.setActiveSlot(index)
            }
            return event
        }

        NotificationCenter.default.addObserver(forName: .emStateChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateStatusBar() }
        }
    }

    private func show(page: EMPage) {
        currentPage = page
        sidebar.selectedPage = page
        for (key, view) in pages {
            view.isHidden = key != page
        }
        pages[page]?.refresh()
        rootView.needsLayout = true
    }

    func reload(slots: [EMPhoneSlot], active: Int, dual: Bool) {
        sidebar.phones = slots.map { slot in
            EMSidebarView.PhoneRow(title: slot.title, subtitle: slot.bundleName ?? "No machine", state: slot.state)
        }
        sidebar.activePhone = active
        sidebar.dualPhone = dual
        phonesPage.reload(slots: slots, active: active, dual: dual, app: app)
        for (_, page) in pages { page.phoneChanged() }
        updateStatusBar()
    }

    func updateStatusBar() {
        let slot = app.activeSlot
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        var segments: [EMStatusBarView.Segment] = [
            .init(text: "Phone \(slot.index + 1) · \(slot.bundleName ?? "no machine")", color: EMPalette.textSecondary),
            .init(text: slot.state.text, color: slot.state.color,
                  led: (slot.state.color, slot.state == .linked || slot.state == .running)),
        ]
        if let ip = slot.control?.guestIP {
            segments.append(.init(text: ip, color: EMPalette.textTertiary))
        }
        segments.append(.init(text: app.bundles.count == 1 ? "1 machine" : "\(app.bundles.count) machines",
                              color: EMPalette.textTertiary))
        segments.append(.init(text: app.dualPhone ? "Dual bay" : "Single bay", color: EMPalette.textTertiary))
        segments.append(.init(text: formatter.string(from: Date()), color: EMPalette.textTertiary, width: 74))
        statusBar.segments = segments
    }
}

// MARK: - Root layout view

@MainActor
final class EMRootView: NSView {
    private weak var sidebar: NSView?
    private weak var pageArea: NSView?
    private weak var status: NSView?

    private let sidebarWidth: CGFloat = 240
    private let statusHeight: CGFloat = 26

    func attach(sidebar: NSView, pageArea: NSView, status: NSView) {
        self.sidebar = sidebar
        self.pageArea = pageArea
        self.status = status
    }

    override func layout() {
        super.layout()
        sidebar?.frame = NSRect(x: 0, y: 0, width: sidebarWidth, height: bounds.height)
        pageArea?.frame = NSRect(x: sidebarWidth, y: statusHeight,
                                 width: bounds.width - sidebarWidth, height: bounds.height - statusHeight)
        status?.frame = NSRect(x: sidebarWidth, y: 0, width: bounds.width - sidebarWidth, height: statusHeight)

        if let pageArea {
            let inner = NSRect(origin: .zero, size: pageArea.frame.size)
            for subview in pageArea.subviews {
                subview.frame = inner
                subview.needsLayout = true
            }
        }
        if ProcessInfo.processInfo.environment["EM_DEBUG"] != nil {
            let frames = (pageArea?.subviews ?? []).map { "\(type(of: $0)):\($0.frame)" }
            emTrace("root=\(bounds) sidebar=\(String(describing: sidebar?.frame)) pages=\(frames.joined(separator: " | "))")
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        EMPalette.canvas.setFill()
        bounds.fill()
    }
}

// MARK: - Phones page

@MainActor
final class EMPhonesPageView: EMPageView {
    private(set) var panes: [(index: Int, pane: EMPhonePaneView)] = []

    init() {
        super.init(app: nil, title: "Phones", subtitle: "Click a bay to focus — interact with the screen directly")
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        EMPalette.canvas.setFill()
        bounds.fill()
        // soft stage light from the top
        if let gradient = NSGradient(colorsAndLocations:
            (NSColor(white: 1, alpha: 0.035), 0.0),
            (NSColor(white: 1, alpha: 0.0), 0.7)) {
            gradient.draw(in: NSRect(x: bounds.minX, y: bounds.maxY - bounds.height * 0.45,
                                     width: bounds.width, height: bounds.height * 0.45), angle: -90)
        }
        super.draw(dirtyRect)
    }

    func reload(slots: [EMPhoneSlot], active: Int, dual: Bool, app: EMAppController) {
        self.app = app
        let wanted: [Int] = (dual && slots.count > 1) ? [0, 1] : [active]

        for (index, pane) in panes where !wanted.contains(index) {
            pane.removeFromSuperview()
        }
        panes.removeAll { !wanted.contains($0.index) }

        for index in wanted {
            let pane: EMPhonePaneView
            if let existing = panes.first(where: { $0.index == index })?.pane {
                pane = existing
            } else {
                pane = app.pane(for: index)
                addSubview(pane)
                panes.append((index, pane))
            }
            let slot = slots[index]
            pane.isActive = index == active && wanted.count > 1
            pane.isDual = dual
            pane.state = slot.control?.isConnected == true ? .linked : slot.state
            pane.setVMName(slot.bundleName)
            pane.linkText = slot.control?.guestIP ?? ""
        }
        panes.sort { $0.index < $1.index }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let top = bounds.maxY - 52
        let bottom = bounds.minY + 12
        guard !panes.isEmpty else { return }
        let gap: CGFloat = 12
        let paneWidth = (bounds.width - gap * CGFloat(panes.count + 1)) / CGFloat(panes.count)
        for (offset, entry) in panes.enumerated() {
            let x = gap + CGFloat(offset) * (paneWidth + gap)
            entry.pane.frame = NSRect(x: x, y: bottom, width: paneWidth, height: max(120, top - bottom))
        }
        if ProcessInfo.processInfo.environment["EM_DEBUG"] != nil {
            emTrace("phonesPage bounds=\(bounds) panes=\(panes.map { $0.pane.frame })")
        }
    }
}
