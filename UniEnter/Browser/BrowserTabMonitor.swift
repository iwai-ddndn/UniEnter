import AppKit
import ApplicationServices
import os

/// 前面ブラウザのアクティブタブが対象チャットサービスのWeb版かをAX APIのみで判定する。
///
/// - 追加権限は不要(アクセシビリティ権限に含まれる。Apple Eventsは使わない)
/// - CGEventTapコールバックからは一切呼ばれない。タブ切替等のAXObserver通知を契機に
///   専用キューで非同期に評価し、結果をメインスレッドの `onChange` で通知する
/// - 判定不能・取得失敗時は常に nil(=書き換えない)側へ倒す
final class BrowserTabMonitor {
    private let log = Logger(subsystem: "dev.iwai.UniEnter", category: "browser")

    /// 対象サービスのWeb版を開いているとき、対応するデスクトップアプリのbundle ID。
    private(set) var webServiceBundleID: String?
    var onChange: ((String?) -> Void)?

    var isEnabled = true {
        didSet {
            guard oldValue != isEnabled else { return }
            if isEnabled { refresh() } else {
                stopRefreshing()
                publish(nil)
            }
        }
    }

    private let axQueue = DispatchQueue(label: "dev.iwai.UniEnter.browser-ax", qos: .userInitiated)
    private var observers: [pid_t: AXObserver] = [:]
    private var frontBrowser: (pid: pid_t, kind: BrowserKind)?
    private var refreshPolicy = BrowserRefreshPolicy()
    private var refreshTimer: Timer?
    private var immediateRefreshScheduled = false
    private var typingPending = false
    private var pointerPending = false
    private var passiveTrace = BrowserPassiveTrace()
    private var diagnosticTimer: Timer?
    private var diagnosticToken: UUID?
    var onDiagnosticFinished: ((URL?) -> Void)?

    init() {
        // ビジーなブラウザへのAX問い合わせで長時間ブロックしないよう、
        // このプロセスのAXメッセージ既定タイムアウトを短くする
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
    }

    // MARK: - 入力(メインスレッドから呼ぶ)

    func frontmostChanged(_ app: NSRunningApplication?) {
        if let app, let bundleID = app.bundleIdentifier,
           let kind = BrowserRegistry.browsers[bundleID] {
            refreshPolicy.setActive(false, now: ProcessInfo.processInfo.systemUptime)
            typingPending = false
            pointerPending = false
            frontBrowser = (app.processIdentifier, kind)
            passiveTrace.record(.activated, now: ProcessInfo.processInfo.systemUptime)
            attachObserver(pid: app.processIdentifier)
            refresh()
        } else {
            frontBrowser = nil
            stopRefreshing()
            publish(nil)
        }
    }

