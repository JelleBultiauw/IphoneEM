import AppKit
import Foundation
import UniformTypeIdentifiers
import VPhoneCore

// MARK: - Page base

@MainActor
class EMPageView: NSView {
    weak var app: EMAppController?
    private var headerTitle = ""
    private var headerSubtitle = ""

    init(app: EMAppController?, title: String, subtitle: String) {
        self.app = app
        self.headerTitle = title
        self.headerSubtitle = subtitle
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        EMPalette.canvas.setFill()
        bounds.fill()

        // header
        let header = NSRect(x: 0, y: bounds.maxY - 46, width: bounds.width, height: 46)
        var x: CGFloat = 24
        let titleAttributes = EMStyle.titleAttributes(size: 15)
        (headerTitle as NSString).draw(at: NSPoint(x: x, y: header.midY - 8), withAttributes: titleAttributes)
        x += (headerTitle as NSString).size(withAttributes: titleAttributes).width + 10
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: EMFont.ui(11.5),
            .foregroundColor: EMPalette.textTertiary,
        ]
        (headerSubtitle as NSString).draw(at: NSPoint(x: x, y: header.midY - 7), withAttributes: subtitleAttributes)
        EMDraw.line(from: NSPoint(x: 0, y: header.minY), to: NSPoint(x: bounds.maxX, y: header.minY),
                    color: EMPalette.separator)
    }

    func refresh() {}
    func phoneChanged() {}
}

// MARK: - Building blocks

@MainActor
enum EMUI {
    static func toolbar(_ views: [NSView], height: CGFloat = 30) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        stack.heightAnchor.constraint(equalToConstant: height).isActive = true
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    static func spacer() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    static func panel(title: String, views: [NSView], padding: CGFloat = 14, fill: Bool = false) -> EMGroupBox {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.distribution = fill ? .fill : .gravityAreas
        stack.translatesAutoresizingMaskIntoConstraints = false

        let holder = NSView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(stack)
        var constraints = [
            stack.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
            stack.topAnchor.constraint(equalTo: holder.topAnchor),
        ]
        constraints.append(stack.bottomAnchor.constraint(lessThanOrEqualTo: holder.bottomAnchor))
        NSLayoutConstraint.activate(constraints)
        if fill, let last = views.last {
            last.setContentHuggingPriority(.defaultLow, for: .vertical)
            last.bottomAnchor.constraint(equalTo: holder.bottomAnchor).isActive = true
        }
        let box = EMGroupBox(title: title, content: holder)
        box.inset = padding
        return box
    }

    static func field(_ text: String, width: CGFloat = 200) -> NSTextField {
        let field = NSTextField(string: text)
        field.font = EMFont.ui(12)
        field.textColor = EMPalette.text
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = EMPalette.field
        field.focusRingType = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        field.wantsLayer = true
        field.layer?.cornerRadius = 6
        field.layer?.borderWidth = 1
        field.layer?.borderColor = EMPalette.border.cgColor
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        field.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return field
    }

    static func popup(_ items: [String], width: CGFloat = 140) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: items)
        popup.appearance = NSAppearance(named: .darkAqua)
        popup.controlSize = .regular
        popup.font = EMFont.medium(11)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: width).isActive = true
        return popup
    }

    static func lcd(_ text: String, width: CGFloat? = nil, mono: Bool = true, size: CGFloat = 10.5) -> EMReadOnlyField {
        let field = EMReadOnlyField(text: text, size: size, mono: mono)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 24).isActive = true
        if let width {
            field.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return field
    }
}

// MARK: - FILES

@MainActor
final class EMFilesPage: EMPageView {
    private let list = EMListBox()
    private let pathField = EMReadOnlyField(text: "/var/mobile", size: 11)
    private let statusField = EMText.label("", size: 10, color: NSColor(calibratedWhite: 0.35, alpha: 1))
    private let upButton = EMButton(title: "Up", compact: true)
    private let refreshButton = EMButton(title: "Refresh", compact: true)
    private let homeButton = EMButton(title: "Home", compact: true)
    private let downloadButton = EMButton(title: "Save to Mac", compact: true)
    private let uploadButton = EMButton(title: "Upload", compact: true)
    private let folderButton = EMButton(title: "New Folder", compact: true)
    private let deleteButton = EMButton(title: "Delete", kind: .danger, compact: true)

    private var currentPath = "/var/mobile"
    private var history: [String] = []
    private var files: [VPhoneRemoteFile] = []

