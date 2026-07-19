import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "dev.iwai.UniEnter", category: "app")

    private var statusItem: NSStatusItem!
    private var statusMenuLine: NSMenuItem!
    private let tapManager = EventTapManager()
    private var permissionTimer: Timer?

    /// 前面アプリのbundle ID(NSWorkspace通知でキャッシュ。コールバックからはこれを参照)
    private var frontmostBundleID: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        observeWorkspace()
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        tapManager.handler = { [weak self] type, event in
            self?.handleEvent(type: type, event: event) ?? event
        }
        startTapWhenPermitted()
    }

    // MARK: - Event handling (M1: ログのみ)

    private func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        if type == .keyDown {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            log.debug("keyDown keycode=\(keycode) frontmost=\(self.frontmostBundleID ?? "nil", privacy: .public)")
        }
        return event
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
        frontmostBundleID = app?.bundleIdentifier
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
        menu.addItem(NSMenuItem(title: "UniEnterを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
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
