import AppKit
import Foundation
import Virtualization
import VPhoneCore

extension Notification.Name {
    static let emLogChanged = Notification.Name("emLogChanged")
    static let emStateChanged = Notification.Name("emStateChanged")
}

// MARK: - Shell helper

enum EMShell {
    static func capture(_ launchPath: String, _ arguments: [String], cwd: URL? = nil,
                        environment: [String: String]? = nil) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = arguments
                if let cwd { process.currentDirectoryURL = cwd }
                if let environment { process.environment = environment }
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                process.standardInput = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: "failed to run \(launchPath): \(error)")
                    return
                }
                let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
                process.waitUntilExit()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
        }
    }
}

// MARK: - Phone slot

@MainActor
final class EMPhoneSlot {
    let index: Int
    var bundleName: String?
    var variant: String = "jb"
    var state: EMPhoneState = .offline
    var vm: VPhoneVirtualMachine?
    var control: VPhoneControl?
    var keyHelper: VPhoneKeyHelper?
    var pane: EMPhonePaneView?
    var udid: String?
    var task: Task<Void, Never>?
    /// False when the bundle has no restored firmware (empty Disk.img): the VM
    /// boots into nothing, which otherwise looks like a black screen bug.
    var hasFirmware = true

    init(index: Int) { self.index = index }

    var title: String { "PHONE \(index + 1)" }
}

// MARK: - App controller

@MainActor
final class EMAppController: NSObject, NSApplicationDelegate {
    /// Strong reference for the NSApplication delegate (AppKit stores it weakly).
    static var retained: EMAppController?
    static var shared: EMAppController? { retained }

    struct PhoneInfo {
        var vmName: String?
        var udid: String?
        var ip: String?
        var sshCommand: String { "ssh -p 22222 mobile@<vm-ip>   # password: alpine" }
    }

    private(set) var slots: [EMPhoneSlot] = [EMPhoneSlot(index: 0), EMPhoneSlot(index: 1)]
    private(set) var activeSlotIndex = 0
    private(set) var bundles: [VPhoneBundle] = []
    var dualPhone = false

    let libraryRoot = VPhoneLibrary.defaultRoot()
    var library: VPhoneLibrary { VPhoneLibrary(root: libraryRoot) }
    let resources = VPhoneResources.resolve()
    private lazy var layout = VPhoneLaunchLayout(resources: resources)

    private(set) var windowController: EMMainWindowController?
    private var pipelines: [Process] = []