    init(app: EMAppController?) {
        super.init(app: app, title: "Files", subtitle: "iPhone storage. Double-click a folder to open it.")
        list.translatesAutoresizingMaskIntoConstraints = false
        pathField.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = EMUI.toolbar([upButton, refreshButton, homeButton, EMUI.spacer(), pathField,
                                    EMUI.spacer(), downloadButton, uploadButton, folderButton, deleteButton])
        let statusBar = EMUI.toolbar([statusField], height: 22)

        addSubview(toolbar)
        addSubview(list)
        addSubview(statusBar)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 54),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            pathField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),

            list.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 4),
            list.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            list.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            list.bottomAnchor.constraint(equalTo: statusBar.topAnchor, constant: -4),

            statusBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            statusBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            statusBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        upButton.onAction = { [weak self] in self?.goUp() }
        refreshButton.onAction = { [weak self] in self?.load() }
        homeButton.onAction = { [weak self] in self?.navigate(to: "/var/mobile") }
        downloadButton.onAction = { [weak self] in self?.downloadSelected() }
        uploadButton.onAction = { [weak self] in self?.upload() }
        folderButton.onAction = { [weak self] in self?.newFolder() }
        deleteButton.onAction = { [weak self] in self?.deleteSelected() }

        list.listView.onActivate = { [weak self] index in
            guard let self, index < self.files.count else { return }
            let file = self.files[index]
            if file.isDirectoryLike { self.navigate(to: file.path) }
        }
        list.listView.onSelectionChange = { [weak self] in self?.updateButtons() }
        list.listView.columnWidths = [80, 110]
        updateButtons()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func refresh() {
        load()
    }

    override func phoneChanged() {
        currentPath = "/var/mobile"
        history = []
        files = []
        list.listView.rows = []
        load()
    }

    private var control: VPhoneControl? { app?.activeControl }

    private func navigate(to path: String) {
        history.append(currentPath)
        currentPath = path
        load()
    }

    private func goUp() {
        guard currentPath != "/" else { return }
        let parent = (currentPath as NSString).deletingLastPathComponent
        navigate(to: parent.isEmpty ? "/" : parent)
    }

    private func load() {
        pathField.stringValue = currentPath
        guard let control, control.isConnected else {
            files = []
            list.listView.rows = []
            statusField.stringValue = "phone offline, boot the phone to browse its files"
            updateButtons()
            return
        }
        statusField.stringValue = "loading \(currentPath)..."
        Task { @MainActor in
            do {
                let entries = try await control.listFiles(path: currentPath)
                let parsed = entries.compactMap { VPhoneRemoteFile(dir: currentPath, entry: $0) }
                files = parsed.sorted { a, b in
                    if a.isDirectoryLike != b.isDirectoryLike { return a.isDirectoryLike }
                    return a.name.lowercased() < b.name.lowercased()
                }
                list.listView.rows = files.map { file in
                    EMRow(symbol: file.isDirectoryLike ? "folder.fill" : "doc.fill",
                          title: file.name,
                          columns: [file.displaySize, file.displayDate],
                          tint: file.isDirectoryLike ? EMPalette.accent : nil)
                }
                statusField.stringValue = "\(files.count) items in \(currentPath)"
            } catch {
                files = []
                list.listView.rows = []
                statusField.stringValue = "error: \(error)"
            }
            updateButtons()
        }
    }

    private func updateButtons() {
        let connected = control?.isConnected ?? false
        upButton.isEnabled = connected && currentPath != "/"
        refreshButton.isEnabled = true
        homeButton.isEnabled = connected
        let hasSelection = list.listView.selectedIndex != nil
        downloadButton.isEnabled = connected && hasSelection
        uploadButton.isEnabled = connected
        folderButton.isEnabled = connected
        deleteButton.isEnabled = connected && hasSelection
    }

    private func selectedFile() -> VPhoneRemoteFile? {
        guard let index = list.listView.selectedIndex, index < files.count else { return nil }
        return files[index]
    }

    private func downloadSelected() {
        guard let control, let file = selectedFile() else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Save Here"
        panel.message = "Save \(file.name) to this folder"
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        let destination = directory.appendingPathComponent(file.name)
        Task { @MainActor in
            do {
                let data = try await control.downloadFile(path: file.path)
                try data.write(to: destination)
                EMLog.shared.write("files: saved \(file.path) -> \(destination.path)")
                statusField.stringValue = "saved to \(destination.path)"
            } catch {
                statusField.stringValue = "download failed: \(error)"
                EMLog.shared.write("files: download failed \(error)")
            }
        }
    }

    private func upload() {
        guard let control else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Upload into \(currentPath)"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { @MainActor in
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let target = (currentPath as NSString).appendingPathComponent(url.lastPathComponent)
                    try await control.uploadFile(path: target, data: data)
                    EMLog.shared.write("files: uploaded \(url.lastPathComponent) -> \(target)")
                } catch {
                    EMLog.shared.write("files: upload failed \(url.lastPathComponent): \(error)")
                }
            }
            load()
        }
    }

    private func newFolder() {
        guard let control else { return }
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Name for the new folder in \(currentPath)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 22))
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let target = (currentPath as NSString).appendingPathComponent(name)
        Task { @MainActor in
            do {
                try await control.createDirectory(path: target)
                EMLog.shared.write("files: created \(target)")
                load()
            } catch {
                EMLog.shared.write("files: mkdir failed \(error)")
            }
        }
    }

    private func deleteSelected() {
        guard let control, let file = selectedFile() else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \(file.name)?"
        alert.informativeText = "This removes the item from the phone's storage."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { @MainActor in
            do {
                try await control.deleteFile(path: file.path)
                EMLog.shared.write("files: deleted \(file.path)")
                load()
            } catch {
                EMLog.shared.write("files: delete failed \(error)")
            }
        }
    }
}

