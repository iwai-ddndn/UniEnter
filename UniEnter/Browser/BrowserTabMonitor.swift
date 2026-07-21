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
            if isEnabled { refresh() } else { publish(nil) }
        }
    }

    private let axQueue = DispatchQueue(label: "dev.iwai.UniEnter.browser-ax", qos: .userInitiated)
    private var observers: [pid_t: AXObserver] = [:]
    private var frontBrowser: (pid: pid_t, kind: BrowserKind)?
    private var generation = 0
    private var pendingWork: DispatchWorkItem?

    init() {
        // ビジーなブラウザへのAX問い合わせで長時間ブロックしないよう、
        // このプロセスのAXメッセージ既定タイムアウトを短くする
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
    }

    // MARK: - 入力(メインスレッドから呼ぶ)

    func frontmostChanged(_ app: NSRunningApplication?) {
        if let app, let bundleID = app.bundleIdentifier,
           let kind = BrowserRegistry.browsers[bundleID] {
            frontBrowser = (app.processIdentifier, kind)
            attachObserver(pid: app.processIdentifier)
            refresh()
        } else {
            frontBrowser = nil
            pendingWork?.cancel()
            publish(nil)
        }
    }

    func appTerminated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        if frontBrowser?.pid == pid {
            frontBrowser = nil
            publish(nil)
        }
    }

    /// 現在の前面ブラウザを再評価する(AXObserver通知・設定変更などから)
    func refresh() {
        guard isEnabled, let front = frontBrowser else { return }
        pendingWork?.cancel()
        generation += 1
        let gen = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let result = Self.evaluate(pid: front.pid, kind: front.kind)
            DispatchQueue.main.async {
                guard self.generation == gen, self.frontBrowser?.pid == front.pid else { return }
                self.publish(result)
            }
        }
        pendingWork = work
        // 通知は連発するため軽くまとめる
        axQueue.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    private func publish(_ id: String?) {
        guard webServiceBundleID != id else { return }
        webServiceBundleID = id
        onChange?(id)
    }

    // MARK: - AXObserver(タブ切替・フォーカス変化の検知)

    private func attachObserver(pid: pid_t) {
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<BrowserTabMonitor>.fromOpaque(refcon).takeUnretainedValue()
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

    private static func evaluate(pid: pid_t, kind: BrowserKind) -> String? {
        let app = AXUIElementCreateApplication(pid)

        // アドレスバー等ブラウザUIのテキスト欄を編集中は無効にする
        // (そこでのEnterはナビゲーション操作であり書き換えてはいけない)
        if let focused = copyElement(app, kAXFocusedUIElementAttribute),
           isBrowserChromeTextField(focused) {
            evalLog.notice("eval pid=\(pid): address bar focused -> inactive")
            return nil
        }

        guard let window = copyElement(app, kAXFocusedWindowAttribute)
                ?? copyElement(app, kAXMainWindowAttribute) else {
            evalLog.notice("eval pid=\(pid): no focused/main window")
            return nil
        }

        let url: URL?
        switch kind {
        case .safari:
            url = findWebAreaURL(in: window)
        case .chromium:
            // レンダラ側AXの有効化(AXEnhancedUserInterface)はウィンドウ操作を壊す
            // 既知の副作用があるため使わず、常時公開されるアドレスバーの値を読む。
            // Arc等アドレスバーが露出しないUIでは、AXWebArea(レンダラAXが有効な
            // 環境でのみ存在)のAXURLをフォールバックとして試す。
            url = findOmniboxURL(in: window) ?? findWebAreaURL(in: window)
        }
        guard let url else {
            evalLog.notice("eval pid=\(pid): url not found (kind=\(String(describing: kind), privacy: .public))")
            return nil
        }
        let service = WebAppMatcher.serviceBundleID(for: url)
        evalLog.notice("eval pid=\(pid): url=\(url.host ?? "?", privacy: .public)\(url.path, privacy: .public) -> \(service ?? "no match", privacy: .public)")
        return service
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

    /// 前面ブラウザのAXツリーをログへダンプする(メニューから手動実行する調査用)。
    func dumpDiagnostics() {
        guard let front = frontBrowser else {
            Self.evalLog.notice("diag: no front browser")
            return
        }
        axQueue.async { Self.dumpTree(pid: front.pid) }
    }

    private static func dumpTree(pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        if let focused = copyElement(app, kAXFocusedUIElementAttribute) {
            evalLog.notice("diag focused: \(describe(focused), privacy: .public)")
        }
        guard let window = copyElement(app, kAXFocusedWindowAttribute)
                ?? copyElement(app, kAXMainWindowAttribute) else {
            evalLog.notice("diag: no window")
            return
        }
        var count = 0
        func walk(_ element: AXUIElement, _ depth: Int) {
            guard count < 300, depth < 9 else { return }
            count += 1
            let indent = String(repeating: "| ", count: depth)
            evalLog.notice("diag \(indent, privacy: .public)\(describe(element), privacy: .public)")
            for child in children(of: element) { walk(child, depth + 1) }
        }
        walk(window, 0)
        evalLog.notice("diag: dumped \(count) nodes")
    }

    private static func describe(_ element: AXUIElement) -> String {
        var parts: [String] = [role(of: element) ?? "?"]
        if let sub = copyString(element, kAXSubroleAttribute) { parts.append("sub=\(sub)") }
        if let id = copyString(element, "AXIdentifier") { parts.append("id=\(id)") }
        if let title = copyString(element, kAXTitleAttribute), !title.isEmpty {
            parts.append("title=\(String(title.prefix(40)))")
        }
        if let desc = copyString(element, kAXDescriptionAttribute), !desc.isEmpty {
            parts.append("desc=\(String(desc.prefix(40)))")
        }
        if let value = copyString(element, kAXValueAttribute), !value.isEmpty {
            parts.append("value=\(String(value.prefix(60)))")
        }
        if let url = copyURL(element, "AXURL") {
            parts.append("url=\(String(url.absoluteString.prefix(60)))")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - AXヘルパー

    private static func copyValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
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
        guard let value = copyValue(element, attribute),
              CFGetTypeID(value) == CFURLGetTypeID() else { return nil }
        return (value as! CFURL) as URL
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
