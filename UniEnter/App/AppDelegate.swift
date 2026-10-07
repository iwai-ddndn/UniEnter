import AppKit
import SwiftUI
import os
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "dev.iwai.UniEnter", category: "app")

    private var statusItem: NSStatusItem!
    private var statusMenuLine: NSMenuItem!
    private var pauseMenuItem: NSMenuItem!
    /// サポート用の診断項目。Optionキーを押しながらメニューを開いたときだけ出す
    private var diagMenuItem: NSMenuItem!
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
    /// アプリ内アップデート(Sparkle)。自動確認はしない(Info.plist の SUEnableAutomaticChecks = NO)。
    /// 通信するのはメニューの「アップデートを確認…」を押したときだけ
    private var updaterController: SPUStandardUpdaterController?

    /// トライアル/ライセンスが有効か(コールバックはこのキャッシュのみ参照)
    private var isEntitled = true
    /// 直前に観測したライセンス状態。期限切れに「変わった瞬間」を捉えるために持つ
    private var lastLicenseState: LicenseState?

    /// デスクトップアプリで書き換えを有効にするサービス(UserDefaultsから読込・設定UIで更新)
    private var enabledDesktopIDs: Set<String> = []
    /// ブラウザ版で書き換えを有効にするサービス
    private var enabledWebIDs: Set<String> = []
    /// アプリ自身の設定でEnter=改行(送信キー=⌘Enter)になっている(=既に統一挙動)アプリ。書き換えを行わない
    private var cmdEnterSendApps: Set<String> = []
    /// アプリの設定ファイルから読み取った送信キー設定(手動宣言とは独立のキャッシュ)。
    /// bundle IDごとのtri-state。未検出のアプリはキー自体が無い(= .unknown 相当)
    private var sendKeyDetections: [String: SendKeyDetection] = [:]
    /// Enter=改行の設定を自動検出できたアプリ(素通し対象)
    private var detectedCmdEnterSendApps: Set<String> {
        Set(sendKeyDetections.filter { $0.value == .cmdEnterSend }.keys)
    }
    /// 「Enter=送信」の既定のままと自動検出できたアプリ。手動宣言があっても素通しにしない
    private var detectedStandardApps: Set<String> {
        Set(sendKeyDetections.filter { $0.value == .standard }.keys)
    }
    private let sendKeyDetector = SendKeyDetector()
    /// 設定ファイル読み取り用。macOS 15+の許可ダイアログ待ちで open() が止まるため、
    /// 1アプリの停滞が他アプリの検出を巻き込まないよう並列にする
    private let sendKeyProbeQueue = DispatchQueue(
        label: "dev.iwai.UniEnter.sendkey-probe", qos: .utility, attributes: .concurrent)
    private var lastSendKeyProbe: [String: Date] = [:]
    /// 検出が空振り(unknown)に終わったアプリ。許可ダイアログの再表示を避けるため自動再試行しない
    private var sendKeyProbeGaveUp: Set<String> = []
    private var sendKeyProbeInFlight: Set<String> = []
    /// 設定・チュートリアルで共有するビューモデル(初回利用時に生成し、以後使い回す)
    private var settingsModel: SettingsViewModel?
    /// 前面アプリ(NSWorkspace通知でキャッシュ)
    private var frontmostApp: NSRunningApplication?
    /// 前面ブラウザが対象サービスのWeb版を開いているとき、対応するアプリのbundle ID
    private var webServiceBundleID: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Explicit support modes never prompt for permission or touch user state.
        if CommandLine.arguments.contains("--verify-existing-accessibility") {
            let trusted = AXIsProcessTrusted()
            print("existingAccessibilityTrusted=\(trusted)")
            exit(trusted ? 0 : 2)
        }
        #if DEBUG
        // --screenshot-mode 起動時は常駐処理を一切始めず、全画面を書き出して終了する
        if ScreenshotMode.runIfRequested() { return }
        #endif

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
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
        // 許可済み・初期設定済みの通常起動にも目に見える入口を用意する。
        if AXIsProcessTrusted(), settingsStore.hasSeenTutorial,
           ![onboardingWindow, tutorialWindow, licenseWindow].contains(where: { $0?.isVisible == true }) {
            openSettings()
        }
        // 日付が変わってもトライアル残日数・期限切れが反映されるよう定期更新
        entitlementTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.refreshEntitlement()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !AXIsProcessTrusted() {
            showOnboarding()
            waitForPermission()
        } else if !licenseManager.isEntitled {
            openLicense()
        } else if let tutorialWindow, tutorialWindow.isVisible {
            showTutorial()
        } else {
            openSettings()
        }
        return false
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
            // Stop using the old browser input immediately, without AX or UI work.
            if browserMonitor.notePointerActivity() {
                engine.targetAvailabilityChanged(isTarget: false)
            }
            return event
        case .keyDown, .keyUp:
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let mods = Self.modifiers(from: event.flags)
            let action: RemapAction
            if type == .keyDown {
                let isPhysical = event.getIntegerValueField(.eventSourceStateID) == 1
                if isPhysical && RemapEngine.isTextInputActivity(keycode: keycode, mods: mods) {
                    browserMonitor.noteTypingActivity()
                }
                let wasComposing = engine.isComposing
                let wasSuggesting = engine.isSuggesting
                action = engine.keyDown(
                    keycode: keycode, mods: mods, isPhysical: isPhysical,
                    characters: Self.characters(of: event)
                )
                if keycode == 36 || keycode == 76 {
                    // 切り分け用: Enterの判定内訳を残す(log show で確認可能なnoticeレベル)
                    log.notice("return keyDown mods=\(mods.rawValue) physical=\(isPhysical) target=\(self.engine.isTargetAppActive) ja=\(self.engine.isJapaneseMode) composing=\(wasComposing) suggesting=\(wasSuggesting) -> \(String(describing: action), privacy: .public)")
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

    /// キーボード配列上でそのキーが生成する文字(IMEを通す前の値)。候補ポップアップの
    /// トリガー文字(`@`等)判定用。イベント自身が持つデータの読み出しでIPCは発生しない
    private static func characters(of event: CGEvent) -> String {
        var buffer = [UniChar](repeating: 0, count: 4)
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return "" }
        return String(utf16CodeUnits: buffer, count: length)
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
            waitForPermission()
        }
    }

    /// 許可されるまで1秒ごとに確認し、許可されたら案内を閉じてタップを始める
    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted() else { return }
            timer.invalidate()
            self.permissionTimer = nil
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            self.startTap()
        }
    }

    /// 起動後に許可が外れたとき(アップデート・再インストール等)にメニューから呼ぶ
    @objc private func requestPermissionAgain() {
        showOnboarding()
        waitForPermission()
    }

    /// タップが止まっているときにメニューから再開する
    @objc private func restartTap() {
        startTap()
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
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
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
        showTutorial()
    }

    @objc private func showTutorial() {
        if let tutorialWindow {
            tutorialWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = TutorialView(
            model: ensureSettingsModel(),
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
        engine.frontmostChanged(isTarget: false)
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

    /// メニューのステータス行に出す、いまの判定(前面が対象外なら nil)
    private var currentTargetLabel: String?

    /// ネイティブアプリ判定とブラウザWeb版判定を合成してエンジンへ反映する
    private func recomputeTarget() {
        let nativeID = frontmostApp?.bundleIdentifier
            .map(AppRegistry.canonicalBundleID)
            .flatMap { enabledDesktopIDs.contains($0) ? $0 : nil }
        let webID = webServiceBundleID.flatMap { enabledWebIDs.contains($0) ? $0 : nil }

        // アプリ自身の設定でEnter=改行になっているアプリは既に統一挙動なので書き換えない。
        // 手動宣言と自動検出(SendKeyDetector)の和集合で判定するが、自動検出が「既定のまま
        // (Enter=送信)」と分かっているアプリは、古い/誤った手動宣言が残っていても素通しにしない。
        // (Web版はワークスペース/アカウントごとに設定が独立しているため対象外にしない)
        let passthroughApps = AppRegistry.passthroughApps(declared: cmdEnterSendApps,
            detectedCmdEnter: detectedCmdEnterSendApps, detectedStandard: detectedStandardApps)
        let nativeNeedsRemap = nativeID.map { !passthroughApps.contains($0) } ?? false
        engine.targetAvailabilityChanged(isTarget: nativeNeedsRemap || webID != nil)

        if let id = nativeID {
            let name = AppRegistry.all.first { $0.bundleID == id }?.name ?? id
            if passthroughApps.contains(id) {
                currentTargetLabel = "\(name) — アプリ側の設定(Enterで改行)のまま"
            } else {
                currentTargetLabel = "動作中 — \(name)"
            }
        } else if let id = webID {
            let name = AppRegistry.all.first { $0.bundleID == id }?.name ?? id
            currentTargetLabel = "動作中 — \(name)(ブラウザ版)"
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
                self.log.notice("sendkey autodetect \(bundleID, privacy: .public): \(String(describing: detection), privacy: .public)")

                let previous = self.sendKeyDetections[bundleID] ?? .unknown
                // 一度読めた結果を一時的な読み取り失敗(アプリが設定ファイルを書き換え中など)で
                // unknown に落とさない。落とすと手動宣言へフォールバックし、⌘Enter送信設定の
                // LINEで⌘Enterが改行に化ける。読めた実績がある=許可ダイアログは済んでいるので、
                // 諦めずに次回また読む
                if detection == .unknown {
                    if previous == .unknown { self.sendKeyProbeGaveUp.insert(bundleID) }
                    return
                }
                guard detection != previous else { return }
                self.sendKeyDetections[bundleID] = detection
                self.settingsModel?.detectedSendKeys[bundleID] = detection
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
        // ステータス行は状態によって押せる/押せないを切り替えるので自動有効化を切る
        menu.autoenablesItems = false
        menu.delegate = self
        statusMenuLine = NSMenuItem(title: "起動中…", action: nil, keyEquivalent: "")
        statusMenuLine.target = self
        statusMenuLine.isEnabled = false
        menu.addItem(statusMenuLine)
        menu.addItem(.separator())
        pauseMenuItem = NSMenuItem(title: "一時停止", action: #selector(toggleEnabled), keyEquivalent: "")
        pauseMenuItem.target = self
        pauseMenuItem.state = .off
        menu.addItem(pauseMenuItem)
        let settingsItem = NSMenuItem(title: "設定…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let tutorialItem = NSMenuItem(title: "使い方…", action: #selector(showTutorial), keyEquivalent: "")
        tutorialItem.target = self
        menu.addItem(tutorialItem)
        let sendKeyHelpItem = NSMenuItem(title: "⌘Enterで送信できないとき…", action: #selector(openSendKeyHelp), keyEquivalent: "")
        sendKeyHelpItem.target = self
        menu.addItem(sendKeyHelpItem)
        let licenseItem = NSMenuItem(title: "ライセンス…", action: #selector(openLicense), keyEquivalent: "")
        licenseItem.target = self
        menu.addItem(licenseItem)
        if let updaterController {
            let updateItem = NSMenuItem(title: "アップデートを確認…",
                                        action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                                        keyEquivalent: "")
            updateItem.target = updaterController
            menu.addItem(updateItem)
        }
        diagMenuItem = NSMenuItem(title: "Chrome入力判定を記録（30秒・本文なし）", action: #selector(dumpBrowserDiagnostics), keyEquivalent: "")
        diagMenuItem.target = self
        diagMenuItem.isHidden = true
        menu.addItem(diagMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "UniEnterを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateStatusUI()
    }

    /// 設定・チュートリアルで共有するビューモデルを(なければ作って)返す
    private func ensureSettingsModel() -> SettingsViewModel {
        if let settingsModel { return settingsModel }
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
        model.openApp = { [weak self] bundleID in
            guard let self else { return }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
            // ユーザーが「確認しにいく」を押した直後なら、読み取り許可ダイアログに
            // 文脈があるので、LINE/Slackはこのタイミングで自動検出を走らせる
            self.probeSendKey(for: bundleID, force: true)
        }
        model.isAppInstalled = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
        model.detectedSendKeys = sendKeyDetections
        settingsModel = model
        return model
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: "UniEnter 設定",
                                        rootView: SettingsView(model: ensureSettingsModel()))
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 「⌘Enterで送信できないとき…」: 設定画面を、該当の項目を開いた状態で出す
    @objc private func openSendKeyHelp() {
        ensureSettingsModel().showAdvanced = true
        openSettings()
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
        let prompt = NSAlert()
        prompt.messageText = "通常の入力判定を30秒間記録します"
        prompt.informativeText = "開始後にChromeの別ページからGeminiを開き、入力欄をクリックして短いダミー文字を一度入力してください。Enterは押さず、送信しないでください。通常処理の通知と判定、文字入力があった事実だけを記録します。文字・キーコード・タイトル・URLは保存せず、診断用の追加AX問い合わせも行いません。30秒後にこのMacへ保存します。"
        prompt.addButton(withTitle: "開始")
        prompt.addButton(withTitle: "キャンセル")
        guard prompt.runModal() == .alertFirstButtonReturn else { return }
        browserMonitor.onDiagnosticFinished = { file in
            let result = NSAlert()
            result.messageText = file == nil ? "診断結果を保存できませんでした" : "診断が終了しました"
            result.informativeText = "自動送信はしていません。"
            if file != nil { result.addButton(withTitle: "ファイルを表示") }
            result.addButton(withTitle: "閉じる")
            if result.runModal() == .alertFirstButtonReturn, let file {
                NSWorkspace.shared.activateFileViewerSelecting([file])
            }
        }
        if !browserMonitor.startMetadataDiagnostics() {
            let result = NSAlert()
            result.messageText = "診断を開始できません"
            result.informativeText = "既存のアクセシビリティ許可が無効、または診断中です。権限設定は変更していません。"
            result.runModal()
        }
    }

    @objc private func toggleEnabled() {
        engine.isEnabled.toggle()
        pauseMenuItem.state = engine.isEnabled ? .off : .on
        updateStatusUI()
    }

    /// ステータス行とメニューバーアイコンを今の状態に合わせる。
    /// 「止まっているのに動いているように見える」ことが一番の事故の元なので、
    /// 止まっている状態は必ず言葉とアイコンで示し、直せるものは行を押して直せるようにする
    private func updateStatusUI() {
        guard statusMenuLine != nil else { return }
        func set(_ title: String, symbol: String, action: Selector? = nil) {
            statusMenuLine.title = title
            statusMenuLine.action = action
            statusMenuLine.isEnabled = action != nil
            statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        }
        if !AXIsProcessTrusted() {
            set("アクセシビリティの許可が必要です — 許可する…", symbol: "exclamationmark.triangle",
                action: #selector(requestPermissionAgain))
        } else if !isEntitled {
            set("トライアル終了 — Enterは各アプリ本来の動きです", symbol: "exclamationmark.triangle",
                action: #selector(openLicense))
        } else if !engine.isEnabled {
            set("一時停止中 — Enterは各アプリ本来の動きです", symbol: "pause.circle")
        } else if tapManager.isRunning {
            var title = currentTargetLabel ?? "待機中 — いまのアプリは対象外"
            if case .trial(let daysLeft) = licenseManager.state {
                title += "(無料トライアル あと\(daysLeft)日)"
            }
            set(title, symbol: "return")
        } else {
            set("停止中 — クリックで再開", symbol: "exclamationmark.triangle", action: #selector(restartTap))
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // 許可が外れた等の変化を、メニューを開いた時点で必ず反映する
        updateStatusUI()
        diagMenuItem.isHidden = !NSEvent.modifierFlags.contains(.option)
    }
}