// MARK: - APPS

@MainActor
final class EMAppsPage: EMPageView {
    private let list = EMListBox()
    private let statusField = EMText.label("", size: 10, color: NSColor(calibratedWhite: 0.35, alpha: 1))
    private let refreshButton = EMButton(title: "Refresh", compact: true)
    private let installButton = EMButton(title: "Install IPA...", kind: .primary, compact: true)
    private let launchButton = EMButton(title: "Launch", compact: true)
    private let terminateButton = EMButton(title: "Terminate", compact: true)
    private let openButton = EMButton(title: "Open URL...", compact: true)

    private var apps: [VPhoneControl.AppInfo] = []

    init(app: EMAppController?) {
        super.init(app: app, title: "Apps", subtitle: "Installed applications. Drag an .ipa onto a phone to install.")
        list.translatesAutoresizingMaskIntoConstraints = false
        let toolbar = EMUI.toolbar([refreshButton, installButton, launchButton, terminateButton, openButton, EMUI.spacer()])
        let statusBar = EMUI.toolbar([statusField], height: 22)
        addSubview(toolbar)
        addSubview(list)
        addSubview(statusBar)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 54),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            list.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 4),
            list.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            list.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            list.bottomAnchor.constraint(equalTo: statusBar.topAnchor, constant: -4),
            statusBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            statusBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            statusBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        refreshButton.onAction = { [weak self] in self?.load() }
        installButton.onAction = { [weak self] in self?.installIPA() }
        launchButton.onAction = { [weak self] in self?.launchSelected() }
        terminateButton.onAction = { [weak self] in self?.terminateSelected() }
        openButton.onAction = { [weak self] in self?.openURL() }
        list.listView.onSelectionChange = { [weak self] in self?.updateButtons() }
        list.listView.columnWidths = [110, 200, 60]
        updateButtons()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func refresh() { load() }
    override func phoneChanged() { load() }

    private var control: VPhoneControl? { app?.activeControl }

    private func load() {
        guard let control, control.isConnected else {
            apps = []
            list.listView.rows = []
            statusField.stringValue = "phone offline, boot the phone to list its apps"
            updateButtons()
            return
        }
        statusField.stringValue = "loading..."
        Task { @MainActor in
            do {
                let result = try await control.appList(filter: "all")
                apps = result.sorted { $0.name.lowercased() < $1.name.lowercased() }
                list.listView.rows = apps.map { app in
                    EMRow(symbol: app.state == "running" ? "play.circle.fill" : "app.fill",
                          title: app.name.isEmpty ? app.bundleId : app.name,
                          columns: [app.version, app.state == "running" ? "pid \(app.pid)" : "",
                                    app.type],
                          detail: app.bundleId,
                          tint: app.state == "running" ? EMPalette.ok : nil)
                }
                statusField.stringValue = "\(apps.count) apps, \(apps.filter { $0.state == "running" }.count) running"
            } catch {
                apps = []
                list.listView.rows = []
                statusField.stringValue = "error: \(error)"
            }
            updateButtons()
        }
    }

    private func updateButtons() {
        let connected = control?.isConnected ?? false
        let hasSelection = list.listView.selectedIndex != nil
        installButton.isEnabled = connected
        refreshButton.isEnabled = true
        launchButton.isEnabled = connected && hasSelection
        terminateButton.isEnabled = connected && hasSelection
        openButton.isEnabled = connected
    }

    private func selectedApp() -> VPhoneControl.AppInfo? {
        guard let index = list.listView.selectedIndex, index < apps.count else { return nil }
        return apps[index]
    }

    private func installIPA() {
        guard let control else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = VPhoneInstallPackage.allowedContentTypes
        panel.message = "Choose an .ipa / .tipa to install on the phone"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { @MainActor in
            for url in urls {
                statusField.stringValue = "installing \(url.lastPathComponent)..."
                do {
                    let result = try await control.installIPA(localURL: url)
                    EMLog.shared.write("apps: installed \(url.lastPathComponent): \(result)")
                    statusField.stringValue = VPhoneInstallPackage.successMessage(for: url.lastPathComponent, detail: result)
                } catch {
                    EMLog.shared.write("apps: install failed \(url.lastPathComponent): \(error)")
                    statusField.stringValue = "install failed: \(error)"
                }
            }
            load()
        }
    }

    private func launchSelected() {
        guard let control, let app = selectedApp() else { return }
        Task { @MainActor in
            do {
                _ = try await control.appLaunch(bundleId: app.bundleId)
                EMLog.shared.write("apps: launched \(app.bundleId)")
                load()
            } catch {
                EMLog.shared.write("apps: launch failed \(error)")
            }
        }
    }

    private func terminateSelected() {
        guard let control, let app = selectedApp() else { return }
        Task { @MainActor in
            do {
                try await control.appTerminate(bundleId: app.bundleId)
                EMLog.shared.write("apps: terminated \(app.bundleId)")
                load()
            } catch {
                EMLog.shared.write("apps: terminate failed \(error)")
            }
        }
    }

    private func openURL() {
        guard let control else { return }
        let alert = NSAlert()
        alert.messageText = "Open URL on Phone"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        field.placeholderString = "https://example.com"
        alert.accessoryView = field
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        Task { @MainActor in
            do {
                try await control.openURL(value)
                EMLog.shared.write("apps: opened \(value)")
            } catch {
                EMLog.shared.write("apps: open failed \(error)")
            }
        }
    }
}

