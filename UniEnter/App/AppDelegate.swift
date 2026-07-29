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
    private let licenseManager = LicenseManager()
    private var permissionTimer: Timer?
    private var entitlementTimer: Timer?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var licenseWindow: NSWindow?
    private var tutorialWindow: NSWindow?

    /// トライアル/ライセンスが有効か(コールバックはこのキャッシュのみ参照)
    private var isEntitled = true
    /// 直前に観測したライセンス状態。期限切れに「変わった瞬間」を捉えるために持つ
    private var lastLicenseState: LicenseState?

    /// デスクトップアプリで書き換えを有効にするサービス(UserDefaultsから読込・設定UIで更新)
    private var enabledDesktopIDs: Set<String> = []
    /// ブラウザ版で書き換えを有効にするサービス
    private var enabledWebIDs: Set<String> = []
    /// アプリ側の送信キーが⌘Enter(=既に統一挙動)のアプリ。書き換えを行わない
    private var cmdEnterSendApps: Set<String> = []
    /// アプリの設定ファイルから⌘Enter送信を自動検出したアプリ(手動宣言とは独立のキャッシュ)
    private var detectedCmdEnterSendApps: Set<String> = []
    private let sendKeyDetector = SendKeyDetector()
    /// 設定ファイル読み取り用。macOS 15+の許可ダイアログ待ちで open() が止まるため、
    /// 1アプリの停滞が他アプリの検出を巻き込まないよう並列にする
    private let sendKeyProbeQueue = DispatchQueue(
        label: "dev.iwai.UniEnter.sendkey-probe", qos: .utility, attributes: .concurrent)
    private var lastSendKeyProbe: [String: Date] = [:]
    /// 検出が空振り(unknown)に終わったアプリ。許可ダイアログの再表示を避けるため自動再試行しない
    private var sendKeyProbeGaveUp: Set<String> = []
    private var sendKeyProbeInFlight: Set<String> = []
    /// 設定ウィンドウのモデル(自動検出の結果表示を更新するために保持)
    private weak var settingsModel: SettingsViewModel?
    /// 前面アプリ(NSWorkspace通知でキャッシュ)
    private var frontmostApp: NSRunningApplication?
    /// 前面ブラウザが対象サービスのWeb版を開いているとき、対応するアプリのbundle ID
    private var webServiceBundleID: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // --screenshot-mode 起動時は常駐処理を一切始めず、全画面を書き出して終了する
        if ScreenshotMode.runIfRequested() { return }
        #endif

        enabledDesktopIDs = settingsStore.enabledDesktopIDs
        enabledWebIDs = settingsStore.enabledWebIDs
        cmdEnterSendApps = settingsStore.cmdEnterSendApps
        setupStatusItem()
        observeWorkspace()
        // 起動時には読まない。設定ファイルの初回アクセスでmacOSの許可ダイアログが出るため、
        // 「LINE/Slackを開いた直後」という文脈がある瞬間まで待つ(updateFrontmostから呼ぶ)

        browserMonitor.isEnabled = !enabledWebIDs.isEmpty
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

        refreshEntitlement()
        // 日付が変わってもトライアル残日数・期限切れが反映されるよう定期更新
        entitlementTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.refreshEntitlement()
        }
    }

    private func refreshEntitlement() {
        let state = licenseManager.state
        isEntitled = licenseManager.isEntitled
        updateStatusUI()

        // 期限切れになったら黙って止まらず必ず知らせる。
        // 「入れたまま忘れられて、何のアプリか分からない常駐」にしないための導線。
        // 起動時に既に期限切れの場合も lastLicenseState が nil なのでここで開く
        let wasExpired = lastLicenseState == .expired
        lastLicenseState = state
        if state == .expired && !wasExpired {
            openLicense()
        }
    }

    // MARK: - Event handling

    private func handleEvent(type: CGEventType, event: CGEvent) -> CGEvent? {
        // トライアル終了かつ未購入の間は一切書き換えない
        guard isEntitled else { return event }
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

    /// SwiftUIの内容にウィンドウサイズが追従するウィンドウを作る。
    ///
    /// `sizingOptions = [.preferredContentSize]` がないと、詳細オプションの開閉などで
    /// 内容が伸びたときにウィンドウが広がらず、本文が「…」で切れる。
    private func makeWindow(title: String, rootView: some View) -> NSWindow {
        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
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
        let window = makeWindow(title: "UniEnter", rootView: view)
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
                self?.maybeShowTutorial()
            }
        }
        updateStatusUI()
        maybeShowTutorial()
    }

    /// 初回のみ: タップが動き出したタイミングで使い方チュートリアルを表示する
    private func maybeShowTutorial() {
        guard tapManager.isRunning, !settingsStore.hasSeenTutorial else { return }
        settingsStore.hasSeenTutorial = true
        let view = TutorialView(
            openSettings: { [weak self] in self?.openSettings() },
            finish: { [weak self] in
                self?.tutorialWindow?.close()
                self?.tutorialWindow = nil
            }
        )
        let window = makeWindow(title: "UniEnterの使い方", rootView: view)
        tutorialWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        log.notice("frontmost: \(app?.bundleIdentifier ?? "nil", privacy: .public)")
        browserMonitor.frontmostChanged(app)
        // 対象アプリが前面に来たタイミングで送信キー設定を読み直す(設定変更の追従)
        if let id = app?.bundleIdentifier.map(AppRegistry.canonicalBundleID),
           enabledDesktopIDs.contains(id) {
            probeSendKey(for: id)
        }
        recomputeTarget()
        // 通知取りこぼしに備えて入力ソースも同期し直す
        inputSourceMonitor.refresh()
        engine.isJapaneseMode = inputSourceMonitor.isJapaneseMode
    }

    /// メニューに表示する現在の判定状態(切り分け用の診断表示)
    private var currentTargetLabel: String?

    /// ネイティブアプリ判定とブラウザWeb版判定を合成してエンジンへ反映する
    private func recomputeTarget() {
        let nativeID = frontmostApp?.bundleIdentifier
            .map(AppRegistry.canonicalBundleID)
            .flatMap { enabledDesktopIDs.contains($0) ? $0 : nil }
        let webID = webServiceBundleID.flatMap { enabledWebIDs.contains($0) ? $0 : nil }

        // アプリ側の送信キーが⌘Enterのアプリは既に統一挙動なので書き換えない。
        // 手動宣言と自動検出(SendKeyDetector)の和集合で判定する。
        // (Web版はワークスペース/アカウントごとに設定が独立しているため対象外にしない)
        let passthroughApps = cmdEnterSendApps.union(detectedCmdEnterSendApps)
        let nativeNeedsRemap = nativeID.map { !passthroughApps.contains($0) } ?? false
        engine.frontmostChanged(isTarget: nativeNeedsRemap || webID != nil)

        if let id = nativeID {
            let name = AppRegistry.all.first { $0.bundleID == id }?.name ?? id
            if detectedCmdEnterSendApps.contains(id) {
                currentTargetLabel = "\(name)(⌘Enter送信を自動検出・素通し)"
            } else if cmdEnterSendApps.contains(id) {
                currentTargetLabel = "\(name)(⌘Enter送信設定・素通し)"
            } else {
                currentTargetLabel = name
            }
        } else if let id = webID {
            let name = AppRegistry.all.first { $0.bundleID == id }?.name ?? id
            currentTargetLabel = "\(name) (Web)"
        } else {
            currentTargetLabel = nil
        }
        updateStatusUI()
    }

    /// LINE/Slackの設定ファイルを読み、⌘Enter送信なら自動素通しに反映する。
    ///
    /// 読み取りは専用キューでのみ行う(タップコールバックからは呼ばない)。
    /// macOS 15+では他アプリのコンテナへの初回アクセスで許可ダイアログが出て、
    /// ユーザーが答えるまで `open()` がブロックしたままになるため:
    /// - 起動時ではなく、そのアプリを実際に開いた直後にだけ読む(ダイアログに文脈を与える)
    /// - 拒否・失敗(unknown)なら自動では再試行しない(ダイアログを繰り返さない)。
    ///   設定画面の「LINE・Slackの設定を読み直す」からは force で再試行できる
    private func probeSendKey(for bundleID: String, force: Bool = false) {
        guard SendKeyDetector.supportedBundleIDs.contains(bundleID) else { return }
        guard !sendKeyProbeInFlight.contains(bundleID) else { return }
        if force {
            sendKeyProbeGaveUp.remove(bundleID)
        } else {
            guard !sendKeyProbeGaveUp.contains(bundleID) else { return }
            // アプリ切替のたびには走らせない(ファイル列挙を伴うため)
            if let last = lastSendKeyProbe[bundleID], Date().timeIntervalSince(last) < 30 { return }
        }
        lastSendKeyProbe[bundleID] = Date()
        sendKeyProbeInFlight.insert(bundleID)
        sendKeyProbeQueue.async { [weak self] in
            guard let self else { return }
            let detection = self.sendKeyDetector.detect(bundleID: bundleID)
            DispatchQueue.main.async {
                self.sendKeyProbeInFlight.remove(bundleID)
                if detection == .unknown { self.sendKeyProbeGaveUp.insert(bundleID) }
                self.log.notice("sendkey autodetect \(bundleID, privacy: .public): \(String(describing: detection), privacy: .public)")

                let detected = detection == .cmdEnterSend
                guard detected != self.detectedCmdEnterSendApps.contains(bundleID) else { return }
                if detected {
                    self.detectedCmdEnterSendApps.insert(bundleID)
                } else {
                    self.detectedCmdEnterSendApps.remove(bundleID)
                }
                self.settingsModel?.detectedCmdEnterSendApps = self.detectedCmdEnterSendApps
                self.recomputeTarget()
            }
        }
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
        let licenseItem = NSMenuItem(title: "ライセンス…", action: #selector(openLicense), keyEquivalent: "")
        licenseItem.target = self
        menu.addItem(licenseItem)
        let diagItem = NSMenuItem(title: "ブラウザ判定を診断(ログ出力)", action: #selector(dumpBrowserDiagnostics), keyEquivalent: "")
        diagItem.target = self
        menu.addItem(diagItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "UniEnterを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateStatusUI()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let model = SettingsViewModel(store: settingsStore)
            model.onDesktopIDsChange = { [weak self] ids in
                guard let self else { return }
                let added = ids.subtracting(self.enabledDesktopIDs)
                self.enabledDesktopIDs = ids
                // 新たに有効化されたLINE/Slackはすぐ検出を走らせる
                for id in added where SendKeyDetector.supportedBundleIDs.contains(id) {
                    self.probeSendKey(for: id, force: true)
                }
                self.updateFrontmost(NSWorkspace.shared.frontmostApplication)
            }
            model.onWebIDsChange = { [weak self] ids in
                guard let self else { return }
                self.enabledWebIDs = ids
                self.browserMonitor.isEnabled = !ids.isEmpty
                self.updateFrontmost(NSWorkspace.shared.frontmostApplication)
            }
            model.onCmdEnterSendAppsChange = { [weak self] ids in
                self?.cmdEnterSendApps = ids
                self?.recomputeTarget()
            }
            model.onRecheckSendKeys = { [weak self] in
                guard let self else { return }
                for id in SendKeyDetector.supportedBundleIDs where self.enabledDesktopIDs.contains(id) {
                    self.probeSendKey(for: id, force: true)
                }
            }
            model.detectedCmdEnterSendApps = detectedCmdEnterSendApps
            settingsModel = model
            settingsWindow = makeWindow(title: "UniEnter 設定", rootView: SettingsView(model: model))
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLicense() {
        if licenseWindow == nil {
            let model = LicenseViewModel(manager: licenseManager)
            model.onActivated = { [weak self] in
                self?.refreshEntitlement()
            }
            licenseWindow = makeWindow(title: "UniEnter ライセンス", rootView: LicenseView(model: model))
        }
        licenseWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func dumpBrowserDiagnostics() {
        browserMonitor.dumpDiagnostics()
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
        } else if !isEntitled {
            statusMenuLine.title = "トライアル終了 — 停止中(ライセンス…から購入)"
            statusItem.button?.image = NSImage(systemSymbolName: "exclamationmark.triangle",
                                              accessibilityDescription: "トライアル終了")
        } else if tapManager.isRunning {
            var title: String
            if let label = currentTargetLabel {
                title = "動作中 — 対象: \(label)"
            } else {
                title = "動作中 — 前面は対象外"
            }
            if case .trial(let daysLeft) = licenseManager.state {
                title += "(試用あと\(daysLeft)日)"
            }
            statusMenuLine.title = title
            statusItem.button?.image = NSImage(systemSymbolName: "return",
                                              accessibilityDescription: "UniEnter")
        } else {
            statusMenuLine.title = "停止中"
        }
    }
}
