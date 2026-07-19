import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "dev.iwai.UniEnter", category: "app")

    private var statusItem: NSStatusItem!
    private var statusMenuLine: NSMenuItem!
    private var enabledMenuItem: NSMenuItem!
    private let tapManager = EventTapManager()
    private let engine = RemapEngine()
    private var permissionTimer: Timer?

    /// 書き換えを有効にするbundle IDの集合(M4でUserDefaults連動にする)
    private var enabledBundleIDs: Set<String> = AppRegistry.allBundleIDs

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        observeWorkspace()
        updateFrontmost(NSWorkspace.shared.frontmostApplication)

        tapManager.handler = { [weak self] type, event in
            self?.handleEvent(type: type, event: event) ?? event
        }
        startTapWhenPermitted()
    }

    // MARK: - Event handling

    private func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        switch type {
        case .leftMouseDown:
            engine.mouseDown()
            return event
        case .keyDown, .keyUp:
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let mods = Self.modifiers(from: event.flags)
            let action: RemapAction
            if type == .keyDown {
                let isPhysical = event.getIntegerValueField(.eventSourceStateID) == 1
                action = engine.keyDown(keycode: keycode, mods: mods, isPhysical: isPhysical)
            } else {
                action = engine.keyUp(keycode: keycode, mods: mods)
            }
            apply(action, to: event)
            return event
        default:
            return event
        }
    }

    private static func modifiers(from flags: CGEventFlags) -> RemapEngine.Modifiers {
        var mods: RemapEngine.Modifiers = []
        if flags.contains(.maskShift) { mods.insert(.shift) }
        if flags.contains(.maskCommand) { mods.insert(.command) }
        if flags.contains(.maskControl) { mods.insert(.control) }
        if flags.contains(.maskAlternate) { mods.insert(.option) }
        return mods
    }

    private func apply(_ action: RemapAction, to event: CGEvent) {
        switch action {
        case .passThrough:
            break
        case .addShift:
            event.flags.insert(.maskShift)
        case .stripCommand:
            var flags = event.flags
            flags.remove(.maskCommand)
            // デバイス依存のCmdビット(NX_DEVICELCMDKEYMASK / NX_DEVICERCMDKEYMASK)も除去
            flags.remove(CGEventFlags(rawValue: 0x8))
            flags.remove(CGEventFlags(rawValue: 0x10))
            event.flags = flags
        }
    }

    // MARK: - Accessibility permission

    private func startTapWhenPermitted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            startTap()
        } else {
            log.info("waiting for accessibility permission")
            updateStatusUI()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self, AXIsProcessTrusted() else { return }
                timer.invalidate()
                self.permissionTimer = nil
                self.startTap()
            }
        }
    }

    private func startTap() {
        if !tapManager.start() {
            // 許可直後はまだ失敗することがあるため再試行
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.tapManager.start()
                self?.updateStatusUI()
            }
        }
        updateStatusUI()
    }

    // MARK: - Workspace observation

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appActivated(_:)),
                           name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(machineDidWake),
                           name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(machineDidWake),
                           name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    @objc private func appActivated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updateFrontmost(app)
    }

    private func updateFrontmost(_ app: NSRunningApplication?) {
        let bundleID = app?.bundleIdentifier
        engine.frontmostChanged(isTarget: bundleID.map { enabledBundleIDs.contains($0) } ?? false)
    }

    @objc private func machineDidWake() {
        tapManager.ensureEnabled()
        updateStatusUI()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "return", accessibilityDescription: "UniEnter")

        let menu = NSMenu()
        statusMenuLine = NSMenuItem(title: "起動中…", action: nil, keyEquivalent: "")
        statusMenuLine.isEnabled = false
        menu.addItem(statusMenuLine)
        menu.addItem(.separator())
        enabledMenuItem = NSMenuItem(title: "有効", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledMenuItem.target = self
        enabledMenuItem.state = .on
        menu.addItem(enabledMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "UniEnterを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateStatusUI()
    }

    @objc private func toggleEnabled() {
        engine.isEnabled.toggle()
        enabledMenuItem.state = engine.isEnabled ? .on : .off
        updateStatusUI()
    }

    private func updateStatusUI() {
        guard statusMenuLine != nil else { return }
        if !AXIsProcessTrusted() {
            statusMenuLine.title = "アクセシビリティ権限が必要です"
            statusItem.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle",
                                              accessibilityDescription: "権限が必要")
        } else if tapManager.isRunning {
            statusMenuLine.title = "動作中"
            statusItem.button?.image = NSImage(systemSymbolName: "return",
                                              accessibilityDescription: "UniEnter")
        } else {
            statusMenuLine.title = "停止中"
        }
    }
}