// MARK: - SCREENSHOTS

@MainActor
final class EMScreenshotsPage: EMPageView {
    private let list = EMListBox()
    private let statusField = EMText.label("", size: 10, color: NSColor(calibratedWhite: 0.35, alpha: 1))
    private let captureButton = EMButton(title: "Capture Phone", kind: .primary, compact: true)
    private let refreshButton = EMButton(title: "Refresh", compact: true)
    private let openButton = EMButton(title: "Open Folder", compact: true)
    private let deleteButton = EMButton(title: "Delete", kind: .danger, compact: true)

    private var files: [URL] = []

    init(app: EMAppController?) {
        super.init(app: app, title: "Screenshots", subtitle: "Captured device screens. Double-click to open one.")
        list.translatesAutoresizingMaskIntoConstraints = false
        let toolbar = EMUI.toolbar([captureButton, refreshButton, openButton, EMUI.spacer(), deleteButton])
        let statusBar = EMUI.toolbar([statusField], height: 22)
        addSubview(toolbar)
        addSubview(list)
        addSubview(statusBar)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor, constant: 54),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            list.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 4),
            list.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            list.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            list.bottomAnchor.constraint(equalTo: statusBar.topAnchor, constant: -4),
            statusBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            statusBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            statusBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        captureButton.onAction = { [weak self] in self?.capture() }
        refreshButton.onAction = { [weak self] in self?.load() }
        openButton.onAction = { [weak self] in
            guard let url = self?.app?.screenshotsDirectory else { return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        deleteButton.onAction = { [weak self] in self?.deleteSelected() }
        list.listView.onActivate = { [weak self] index in
            guard let self, index < self.files.count else { return }
            NSWorkspace.shared.open(self.files[index])
        }
        list.listView.onSelectionChange = { [weak self] in self?.updateButtons() }
        list.listView.columnWidths = [120]
        list.listView.rowHeight = 46
    }

    required init?(coder: NSCoder) { fatalError() }

    override func refresh() { load() }

    private func load() {
        let directory = app?.screenshotsDirectory ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                includingPropertiesForKeys: [.contentModificationDateKey],
                                                                options: [.skipsHiddenFiles])) ?? []
        files = urls.filter { $0.pathExtension.lowercased() == "png" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
        list.listView.rows = files.map { url in
            let image = NSImage(contentsOf: url)
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            return EMRow(symbol: image == nil ? "photo" : nil, image: image?.emThumbnail(height: 44),
                         title: url.lastPathComponent, columns: [EMFormat.date(date)])
        }
        statusField.stringValue = "\(files.count) captures in \(directory.path)"
        updateButtons()
    }

    private func updateButtons() {
        captureButton.isEnabled = app?.canCaptureScreenshot ?? false
        deleteButton.isEnabled = list.listView.selectedIndex != nil
    }

    private func capture() {
        app?.captureActiveScreenshot { [weak self] message in
            self?.statusField.stringValue = message
            self?.load()
        }
    }

    private func deleteSelected() {
        guard let index = list.listView.selectedIndex, index < files.count else { return }
        try? FileManager.default.removeItem(at: files[index])
        load()
    }
}