    func appTerminated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        if frontBrowser?.pid == pid {
            frontBrowser = nil
            stopRefreshing()
            publish(nil)
        }
    }

    /// 現在の前面ブラウザを再評価する(AXObserver通知・設定変更などから)
    func refresh() {
        guard isEnabled, frontBrowser != nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if !refreshPolicy.active { refreshPolicy.setActive(true, now: now) }
        else { refreshPolicy.invalidate(now: now) }
        passiveTrace.record(.invalidated, now: now, generation: refreshPolicy.generation)
        publish(nil)
        startRefreshTimer()
        scheduleImmediateRefresh()
    }

    /// Coalesce notifications within this run-loop turn, not behind a 100ms timer.
    /// Never called by the event-tap callbacks. AX remains asynchronous on axQueue.
    private func scheduleImmediateRefresh() {
        guard isEnabled, frontBrowser != nil, !immediateRefreshScheduled else { return }
        immediateRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.immediateRefreshScheduled = false
            self.pumpRefresh()
        }
    }

    /// Event-tap callers only set flags: no AX, dispatch, file I/O, UI, or logging.
    func noteTypingActivity() { typingPending = true }
    func notePointerActivity() -> Bool {
        guard isEnabled, frontBrowser != nil else { return false }
        pointerPending = true
        return true
    }

    private func stopRefreshing() {
        refreshPolicy.setActive(false, now: ProcessInfo.processInfo.systemUptime)
        refreshTimer?.invalidate()
        refreshTimer = nil
        typingPending = false
        pointerPending = false
        passiveTrace.record(.deactivated, now: ProcessInfo.processInfo.systemUptime)
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.pumpRefresh() }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func pumpRefresh() {
        guard isEnabled, let front = frontBrowser else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if pointerPending {
            pointerPending = false
            refreshPolicy.invalidate(now: now, settleDelay: 0.08)
            passiveTrace.record(.invalidated, now: now, generation: refreshPolicy.generation)
            publish(nil)
        }
        if typingPending {
            typingPending = false
            passiveTrace.record(.typingOccurred, now: now, generation: refreshPolicy.generation,
                                active: webServiceBundleID != nil)
            refreshPolicy.activity(now: now)
        }
        guard let ticket = refreshPolicy.begin(now: now) else { return }
        passiveTrace.record(.evaluationStarted, now: now, generation: ticket.generation)
        axQueue.async { [weak self] in
            // A wall-clock budget prevents walking large/unresponsive AX trees indefinitely.
            // One already-running AX IPC may finish after the budget (OS timeout: 250ms).
            Thread.current.threadDictionary[Self.budgetKey] = ProcessInfo.processInfo.systemUptime + 0.2
            let result = Self.evaluate(pid: front.pid, kind: front.kind)
            let timedOut = ProcessInfo.processInfo.systemUptime >= (Thread.current.threadDictionary[Self.budgetKey] as? Double ?? 0)
            Thread.current.threadDictionary.removeObject(forKey: Self.budgetKey)
            let bounded = timedOut ? BrowserEvaluation(service: nil, reason: .timedOut) : result
            DispatchQueue.main.async {
                guard let self else { return }
                let completedAt = ProcessInfo.processInfo.systemUptime
                let accepted = self.refreshPolicy.complete(ticket, now: completedAt)
                    && self.isEnabled && self.frontBrowser?.pid == front.pid && !self.pointerPending
                self.passiveTrace.record(.evaluationFinished, now: completedAt,
                    generation: ticket.generation, active: bounded.service != nil,
                    reason: bounded.reason, accepted: accepted)
                if accepted { self.publish(bounded.service) }
                // If a focus change arrived during AX work, re-evaluate the newest
                // generation promptly; the budget still applies and workers never overlap.
                self.scheduleImmediateRefresh()
            }
        }
    }

    private func publish(_ id: String?) {
        guard webServiceBundleID != id else { return }
        webServiceBundleID = id
        passiveTrace.record(.cacheChanged, now: ProcessInfo.processInfo.systemUptime,
                            generation: refreshPolicy.generation, active: id != nil)
        onChange?(id)
    }

    // MARK: - AXObserver(タブ切替・フォーカス変化の検知)

    private func attachObserver(pid: pid_t) {
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { observer, _, notification, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<BrowserTabMonitor>.fromOpaque(refcon).takeUnretainedValue()
            // Background browser notifications must not invalidate the front browser.
            guard monitor.isEnabled, let front = monitor.frontBrowser,
                  let expected = monitor.observers[front.pid], CFEqual(observer, expected) else { return }
            let event: BrowserPassiveTrace.Event
            switch notification as String {
            case kAXFocusedUIElementChangedNotification: event = .focusNotification
            case kAXTitleChangedNotification: event = .titleNotification
            case kAXFocusedWindowChangedNotification: event = .focusedWindowNotification
            case kAXMainWindowChangedNotification: event = .mainWindowNotification
            default: event = .otherNotification
            }
            monitor.passiveTrace.record(event, now: ProcessInfo.processInfo.systemUptime)
            // All context changes still invalidate immediately, including title changes.
            monitor.refresh()
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else {
            log.warning("AXObserverCreate failed for pid \(pid)")
            return
        }
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications = [
            kAXTitleChangedNotification,            // タブ切替・ページ遷移
            kAXFocusedUIElementChangedNotification, // アドレスバー⇔ページ内のフォーカス移動
            kAXFocusedWindowChangedNotification,
            kAXMainWindowChangedNotification,
        ]
        for name in notifications {
            AXObserverAddNotification(observer, appElement, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
    }

    // MARK: - 評価(axQueue上で実行)

    private static let evalLog = Logger(subsystem: "dev.iwai.UniEnter", category: "browser-eval")

    private static func evaluate(pid: pid_t, kind: BrowserKind) -> BrowserEvaluation {
        let app = AXUIElementCreateApplication(pid)

        if let focused = copyElement(app, kAXFocusedUIElementAttribute) {
            if copyString(focused, kAXSubroleAttribute) == "AXSecureTextField" { return BrowserEvaluation(service: nil, reason: .secureInput) }
            // サイドパネルはタブのアドレスバーとURLが違う。
            // 最も近いWebAreaだけを見る。他の兄弟/背後のページは探さない。
            if let document = focusedDocument(of: focused) {
                guard let documentURL = copyURL(document, "AXURL") else { return BrowserEvaluation(service: nil, reason: .missingFocusedURL) }
                if documentURL.host?.lowercased() == "gemini.google.com" {
                    let service = WebAppMatcher.focusedGeminiService(
                        role: role(of: focused),
                        subrole: copyString(focused, kAXSubroleAttribute),
                        documentURL: documentURL)
                    return BrowserEvaluation(service: service, reason: service == nil ? .rejectedGeminiInput : .focusedGemini)
                }
                // 通常ページ/拡張機能/ログインページに戻ったら、背後の
                // 対象タブにフォールバックしない。
                let service = WebAppMatcher.serviceBundleID(for: documentURL)
                return BrowserEvaluation(service: service, reason: service == nil ? .otherFocusedWeb : .focusedWebService)
            }
            if isBrowserChromeTextField(focused) { return BrowserEvaluation(service: nil, reason: .browserTextInput) }
        }

        guard let window = copyElement(app, kAXFocusedWindowAttribute)
                ?? copyElement(app, kAXMainWindowAttribute) else {
            evalLog.notice("eval pid=\(pid): no focused/main window")
            return BrowserEvaluation(service: nil, reason: .noWindow)
        }

        var url: URL?
        var hostOnly = false
        switch kind {
        case .safari:
            url = findWebAreaURL(in: window)
        case .chromium:
            // レンダラ側AXの有効化(AXEnhancedUserInterface)はウィンドウ操作を壊す
            // 既知の副作用があるため使わず、常時公開されるアドレスバーの値を読む。
            url = findOmniboxURL(in: window)
            if url == nil, let hostURL = findArcCommandBarURL(in: window) {
                // Arcはアドレスバーが無く、コマンドバーの静的テキストにドメインのみ露出する
                url = hostURL
                hostOnly = true
            }
            if url == nil {
                // レンダラAXが有効な環境ではAXWebAreaのAXURLが取れることがある
                url = findWebAreaURL(in: window)
            }
        }
        guard let url else {
            evalLog.notice("eval pid=\(pid): url not found (kind=\(String(describing: kind), privacy: .public))")
            return BrowserEvaluation(service: nil, reason: .noURL)
        }
        let service = WebAppMatcher.serviceBundleID(for: url, hostOnly: hostOnly)
        evalLog.notice("eval pid=\(pid): service=\(service ?? "no match", privacy: .public)")
        return BrowserEvaluation(service: service, reason: service == nil ? .otherTab : .tabService)
    }

    private static func focusedDocument(of element: AXUIElement) -> AXUIElement? {
        WebAppMatcher.nearestFocusedWebArea(from: element, role: { role(of: $0) },
            parent: { copyElement($0, kAXParentAttribute) })
    }

    /// Arc: ウィンドウ直下の浅い階層にある `commandBarPlaceholderTextField`
    /// (AXStaticText、値は表示中ページのホスト名のみ)を読む。
    private static func findArcCommandBarURL(in window: AXUIElement) -> URL? {
        var visited = 0
        func search(_ element: AXUIElement, depth: Int) -> URL? {
            guard visited < 120, depth <= 3 else { return nil }
            visited += 1
            if copyString(element, "AXIdentifier") == "commandBarPlaceholderTextField",
               let value = copyString(element, kAXValueAttribute) {
                return WebAppMatcher.normalizedURL(from: value)
            }
            for child in children(of: element) {
                if let url = search(child, depth: depth + 1) { return url }
            }
            return nil
        }
        return search(window, depth: 0)
    }

    /// フォーカス要素がブラウザ自身のUI(アドレスバー・検索バー等)のテキスト欄か。
    /// Webページ内のテキスト欄はAXWebAreaの子孫として現れるため、祖先にAXWebAreaが
    /// 無いテキスト欄だけをブラウザUIとみなす。Chromium系もレンダラAXが有効な環境
    /// (他の支援技術ツールが常駐している等)ではページ内テキスト欄が露出するので、
    /// ロールだけで判定するとメッセージ入力欄で誤って無効化してしまう。
    private static func isBrowserChromeTextField(_ element: AXUIElement) -> Bool {
        let textRoles: Set<String> = ["AXTextField", "AXSearchField", "AXComboBox", "AXTextArea"]
        guard let role = role(of: element), textRoles.contains(role) else { return false }
        var current = element
        for _ in 0..<25 {
            guard let parent = copyElement(current, kAXParentAttribute) else { return true }
            if self.role(of: parent) == "AXWebArea" { return false }
            current = parent
        }
        return true
    }

    /// Safari: ウィンドウ配下からAXWebAreaを探し、そのAXURLを読む
    private static func findWebAreaURL(in window: AXUIElement) -> URL? {
        var visited = 0
        func search(_ element: AXUIElement, depth: Int) -> URL? {
            guard visited < 800, depth < 14 else { return nil }
            visited += 1
            if role(of: element) == "AXWebArea" {
                return copyURL(element, "AXURL")
            }
            for child in children(of: element) {
                if let url = search(child, depth: depth + 1) { return url }
            }
            return nil
        }
        return search(window, depth: 0)
    }

    /// Chromium系: ウィンドウ配下からURLとして解釈できる値を持つ最初のAXTextField
    /// (=アドレスバー)を探す。レンダラAXが有効な環境ではWebコンテンツのツリーが
    /// 巨大になるため、AXWebArea配下(アドレスバーは絶対に無い)へは降りない。
    private static func findOmniboxURL(in window: AXUIElement) -> URL? {
        var visited = 0
        func search(_ element: AXUIElement, depth: Int) -> URL? {
            guard visited < 1000, depth < 12 else { return nil }
            visited += 1
            let role = self.role(of: element)
            if role == "AXWebArea" { return nil }
            if role == "AXTextField",
               let value = copyString(element, kAXValueAttribute),
               let url = WebAppMatcher.normalizedURL(from: value) {
                return url
            }
            for child in children(of: element) {
                if let url = search(child, depth: depth + 1) { return url }
            }
            return nil
        }
        return search(window, depth: 0)
    }

    // MARK: - 診断

    /// Passive: observes normal scheduling only. Starting does not refresh or read AX.
    @discardableResult
    func startMetadataDiagnostics() -> Bool {
        guard diagnosticToken == nil, AXIsProcessTrusted() else { return false }
        diagnosticToken = UUID()
        passiveTrace.start(now: ProcessInfo.processInfo.systemUptime, active: webServiceBundleID != nil)
        let timer = Timer(timeInterval: BrowserPassiveTrace.duration, repeats: false) { [weak self] _ in
            self?.finishMetadataDiagnostics()
        }
        diagnosticTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        return true
    }

    private func finishMetadataDiagnostics() {
        diagnosticTimer?.invalidate()
        diagnosticTimer = nil
        diagnosticToken = nil
        let lines = passiveTrace.finish(now: ProcessInfo.processInfo.systemUptime)
        var output: URL?
        do {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("UniEnter-Metadata-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700])
            let file = directory.appendingPathComponent("browser-passive.txt")
            guard FileManager.default.createFile(atPath: file.path,
                contents: Data(lines.joined(separator: "\n").utf8),
                attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
            output = file
        } catch { /* No raw error or captured content in system logs. */ }
        onDiagnosticFinished?(output)
    }

    // MARK: - AXヘルパー

    private static let budgetKey = "dev.iwai.UniEnter.ax-deadline"
    private static func copyValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        if let deadline = Thread.current.threadDictionary[budgetKey] as? Double,
           ProcessInfo.processInfo.systemUptime >= deadline { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copyValue(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        guard let value = copyValue(element, attribute) else { return nil }
        return value as? String
    }

    private static func copyURL(_ element: AXUIElement, _ attribute: String) -> URL? {
        guard let value = copyValue(element, attribute) else { return nil }
        if CFGetTypeID(value) == CFURLGetTypeID() { return (value as! CFURL) as URL }
        if let string = value as? String { return URL(string: string) }
        return nil
    }

    private static func role(of element: AXUIElement) -> String? {
        copyString(element, kAXRoleAttribute)
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        guard let value = copyValue(element, kAXChildrenAttribute),
              let array = value as? [AnyObject] else { return [] }
        return array.compactMap { item in
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else { return nil }
            return (item as! AXUIElement)
        }
    }
}