    var screenshotsDirectory: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("iPhoneEM", isDirectory: true)
    }

    var activeSlot: EMPhoneSlot { slots[min(activeSlotIndex, slots.count - 1)] }
    var activeControl: VPhoneControl? { activeSlot.control }
    var canCaptureScreenshot: Bool {
        activeSlot.pane?.screenView != nil && (activeSlot.state == .running || activeSlot.state == .linked)
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        try? FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)

        EMLog.shared.write("iPhoneEM started, engine \(VPhoneBuildInfo.commitHash)")
        EMLog.shared.write("library: \(libraryRoot.path)")

        let controller = EMMainWindowController(app: self)
        windowController = controller
        controller.showWindow()
        refreshLibrary()

        // pick sensible defaults: first VM in each slot
        if let first = bundles.first {
            setSlotVM(slot: 0, name: first.name, silent: true)
            if bundles.count > 1 {
                setSlotVM(slot: 1, name: bundles[1].name, silent: true)
            }
        }
        refreshUI()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closing the window must not stop a running phone: the VM lives in this
    /// process, so the app stays alive and the window can be brought back from
    /// the Dock or the Window menu. Quitting (Cmd Q) still stops the phones.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { windowController?.bringToFront() }
        return true
    }

    @objc func showWindowFromMenu() {
        windowController?.bringToFront()
    }

    func applicationWillTerminate(_ notification: Notification) {
        for slot in slots {
            slot.control?.cancelPendingRequests(reason: "app quiting")
            slot.vm?.virtualMachine.stop { _ in }
        }
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About iPhoneEM", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide iPhoneEM", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit iPhoneEM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Capture Active Phone", action: #selector(captureActiveFromMenu), keyEquivalent: "s")
        fileMenu.item(at: 0)?.target = self
        fileMenu.addItem(withTitle: "Rescan VM Library", action: #selector(rescanFromMenu), keyEquivalent: "r")
        fileMenu.item(at: 1)?.target = self
        fileItem.submenu = fileMenu

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        let showItem = NSMenuItem(title: "Show iPhoneEM Window", action: #selector(showWindowFromMenu), keyEquivalent: "1")
        showItem.target = self
        windowMenu.addItem(showItem)
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func captureActiveFromMenu() {
        captureActiveScreenshot { message in EMLog.shared.write("screenshot: \(message)") }
    }

    @objc private func rescanFromMenu() {
        refreshLibrary()
    }

    // MARK: Library

    func refreshLibrary() {
        do {
            bundles = try library.bundles()
            EMLog.shared.write("library: \(bundles.count) vm(s)")
        } catch {
            bundles = []
            EMLog.shared.write("library: scan failed \(error)")
        }
        // drop stale selections
        for slot in slots {
            if let name = slot.bundleName, !bundles.contains(where: { $0.name == name }) {
                slot.bundleName = nil
                if slot.vm == nil { slot.state = .empty }
            }
            if slot.bundleName == nil, slot.vm == nil {
                slot.state = .empty
            }
        }
        refreshUI()
    }

    func setSlotVM(slot index: Int, name: String?, silent: Bool = false) {
        guard index < slots.count else { return }
        let slot = slots[index]
        guard slot.vm == nil else {
            EMLog.shared.write("phone \(index + 1): stop the phone before switching its vm")
            return
        }
        if let name, let other = slots.first(where: { $0.index != index && $0.bundleName == name }) {
            EMLog.shared.write("phone \(index + 1): \(name) is already used by phone \(other.index + 1), pick another vm")
            return
        }
        slot.bundleName = name
        slot.udid = nil
        if let name {
            slot.state = .offline
            slot.udid = readUDID(name: name)
            slot.hasFirmware = guestIsInstalled(name: name)
            if !slot.hasFirmware {
                EMLog.shared.write("phone \(index + 1): \(name) has no firmware yet, run Create Phone in Setup")
            }
        } else {
            slot.state = .empty
        }
        if !silent {
            EMLog.shared.write("phone \(index + 1): vm = \(name ?? "none")")
        }
        refreshUI()
    }

    /// The engine restores iOS onto Disk.img; before that the sparse image has
    /// nothing allocated in it. A restored machine holds several GB.
    func guestIsInstalled(name: String) -> Bool {
        guard let bundle = try? library.bundle(named: name) else { return false }
        let disk = bundle.url.appendingPathComponent(bundle.manifest.diskImage)
        guard let values = try? disk.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else {
            return false
        }
        let allocated = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        return allocated > 1_000_000_000
    }

    private func readUDID(name: String) -> String? {
        let url = libraryRoot.appendingPathComponent(name).appendingPathComponent("udid-prediction.txt")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") where line.hasPrefix("UDID=") {
            return String(line.dropFirst(5))
        }
        return nil
    }

    func phoneInfo(slot index: Int) -> PhoneInfo {
        let slot = slots[index]
        var info = PhoneInfo()
        info.vmName = slot.bundleName
        info.udid = slot.udid
        if let ip = slot.control?.guestIP { info.ip = ip }
        return info
    }

    // MARK: Boot / stop

    func boot(slot index: Int) {
        guard index < slots.count else { return }
        let slot = slots[index]
        guard slot.vm == nil else { return }
        guard let name = slot.bundleName else {
            EMLog.shared.write("phone \(index + 1): no vm selected, pick one in Setup")
            return
        }
        slot.state = .booting
        refreshUI()
        EMLog.shared.write("phone \(index + 1): booting \(name)...")
        if !slot.hasFirmware {
            EMLog.shared.write("phone \(index + 1): warning, this machine has no firmware on its disk yet, so the screen will stay black. Run Create Phone in Setup first.")
        }

        slot.task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let bundle = try self.library.bundle(named: name)
                do {
                    _ = try self.layout.stageVphoned(into: bundle)
                } catch {
                    EMLog.shared.write("phone \(index + 1): warning: could not stage vphoned: \(error)")
                }
                let options = try self.makeOptions(bundle: bundle, variant: slot.variant)
                let vm = try VPhoneVirtualMachine(options: options)
                vm.shouldExitOnGuestStop = false
                vm.onGuestStopped = { [weak self] reason in
                    Task { @MainActor in
                        guard let self else { return }
                        EMLog.shared.write("phone \(index + 1): guest stopped (\(reason))")
                        self.teardown(slot: index)
                    }
                }
                slot.vm = vm
                self.attachPane(slot: slot, options: options)
                try await vm.start(forceDFU: false)
                slot.state = .running
                EMLog.shared.write("phone \(index + 1): vm running")
                self.attachControl(slot: slot, options: options, vm: vm)
            } catch {
                slot.state = .error("\(error)")
                EMLog.shared.write("phone \(index + 1): boot failed: \(error)")
                self.teardown(slot: index, keepError: true)
            }
            self.refreshUI()
        }
    }

    func stop(slot index: Int) {
        guard index < slots.count else { return }
        let slot = slots[index]
        guard let vm = slot.vm else { return }
        EMLog.shared.write("phone \(index + 1): stopping...")
        slot.control?.cancelPendingRequests(reason: "user stopped the phone")
        vm.virtualMachine.stop { [weak self] error in
            Task { @MainActor in
                if let error {
                    EMLog.shared.write("phone \(index + 1): stop error \(error)")
                } else {
                    EMLog.shared.write("phone \(index + 1): stopped")
                }
                self?.teardown(slot: index)
                self?.refreshUI()
            }
        }
    }

    private func teardown(slot index: Int, keepError: Bool = false) {
        guard index < slots.count else { return }
        let slot = slots[index]
        slot.control?.onConnect = nil
        slot.control?.onDisconnect = nil
        slot.control = nil
        slot.keyHelper = nil
        slot.vm = nil
        slot.pane?.detach()
        if !keepError {
            slot.state = slot.bundleName == nil ? .empty : .offline
        }
        refreshUI()
    }

    private func makeOptions(bundle: VPhoneBundle, variant: String) throws -> VPhoneVirtualMachine.Options {
        let manifest = bundle.manifest
        let directory = bundle.url
        let romURL = manifest.romImages.map { manifest.resolve(path: $0.avpBooter, in: directory) }
        let sepRomURL = manifest.romImages.map { manifest.resolve(path: $0.avpSEPBooter, in: directory) }
        return VPhoneVirtualMachine.Options(
            configURL: bundle.configURL,
            romURL: romURL,
            nvramURL: manifest.resolve(path: manifest.nvramStorage, in: directory),
            diskURL: manifest.resolve(path: manifest.diskImage, in: directory),
            cpuCount: Int(manifest.cpuCount),
            memorySize: manifest.memorySize,
            sepStorageURL: manifest.resolve(path: manifest.sepStorage, in: directory),
            sepRomURL: sepRomURL,
            screenWidth: manifest.screenConfig.width,
            screenHeight: manifest.screenConfig.height,
            screenPPI: manifest.screenConfig.pixelsPerInch,
            screenScale: manifest.screenConfig.scale,
            kernelDebugPort: nil,
            variant: VPhoneVirtualMachine.Variant(rawValue: variant) ?? .jb,
            noVphoned: false)
    }

    private func attachPane(slot: EMPhoneSlot, options: VPhoneVirtualMachine.Options) {
        guard let pane = slot.pane else { return }
        pane.configure(width: options.screenWidth, height: options.screenHeight, scale: options.screenScale)
    }

    private func attachControl(slot: EMPhoneSlot, options: VPhoneVirtualMachine.Options, vm: VPhoneVirtualMachine) {
        let control = VPhoneControl(variant: options.variant)
        let vphonedURL = layout.vphoned
        if FileManager.default.fileExists(atPath: vphonedURL.path) {
            control.guestBinaryURL = vphonedURL
        }
        let index = slot.index
        control.onConnect = { [weak self] caps in
            Task { @MainActor in
                guard let self else { return }
                slot.state = .linked
                // a guest reboot reconnects the control channel: re-attach the
                // display too, otherwise the bay can stay black after a restart
                slot.pane?.refreshDisplay()
                EMLog.shared.write("phone \(index + 1): guest link online (caps: \(caps.joined(separator: ",")))")
                if let ip = slot.control?.guestIP {
                    EMLog.shared.write("phone \(index + 1): guest ip \(ip), ssh -p 22222 mobile@\(ip)")
                }
                self.refreshUI()
            }
        }
        control.onDisconnect = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if slot.vm != nil, slot.state == .linked {
                    slot.state = .running
                    EMLog.shared.write("phone \(index + 1): guest link lost")
                }
                self.refreshUI()
            }
        }
        if let device = vm.virtualMachine.socketDevices.first as? VZVirtioSocketDevice {
            control.connect(device: device)
        }
        let keyHelper = VPhoneKeyHelper(vm: vm, control: control)
        slot.control = control
        slot.keyHelper = keyHelper
        if let pane = slot.pane {
            pane.attach(vm: vm.virtualMachine, control: control, keyHelper: keyHelper,
                        width: options.screenWidth, height: options.screenHeight, scale: options.screenScale)
        }
    }

    // MARK: Screenshots

    func captureActiveScreenshot(completion: @escaping (String) -> Void) {
        let slot = activeSlot
        guard let view = slot.pane?.screenView else {
            completion("no running phone in the bay")
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = screenshotsDirectory
            .appendingPathComponent("phone\(slot.index + 1)_\(formatter.string(from: Date())).png")
        let recorder = VPhoneScreenRecorder()
        Task { @MainActor in
            do {
                _ = try await recorder.saveScreenshot(view: view, to: url)
                EMLog.shared.write("screenshot: saved \(url.lastPathComponent)")
                completion("saved \(url.lastPathComponent)")
            } catch {
                EMLog.shared.write("screenshot: failed \(error)")
                completion("capture failed: \(error)")
            }
        }
    }

    // MARK: Pipeline commands

    func runEngine(arguments: [String], label: String) {
        let executable = VPhoneResources.runningExecutable()
        EMLog.shared.write("$ \(label)")
        runStreaming(executable: executable, arguments: arguments, cwd: resources.base, environment: nil)
    }

    func runScript(_ url: URL, arguments: [String], label: String) {
        EMLog.shared.write("$ \(label) (\(url.lastPathComponent))")
        var env = ProcessInfo.processInfo.environment
        env["VPHONE_CLI_BIN"] = VPhoneResources.runningExecutable().path
        runStreaming(executable: URL(fileURLWithPath: "/bin/zsh"), arguments: [url.path] + arguments,
                     cwd: resources.base, environment: env)
    }

    private func runStreaming(executable: URL, arguments: [String], cwd: URL?, environment: [String: String]?) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let cwd { process.currentDirectoryURL = cwd }
        if let environment { process.environment = environment }
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let handler: @Sendable (FileHandle) -> Void = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                for line in text.split(separator: "\n", omittingEmptySubsequences: false) where !line.isEmpty {
                    EMLog.shared.write(String(line))
                }
            }
        }
        pipe.fileHandleForReading.readabilityHandler = handler
        process.terminationHandler = { proc in
            Task { @MainActor in
                EMLog.shared.write("[exit \(proc.terminationStatus)] \(arguments.prefix(3).joined(separator: " "))")
                NotificationCenter.default.post(name: .emStateChanged, object: nil)
            }
        }
        do {
            try process.run()
            pipelines.append(process)
        } catch {
            EMLog.shared.write("failed to launch \(executable.lastPathComponent): \(error)")
        }
    }

    // MARK: UI coordination

    func refreshUI() {
        windowController?.reload(slots: slots, active: activeSlotIndex, dual: dualPhone)
        NotificationCenter.default.post(name: .emStateChanged, object: nil)
    }

    func setActiveSlot(_ index: Int) {
        guard index < slots.count, index != activeSlotIndex else { return }
        activeSlotIndex = index
        EMLog.shared.write("ui: active = phone \(index + 1)")
        refreshUI()
    }

    func setDualPhone(_ enabled: Bool) {
        dualPhone = enabled
        EMLog.shared.write("ui: two phones \(enabled ? "on" : "off")")
        refreshUI()
    }

    func pane(for slot: Int) -> EMPhonePaneView {
        let target = slots[slot]
        if let pane = target.pane { return pane }
        let pane = EMPhonePaneView(index: slot)
        pane.setVMName(target.bundleName)
        pane.state = target.state
        pane.onSelect = { [weak self] in self?.setActiveSlot(slot) }
        pane.onBoot = { [weak self] in self?.boot(slot: slot) }
        pane.onStop = { [weak self] in self?.stop(slot: slot) }
        pane.onHome = { [weak self] in
            _ = self
            EMLog.shared.write("phone \(slot + 1): home")
        }
        pane.onPower = { [weak self] in
            guard let control = self?.slots[slot].control, control.isConnected else { return }
            control.sendHIDPress(page: 0x0C, usage: 0x30)
        }
        pane.onVolumeUp = { [weak self] in
            guard let control = self?.slots[slot].control, control.isConnected else { return }
            control.sendHIDPress(page: 0x0C, usage: 0xE9)
        }
        pane.onVolumeDown = { [weak self] in
            guard let control = self?.slots[slot].control, control.isConnected else { return }
            control.sendHIDPress(page: 0x0C, usage: 0xEA)
        }
        pane.onRecents = { [weak self] in
            guard let pane = self?.slots[slot].pane, pane.hasScreen else { return }
            EMLog.shared.write("phone \(slot + 1): app switcher")
            pane.showAppSwitcher()
        }
        pane.onSnapshot = { [weak self] in
            guard let self else { return }
            self.setActiveSlot(slot)
            self.captureActiveScreenshot { message in EMLog.shared.write("screenshot: \(message)") }
        }
        pane.onPickVM = { [weak self] view in
            self?.showVMMenu(slot: slot, from: view)
        }
        target.pane = pane
        return pane
    }

    private func showVMMenu(slot: Int, from view: NSView) {
        refreshLibrary()
        let menu = NSMenu()
        for bundle in bundles {
            let item = NSMenuItem(title: bundle.name, action: #selector(vmMenuSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [slot, bundle.name]
            item.state = slots[slot].bundleName == bundle.name ? .on : .off
            menu.addItem(item)
        }
        if bundles.isEmpty {
            menu.addItem(withTitle: "no vms yet, create one in Setup", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let reveal = NSMenuItem(title: "Reveal VM Library...", action: #selector(revealLibrary), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.minY - 4), in: view)
    }

    @objc private func vmMenuSelected(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? [Any], payload.count == 2,
              let slot = payload[0] as? Int, let name = payload[1] as? String else { return }
        setSlotVM(slot: slot, name: name)
    }

    @objc private func revealLibrary() {
        try? FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([libraryRoot])
    }
}