// MARK: - SETUP

@MainActor
final class EMSetupPage: EMPageView {
    private let console = EMConsoleView()
    private let vmList = EMListBox()
    private let nameField = EMUI.field("myphone", width: 150)
    private let variantPopup = EMUI.popup(["jb", "regular", "dev", "exp", "less"], width: 96)
    private let createButton = EMButton(title: "Create Phone", kind: .primary, compact: true)
    private let cloneButton = EMButton(title: "Clone", compact: true)
    private let deleteButton = EMButton(title: "Delete", kind: .danger, compact: true)
    private let revealButton = EMButton(title: "Reveal", compact: true)
    private let usePhone1Button = EMButton(title: "Use as Phone 1", compact: true)
    private let usePhone2Button = EMButton(title: "Use as Phone 2", compact: true)
    private let preflightButton = EMButton(title: "Run Host Checks", kind: .primary, compact: true)
    private let refreshButton = EMButton(title: "Rescan", compact: true)
    private let clearButton = EMButton(title: "Clear", compact: true)

    private let sipLabel = EMText.label("SIP: checking...", size: 11.5)
    private let amfiLabel = EMText.label("AMFI: checking...", size: 11.5)
    private let engineLabel = EMText.label("Engine: ...", size: 11.5, color: EMPalette.textSecondary)
    private let libraryLabel = EMText.label("", size: 11.5, color: EMPalette.textSecondary)

    private var bundles: [VPhoneBundle] = []
    private var isLoading = false

    init(app: EMAppController?) {
        super.init(app: app, title: "Setup", subtitle: "Machine library, host requirements and the engine console")

        console.translatesAutoresizingMaskIntoConstraints = false
        vmList.translatesAutoresizingMaskIntoConstraints = false

        let hostPanel = EMUI.panel(title: "Host requirements", views: [
            sipLabel, amfiLabel, engineLabel,
            EMUI.toolbar([preflightButton, refreshButton], height: 34),
        ])
        let libraryPanel = EMUI.panel(title: "Virtual machines", views: [
            libraryLabel,
            EMUI.toolbar([EMText.caption("Name", size: 11), nameField, EMText.caption("Variant", size: 11),
                          variantPopup, createButton], height: 32),
            EMUI.toolbar([cloneButton, deleteButton, revealButton, EMUI.spacer(),
                          usePhone1Button, usePhone2Button], height: 32),
            vmList,
        ], fill: true)
        let consolePanel = EMUI.panel(title: "Engine console", views: [
            EMUI.toolbar([EMText.caption("Live output from the engine and the pipeline", size: 11), EMUI.spacer(), clearButton], height: 30),
            console,
        ], fill: true)

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        for view in [hostPanel, libraryPanel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(view)
        }
        consolePanel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        addSubview(consolePanel)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 58),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            row.heightAnchor.constraint(equalToConstant: 268),

            hostPanel.topAnchor.constraint(equalTo: row.topAnchor),
            hostPanel.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            hostPanel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            hostPanel.widthAnchor.constraint(equalToConstant: 356),

            libraryPanel.topAnchor.constraint(equalTo: row.topAnchor),
            libraryPanel.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            libraryPanel.leadingAnchor.constraint(equalTo: hostPanel.trailingAnchor, constant: 12),
            libraryPanel.trailingAnchor.constraint(equalTo: row.trailingAnchor),

