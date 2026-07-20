import AppKit
import SwiftUI
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "dev.iwai.UniEnter", category: "app")

    private var statusItem: NSStatusItem!
    private var statusMenuLine: NSMenuItem!
    private var enabledMenuItem: NSMenuItem!
    private let tapManager = EventTapManager()
    private let engine = RemapEngine()
    private let inputSourceMonitor = InputSourceMonitor()
    private let browserMonitor = BrowserTabMonitor()
    private let settingsStore = SettingsStore()
    private var permissionTimer: Timer?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    /// 書き換えを有効にするbundle IDの集合(UserDefaultsから読込・設定UIで更新)
    private var enabledBundleIDs: Set<String> = []
    /// 前面アプリ(NSWorkspace通知でキャッシュ)
    private var frontmostApp: NSRunningApplication?
    /// 前面ブラウザが対象サービスのWeb版を開いているとき、対応するアプリのbundle ID
    private var webServiceBundleID: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        enabledBundleIDs = settingsStore.enabledBundleIDs
        setupStatusItem()
        observeWorkspace()

        browserMonitor.isEnabled = settingsStore.browserSupportEnabled
        browserMonitor.onChange = { [weak self] serviceID in
            self?.webServiceBundleID = serviceID
            self?.recomputeTarget()
        }
        updateFrontmost(NSWorkspace.shared.frontmostApplication)

        engine.inputSourceChanged(isJapanese: inputSourceMonitor.isJapaneseMode)
        inputSourceMonitor.onChange = { [weak self] isJapanese in
            self?.engine.inputSourceChanged(isJapanese: isJapanese)
        }

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
                let wasComposing = engine.isComposing
                action = engine.keyDown(keycode: keycode, mods: mods, isPhysical: isPhysical)
                if keycode == 36 || keycode == 76 {
                    // 切り分け用: Enterの判定内訳を残す(log show で確認可能なnoticeレベル)
                    log.notice("return keyDown mods=\(mods.rawValue) physical=\(isPhysical) target=\(self.engine.isTargetAppActive) ja=\(self.engine.isJapaneseMode) composing=\(wasComposing) -> \(String(describing: action), privacy: .public)")
                }
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
            showOnboarding()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self, AXIsProcessTrusted() else { return }
                timer.invalidate()
                self.permissionTimer = nil
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                self.startTap()
            }
        }
    }

    private func showOnboarding() {
        guard onboardingWindow == nil else { return }
        let view = OnboardingView(
            openSystemSettings: {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            },
            requestPrompt: {
                // リストから削除された後に呼ぶと、現在のビルドで項目が登録し直される
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "UniEnter"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        center.addObserver(self, selector: #selector(appTerminated(_:)),
                           name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(machineDidWake),
                           name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(machineDidWake),
                           name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    @objc private func appActivated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updateFrontmost(app)
    }

    @objc private func appTerminated(_ note: Notification) {
        if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            browserMonitor.appTerminated(app)
        }
    }

    private func updateFrontmost(_ app: NSRunningApplication?) {
        frontmostApp = app
        browserMonitor.frontmostChanged(app)
        recomputeTarget()
        // 通知取りこぼしに備えて入力ソースも同期し直す
        inputSourceMonitor.refresh()
        engine.isJapaneseMode = inputSourceMonitor.isJapaneseMode
    }

    /// メニューに表示する現在の判定状態(切り分け用の診断表示)
    private var currentTargetLabel: String?

    /// ネイティブアプリ判定とブラウザWeb版判定を合成してエンジンへ反映する
    private func recomputeTarget() {
        let nativeID = frontmostApp?.bundleIdentifier.flatMap { enabledBundleIDs.contains($0) ? $0 : nil }
        let webID = webServiceBundleID.flatMap { enabledBundleIDs.contains($0) ? $0 : nil }
        engine.frontmostChanged(isTarget: nativeID != nil || webID != nil)

        if let id = nativeID {
            currentTargetLabel = AppRegistry.all.first { $0.bundleID == id }?.name ?? id
        } else if let id = webID {
            let name = AppRegistry.all.first { $0.bundleID == id }?.name ?? id
            currentTargetLabel = "\(name) (Web)"
        } else {
            currentTargetLabel = nil
        }
        updateStatusUI()
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
        let settingsItem = NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "UniEnterを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateStatusUI()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let model = SettingsViewModel(store: settingsStore)
            model.onEnabledAppsChange = { [weak self] ids in
                guard let self else { return }
                self.enabledBundleIDs = ids
                self.updateFrontmost(NSWorkspace.shared.frontmostApplication)
            }
            model.onBrowserSupportChange = { [weak self] enabled in
                self?.browserMonitor.isEnabled = enabled
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "UniEnter 設定"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
            if let label = currentTargetLabel {
                statusMenuLine.title = "動作中 — 対象: \(label)"
            } else {
                statusMenuLine.title = "動作中 — 前面は対象外"
            }
            statusItem.button?.image = NSImage(systemSymbolName: "return",
                                              accessibilityDescription: "UniEnter")
        } else {
            statusMenuLine.title = "停止中"
        }
    }
}
