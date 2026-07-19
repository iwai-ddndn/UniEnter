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

    private static func evaluate(pid: pid_t, kind: BrowserKind) -> String? {
        let app = AXUIElementCreateApplication(pid)

        // アドレスバー等ブラウザUIのテキスト欄を編集中は無効にする
        // (そこでのEnterはナビゲーション操作であり書き換えてはいけない)
        if let focused = copyElement(app, kAXFocusedUIElementAttribute),
           isBrowserChromeTextField(focused, kind: kind) {
            return nil
        }

        guard let window = copyElement(app, kAXFocusedWindowAttribute)
                ?? copyElement(app, kAXMainWindowAttribute) else { return nil }

        let url: URL?
        switch kind {
        case .safari:
            url = findWebAreaURL(in: window)
        case .chromium:
            // レンダラ側AXの有効化(AXEnhancedUserInterface)はウィンドウ操作を壊す
            // 既知の副作用があるため使わず、常時公開されるアドレスバーの値を読む
            url = findOmniboxURL(in: window)
        }
        guard let url else { return nil }
        return WebAppMatcher.serviceBundleID(for: url)
    }

    /// フォーカス要素がブラウザ自身のUI(アドレスバー・検索バー等)のテキスト欄か。
    private static func isBrowserChromeTextField(_ element: AXUIElement, kind: BrowserKind) -> Bool {
        let textRoles: Set<String> = ["AXTextField", "AXSearchField", "AXComboBox", "AXTextArea"]
        guard let role = role(of: element), textRoles.contains(role) else { return false }
        switch kind {
        case .chromium:
            // Web内テキスト欄はレンダラAX無効のため露出しない。
            // テキスト欄ロールが取れたらブラウザUIとみなす。
            return true
        case .safari:
            // Webページ内のテキスト欄はAXWebAreaの子孫。祖先にAXWebAreaが無ければブラウザUI。
            var current = element
            for _ in 0..<20 {
                guard let parent = copyElement(current, kAXParentAttribute) else { return true }
                if self.role(of: parent) == "AXWebArea" { return false }
                current = parent
            }
            return true
        }
    }

    /// Safari: ウィンドウ配下からAXWebAreaを探し、そのAXURLを読む
    private static func findWebAreaURL(in window: AXUIElement) -> URL? {
        var visited = 0
        func search(_ element: AXUIElement, depth: Int) -> URL? {
            guard visited < 400, depth < 12 else { return nil }
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
    /// (=アドレスバー)を探す。レンダラAXは無効のためツリーはブラウザUIのみで小さい。
    private static func findOmniboxURL(in window: AXUIElement) -> URL? {
        var visited = 0
        func search(_ element: AXUIElement, depth: Int) -> URL? {
            guard visited < 400, depth < 10 else { return nil }
            visited += 1
            if role(of: element) == "AXTextField",
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