            consolePanel.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 12),
            consolePanel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            consolePanel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            consolePanel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

            vmList.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),
            console.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])

        createButton.onAction = { [weak self] in self?.createVM() }
        cloneButton.onAction = { [weak self] in self?.cloneVM() }
        deleteButton.onAction = { [weak self] in self?.deleteVM() }
        revealButton.onAction = { [weak self] in self?.revealSelected() }
        usePhone1Button.onAction = { [weak self] in self?.useSelected(inSlot: 0) }
        usePhone2Button.onAction = { [weak self] in self?.useSelected(inSlot: 1) }
        preflightButton.onAction = { [weak self] in self?.runPreflight() }
        refreshButton.onAction = { [weak self] in
            self?.app?.refreshLibrary()
            self?.load()
        }
        clearButton.onAction = { [weak self] in self?.console.clear() }
        vmList.listView.emptyText = "No machines yet. Create one above."
        vmList.listView.showsDetail = false
        vmList.listView.columnWidths = [80, 150]
        vmList.listView.onSelectionChange = { [weak self] in
            guard let self, !self.isLoading else { return }
            self.updateButtons()
        }
        nameField.target = self
        nameField.action = #selector(nameChanged)

        EMLog.shared.onChange = { [weak self] in
            guard let self else { return }
            self.console.append(EMLog.shared.text)
        }
        console.append(EMLog.shared.text)
        load()
        checkHost()
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func nameChanged() {
        updateButtons()
    }

    override func refresh() {
        load()
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        bundles = app?.bundles ?? []
        let selectedName = selectedBundle()?.name
        vmList.listView.rows = bundles.map { bundle in
            EMRow(symbol: "internaldrive", title: bundle.name,
                  columns: [EMFormat.bytes(bundle.diskSizeBytes),
                            "\(bundle.manifest.cpuCount) CPU, \(bundle.manifest.memorySize / 1024 / 1024 / 1024) GB"],
                  tint: EMPalette.textSecondary)
        }
        if let selectedName, let index = bundles.firstIndex(where: { $0.name == selectedName }) {
            vmList.listView.selectedIndex = index
        } else if !bundles.isEmpty {
            vmList.listView.selectedIndex = 0
        }
        libraryLabel.stringValue = bundles.isEmpty
            ? "\(app?.libraryRoot.path ?? ""), no machines yet"
            : "\(bundles.count == 1 ? "1 machine" : "\(bundles.count) machines"), \(app?.libraryRoot.path ?? "")"
        engineLabel.stringValue = "Engine vphone-cli \(VPhoneBuildInfo.commitHash), \(VPhoneResources.resolve().base.lastPathComponent)"
        updateButtons()
    }

    private func updateButtons() {
        let hasSelection = selectedBundle() != nil
        cloneButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
        revealButton.isEnabled = hasSelection
        usePhone1Button.isEnabled = hasSelection
        usePhone2Button.isEnabled = hasSelection
        createButton.isEnabled = !(nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func selectedBundle() -> VPhoneBundle? {
        guard let index = vmList.listView.selectedIndex, index < bundles.count else { return nil }
        return bundles[index]
    }

    private func checkHost() {
        Task { @MainActor in
            let sip = await EMShell.capture("/usr/bin/csrutil", ["status"]).lowercased()
            if sip.contains("status: disabled") {
                sipLabel.stringValue = "SIP disabled (required)"
                sipLabel.textColor = EMPalette.ok
            } else if sip.contains("without debug") || sip.contains("custom configuration") {
                sipLabel.stringValue = "SIP only partly relaxed, allow-research-guests is missing"
                sipLabel.textColor = EMPalette.warn
            } else {
                sipLabel.stringValue = "SIP enabled, turn it off in Recovery first"
                sipLabel.textColor = EMPalette.bad
            }

            let bootArgs = await EMShell.capture("/usr/sbin/nvram", ["boot-args"])
            let bootArgsValue = bootArgs
                .replacingOccurrences(of: "boot-args", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if bootArgs.contains("amfi_get_out_of_my_way=1") {
                amfiLabel.stringValue = "AMFI relaxed (amfi_get_out_of_my_way=1)"
                amfiLabel.textColor = EMPalette.ok
            } else if !bootArgsValue.isEmpty {
                // show what IS set - a typo or a stale value is visible immediately
                amfiLabel.stringValue = "AMFI: wrong boot-args, \(bootArgsValue)"
                amfiLabel.textColor = EMPalette.bad
            } else {
                amfiLabel.stringValue = "AMFI: no boot-args set, use amfi_get_out_of_my_way=1 and reboot"
                amfiLabel.textColor = EMPalette.bad
            }
        }
    }

    private func runPreflight() {
        let resources = VPhoneResources.resolve()
        app?.runScript(resources.preflightScript, arguments: [], label: "host preflight")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.checkHost()
        }
    }

    private func createVM() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let variant = variantPopup.titleOfSelectedItem ?? "jb"
        Task { @MainActor in
            let ready = await self.hostIsReady()
            if !ready {
                let alert = NSAlert()
                alert.messageText = "This Mac is not ready yet"
                alert.informativeText = """
                Booting a virtual iPhone needs SIP and AMFI relaxed first:

                  1. Reboot into Recovery (hold the power button)
                  2. Open Terminal and run:
                     csrutil disable
                     csrutil allow-research-guests enable
                  3. Back in macOS:
                     sudo nvram boot-args="amfi_get_out_of_my_way=1"
                     then reboot

                The download and patch stages work without this, but the DFU restore and the first boot will fail. Continue anyway?
                """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Continue Anyway")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
            self.startCreate(name: name, variant: variant)
        }
    }

    private func hostIsReady() async -> Bool {
        let sip = await EMShell.capture("/usr/bin/csrutil", ["status"]).lowercased()
        let bootArgs = await EMShell.capture("/usr/sbin/nvram", ["boot-args"])
        let sipOK = sip.contains("status: disabled")
        let amfiOK = bootArgs.contains("amfi_get_out_of_my_way=1")
        return sipOK && amfiOK
    }

    private func startCreate(name: String, variant: String) {
        let alert = NSAlert()
        alert.messageText = "Create \(name)?"
        alert.informativeText = "Runs the full pipeline: firmware download and patch, DFU restore, CFW install and first boot (variant \(variant)). Several gigabytes are downloaded; macOS asks for your password once for the CFW step."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        EMLog.shared.write("setup: creating machine \(name) (variant \(variant))")
        // --root-popup: macOS shows its own admin dialog for the CFW mount,
        // so no terminal is needed for sudo.
        app?.runEngine(arguments: ["vm", "create", name, "-V", variant, "--root-popup"],
                       label: "vm create \(name) -V \(variant) --root-popup")
        pollLibrary()
    }

    private func cloneVM() {
        guard let bundle = selectedBundle() else { return }
        let target = "\(bundle.name)-2"
        let alert = NSAlert()
        alert.messageText = "Clone \(bundle.name) into \(target)?"
        alert.informativeText = "Fast APFS copy with a fresh device identity. Handy for running a second phone side by side."
        alert.addButton(withTitle: "Clone")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        app?.runEngine(arguments: ["vm", "clone", bundle.name, target], label: "vm clone \(bundle.name) \(target)")
        pollLibrary()
    }

    private func deleteVM() {
        guard let bundle = selectedBundle() else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \(bundle.name)?"
        alert.informativeText = "The whole bundle is removed from \(app?.libraryRoot.path ?? "~/.vphone/VMs")."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        app?.runEngine(arguments: ["vm", "delete", bundle.name], label: "vm delete \(bundle.name)")
        pollLibrary()
    }

    private func pollLibrary() {
        // `vm` commands run in a child process; rescan a few times as they finish.
        for delay in [1.0, 3.0, 8.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.app?.refreshLibrary()
                self?.load()
            }
        }
    }

    private func revealSelected() {
        guard let bundle = selectedBundle() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([bundle.url])
    }

    private func useSelected(inSlot slot: Int) {
        guard let bundle = selectedBundle() else { return }
        app?.setSlotVM(slot: slot, name: bundle.name)
    }
}

// MARK: - INFO

@MainActor
final class EMInfoPage: EMPageView {
    private let engineLabel = EMText.label("", size: 11.5)
    private let libraryField = EMUI.lcd("", width: 380)
    private let ipswField = EMUI.lcd("", width: 380)
    private let clipboardField = EMUI.field("", width: 320)
    private let sendClipboardButton = EMButton(title: "Send to Phone", kind: .primary, compact: true)
    private let fetchClipboardButton = EMButton(title: "Fetch from Phone", compact: true)
    private let statusField = EMText.label("", size: 11, color: EMPalette.textSecondary)
    private var phoneFields: [[EMReadOnlyField]] = []
    private let column = NSStackView()

    init(app: EMAppController?) {
        super.init(app: app, title: "Info", subtitle: "Connection details, paths and the clipboard bridge")

        column.orientation = .vertical
        column.spacing = 12
        column.alignment = .leading
        column.translatesAutoresizingMaskIntoConstraints = false

        let pathsPanel = EMUI.panel(title: "Paths", views: [
            engineLabel,
            EMUI.toolbar([EMText.caption("Machine library", size: 11), libraryField], height: 28),
            EMUI.toolbar([EMText.caption("Firmware cache", size: 11), ipswField], height: 28),
        ])

        let phonesStack = NSStackView()
        phonesStack.orientation = .vertical
        phonesStack.spacing = 10
        phonesStack.alignment = .width

        for index in 0..<2 {
            let vm = EMUI.lcd("-", width: 170)
            let udid = EMUI.lcd("-", width: 280)
            let ssh = EMUI.lcd("-", width: 300)
            let copyButton = EMButton(title: "Copy SSH", compact: true)
            copyButton.onAction = { [weak self] in
                guard let self, let info = self.app?.phoneInfo(slot: index) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(info.sshCommand, forType: .string)
                self.statusField.stringValue = "Copied: \(info.sshCommand)"
            }
            let title = EMText.label("Phone \(index + 1)", size: 12, bold: true)
            let row = NSStackView(views: [
                title,
                EMUI.toolbar([EMText.caption("Machine", size: 11), vm, EMText.caption("UDID", size: 11), udid], height: 28),
                EMUI.toolbar([EMText.caption("SSH", size: 11), ssh, copyButton], height: 28),
            ])
            row.orientation = .vertical
            row.spacing = 6
            row.alignment = .leading
            phonesStack.addArrangedSubview(row)
            phoneFields.append([vm, udid, ssh])
        }
        let phonesPanel = EMUI.panel(title: "Phones", views: [phonesStack])

        let clipboardPanel = EMUI.panel(title: "Clipboard", views: [
            EMUI.toolbar([clipboardField, sendClipboardButton, fetchClipboardButton], height: 30),
            statusField,
        ])

        for panel in [pathsPanel, phonesPanel, clipboardPanel] {
            column.addArrangedSubview(panel)
            panel.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        engineLabel.lineBreakMode = .byTruncatingMiddle
        engineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor, constant: 58),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
        ])

        sendClipboardButton.onAction = { [weak self] in self?.sendClipboard() }
        fetchClipboardButton.onAction = { [weak self] in self?.fetchClipboard() }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func refresh() {
        engineLabel.stringValue = "Engine vphone-cli \(VPhoneBuildInfo.commitHash), \(VPhoneResources.resolve().base.path)"
        libraryField.stringValue = app?.libraryRoot.path ?? "~/.vphone/VMs"
        ipswField.stringValue = VPhoneResources.resolve().ipswCacheDir.path
        guard let app else { return }
        for index in 0..<phoneFields.count {
            let info = app.phoneInfo(slot: index)
            let fields = phoneFields[index]
            fields[0].stringValue = info.vmName ?? "-"
            fields[1].stringValue = info.udid ?? "-"
            fields[2].stringValue = info.sshCommand
        }
        statusField.stringValue = app.activeControl?.isConnected == true
            ? "Phone \(app.activeSlotIndex + 1) is connected" : "Phone \(app.activeSlotIndex + 1) is offline"
    }

    override func phoneChanged() { refresh() }

    private func sendClipboard() {
        guard let control = app?.activeControl, control.isConnected else {
            statusField.stringValue = "No connected phone"
            return
        }
        let text = clipboardField.stringValue
        guard !text.isEmpty else { return }
        Task { @MainActor in
            do {
                try await control.clipboardSet(text: text)
                EMLog.shared.write("clipboard: sent \(text.count) characters")
                statusField.stringValue = "Clipboard sent"
            } catch {
                statusField.stringValue = "Clipboard send failed: \(error)"
            }
        }
    }

    private func fetchClipboard() {
        guard let control = app?.activeControl, control.isConnected else {
            statusField.stringValue = "No connected phone"
            return
        }
        Task { @MainActor in
            do {
                let content = try await control.clipboardGet()
                if let text = content.text {
                    clipboardField.stringValue = text
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    statusField.stringValue = "Fetched \(text.count) characters"
                } else if let data = content.imageData {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setData(data, forType: .tiff)
                    statusField.stringValue = "Fetched an image from the clipboard"
                } else {
                    statusField.stringValue = "Clipboard is empty"
                }
            } catch {
                statusField.stringValue = "Clipboard fetch failed: \(error)"
            }
        }
    }
}

// MARK: - Thumbnails

extension NSImage {
    func emThumbnail(height: CGFloat) -> NSImage {
        let ratio = size.width > 0 ? size.height / size.width : 1
        let target = NSSize(width: height / max(ratio, 0.001), height: height)
        let image = NSImage(size: target)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        EMPalette.faceDark.setStroke()
        NSBezierPath(rect: NSRect(origin: .zero, size: target).insetBy(dx: 0.5, dy: 0.5)).stroke()
        image.unlockFocus()
        return image
    }
}
